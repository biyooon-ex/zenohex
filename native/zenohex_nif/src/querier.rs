use std::time::Duration;
use std::time::Instant;

use rustler::Encoder;
use zenoh::Wait;

use crate::builder::Builder;

#[rustler::nif(schedule = "DirtyIo")]
fn querier_get<'a>(
    env: rustler::Env<'a>,
    entity_global_id_resource: rustler::ResourceArc<crate::session::EntityGlobalIdResource>,
    timeout: u64,
    opts: rustler::Term,
) -> rustler::NifResult<(rustler::Atom, Vec<rustler::Term<'a>>)> {
    let session_id = &entity_global_id_resource.zid();
    let entity_global_id = &entity_global_id_resource;

    let session =
        crate::session::SessionMap::get_session(&crate::session::SESSION_MAP, session_id)?;
    // WHY: Keep the read lock only around handler creation.
    //      If session_locked lives through the reply loop, write-lock operations such as
    //      undeclare or session close can be blocked until timeout.
    let channel_handler =
        {
            let session_locked = session.read().unwrap();
            let entity = session_locked.get_entity(entity_global_id)?;

            match entity {
                crate::session::Entity::Querier(querier, _) => querier
                    .get()
                    .apply_opts(opts)?
                    .wait()
                    .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?,
                _ => unreachable!("unexpected entity"),
            }
        };

    let deadline = Instant::now() + Duration::from_millis(timeout);
    let mut replies = Vec::new();

    loop {
        // NOTE: `recv_deadline` document says following,
        //       > If the deadline has expired, this will return None.
        let reply = match channel_handler.recv_deadline(deadline) {
            Ok(Some(reply)) => reply,
            Ok(None) => {
                // If we timeout but have collected replies, return them successfully.
                // Only error on timeout if we have no data at all.
                if !replies.is_empty() {
                    break;
                }
                return Err(rustler::Error::Term(Box::new(crate::atoms::timeout())));
            }
            Err(error) => {
                // If the channel disconnected after receiving some replies,
                // treat it as a successful completion and return what we collected.
                if channel_handler.is_disconnected() && !replies.is_empty() {
                    break;
                }
                return Err(rustler::Error::Term(crate::zenoh_error!(error)));
            }
        };

        let term = match reply.result() {
            Ok(sample) => crate::sample::ZenohexSample::from(env, sample.clone()).encode(env),
            Err(reply_error) => {
                crate::query::ZenohexQueryReplyError::from(env, reply_error.clone()).encode(env)
            }
        };

        replies.push(term);
    }

    Ok((rustler::types::atom::ok(), replies))
}

#[rustler::nif]
fn querier_undeclare(
    entity_global_id_resource: rustler::ResourceArc<crate::session::EntityGlobalIdResource>,
) -> rustler::NifResult<rustler::Atom> {
    let session_id = &entity_global_id_resource.zid();
    let entity_global_id = &entity_global_id_resource;

    let session =
        crate::session::SessionMap::get_session(&crate::session::SESSION_MAP, session_id)?;
    let mut session_locked = session.write().unwrap();
    let entity = session_locked.remove_entity(entity_global_id)?;

    match entity {
        crate::session::Entity::Querier(querier, _) => {
            querier
                .undeclare()
                .wait()
                .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

            Ok(rustler::types::atom::ok())
        }
        _ => unreachable!("unexpected entity"),
    }
}
