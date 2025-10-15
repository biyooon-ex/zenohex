use std::ops::Deref;
use std::sync::Mutex;
use std::time::Duration;
use std::time::Instant;

use rustler::Encoder;
use zenoh::Wait;

use crate::builder::Builder;

struct LivelinessTokenResource(Mutex<Option<zenoh::liveliness::LivelinessToken>>);

#[rustler::resource_impl]
impl rustler::Resource for LivelinessTokenResource {}

impl Deref for LivelinessTokenResource {
    type Target = Mutex<Option<zenoh::liveliness::LivelinessToken>>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl Drop for LivelinessTokenResource {
    fn drop(&mut self) {
        let mut token_option = self.lock().unwrap();
        match token_option.take() {
            Some(token) => token.undeclare().wait().unwrap(),
            None => log::debug!("liveliness token already undeclared"),
        }
    }
}

impl LivelinessTokenResource {
    fn new(liveliness_token: zenoh::liveliness::LivelinessToken) -> LivelinessTokenResource {
        LivelinessTokenResource(Mutex::new(Some(liveliness_token)))
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn liveliness_get<'a>(
    env: rustler::Env<'a>,
    session_id_resource: rustler::ResourceArc<crate::session::SessionIdResource>,
    key_expr: &str,
    timeout: u64,
    opts: rustler::Term,
) -> rustler::NifResult<(rustler::Atom, Vec<rustler::Term<'a>>)> {
    let session_id = &session_id_resource;
    let session =
        crate::session::SessionMap::get_session(&crate::session::SESSION_MAP, session_id)?;
    let session_locked = session.read().unwrap();

    let liveliness_get_builder = session_locked.liveliness().get(key_expr);

    let channel_handler = liveliness_get_builder
        .apply_opts(opts)?
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

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
fn liveliness_declare_subscriber(
    session_id_resource: rustler::ResourceArc<crate::session::SessionIdResource>,
    key_expr: String,
    // WHY: Pass `pid` instead of using `env.pid()`
    //      so the user can specify any receiver process
    pid: rustler::LocalPid,
    opts: rustler::Term,
) -> rustler::NifResult<(
    rustler::Atom,
    rustler::ResourceArc<crate::session::EntityGlobalIdResource>,
)> {
    let session_id = &session_id_resource;
    let session =
        crate::session::SessionMap::get_session(&crate::session::SESSION_MAP, session_id)?;
    let mut session_locked = session.write().unwrap();

    let liveliness_subscriber_buidler = session_locked.liveliness().declare_subscriber(key_expr);

    let subscriber = liveliness_subscriber_buidler
        .apply_opts(opts)?
        .callback(move |sample| {
            // WHY: Spawn a thread inside this callback.
            //      If we don't spawn a thread, a panic will occur.
            //      See: https://docs.rs/rustler/latest/rustler/env/struct.OwnedEnv.html#panics
            std::thread::spawn(move || {
                let _ = rustler::OwnedEnv::new().run(|env: rustler::Env| {
                    env.send(&pid, crate::sample::ZenohexSample::from(env, sample))
                });
            });
        })
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    let subscriber_id = subscriber.id();
    session_locked.insert_entity(
        subscriber_id,
        crate::session::Entity::Subscriber(subscriber, session_id_resource),
    )?;

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(crate::session::EntityGlobalIdResource::new(subscriber_id)),
    ))
}

#[rustler::nif]
fn liveliness_declare_token(
    session_id_resource: rustler::ResourceArc<crate::session::SessionIdResource>,
    key_expr: &str,
) -> rustler::NifResult<(rustler::Atom, rustler::ResourceArc<LivelinessTokenResource>)> {
    let session_id = &session_id_resource;
    let session =
        crate::session::SessionMap::get_session(&crate::session::SESSION_MAP, session_id)?;
    let session_locked = session.read().unwrap();

    let liveliness_token_buidler = session_locked.liveliness().declare_token(key_expr);

    let liveliness_token = liveliness_token_buidler
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(LivelinessTokenResource::new(liveliness_token)),
    ))
}

#[rustler::nif]
fn liveliness_token_undeclare(
    liveliness_token_resource: rustler::ResourceArc<LivelinessTokenResource>,
) -> rustler::NifResult<rustler::Atom> {
    let mut liveliness_token_option = liveliness_token_resource.lock().unwrap();
    match liveliness_token_option.take() {
        Some(liveliness_token) => {
            liveliness_token
                .undeclare()
                .wait()
                .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;
            Ok(rustler::types::atom::ok())
        }
        None => Err(rustler::Error::Term(Box::new("already undeclared"))),
    }
}
