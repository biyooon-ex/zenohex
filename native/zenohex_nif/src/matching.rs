use std::ops::Deref;
use std::sync::Mutex;

use rustler::Encoder;
use zenoh::Wait;

struct MatchingListenerResource {
    listener: Mutex<
        Option<
            zenoh::matching::MatchingListener<
                crate::helper::forwarder::ChannelHandler<zenoh::matching::MatchingStatus>,
            >,
        >,
    >,
}

#[rustler::resource_impl]
impl rustler::Resource for MatchingListenerResource {}

impl Deref for MatchingListenerResource {
    type Target = Mutex<
        Option<
            zenoh::matching::MatchingListener<
                crate::helper::forwarder::ChannelHandler<zenoh::matching::MatchingStatus>,
            >,
        >,
    >;

    fn deref(&self) -> &Self::Target {
        &self.listener
    }
}

impl MatchingListenerResource {
    fn new(
        listener: zenoh::matching::MatchingListener<
            crate::helper::forwarder::ChannelHandler<zenoh::matching::MatchingStatus>,
        >,
    ) -> Self {
        MatchingListenerResource {
            listener: Mutex::new(Some(listener)),
        }
    }
}

impl Drop for MatchingListenerResource {
    fn drop(&mut self) {
        let mut listener_option = self.lock().unwrap();
        match listener_option.take() {
            Some(listener) => {
                if let Err(error) = listener.undeclare().wait() {
                    log::debug!("matching listener drop undeclare failed: {}", error);
                }
            }
            None => log::debug!("matching listener already undeclared"),
        }
    }
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Matching.Status"]
pub struct ZenohexMatchingStatus {
    matching: bool,
}

impl From<zenoh::matching::MatchingStatus> for ZenohexMatchingStatus {
    fn from(value: zenoh::matching::MatchingStatus) -> Self {
        ZenohexMatchingStatus {
            matching: value.matching(),
        }
    }
}

#[rustler::nif]
fn matching_status(
    entity_global_id_resource: rustler::ResourceArc<crate::session::EntityGlobalIdResource>,
) -> rustler::NifResult<(rustler::Atom, bool)> {
    let session_id = &entity_global_id_resource.zid();
    let entity_global_id = &entity_global_id_resource;

    let session =
        crate::session::SessionMap::get_session(&crate::session::SESSION_MAP, session_id)?;
    let session_locked = session.read().unwrap();
    let entity = session_locked.get_entity(entity_global_id)?;

    let status = match entity {
        crate::session::Entity::Publisher(publisher, _) => publisher
            .matching_status()
            .wait()
            .map(|status| status.matching()),
        crate::session::Entity::Querier(querier, _) => querier
            .matching_status()
            .wait()
            .map(|status| status.matching()),
        _ => {
            return Err(rustler::Error::Term(Box::new(
                crate::atoms::unsupported_entity(),
            )))
        }
    }
    .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    Ok((rustler::types::atom::ok(), status))
}

#[rustler::nif]
fn matching_declare_listener(
    entity_global_id_resource: rustler::ResourceArc<crate::session::EntityGlobalIdResource>,
    pid: rustler::LocalPid,
) -> rustler::NifResult<(
    rustler::Atom,
    rustler::ResourceArc<MatchingListenerResource>,
)> {
    let session_id = &entity_global_id_resource.zid();
    let entity_global_id = &entity_global_id_resource;

    let session =
        crate::session::SessionMap::get_session(&crate::session::SESSION_MAP, session_id)?;
    let session_locked = session.read().unwrap();
    let entity = session_locked.get_entity(entity_global_id)?;

    let channel_kind = crate::helper::forwarder::ChannelKind::from_env()?;

    let listener = match entity {
        crate::session::Entity::Publisher(publisher, _) => publisher
            .matching_listener()
            .with(channel_kind)
            .wait(),
        crate::session::Entity::Querier(querier, _) => querier
            .matching_listener()
            .with(channel_kind)
            .wait(),
        _ => {
            return Err(rustler::Error::Term(Box::new(
                crate::atoms::unsupported_entity(),
            )))
        }
    }
    .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    crate::helper::forwarder::spawn_forwarder(
        pid,
        listener.handler().clone(),
        |env, matching_status| ZenohexMatchingStatus::from(matching_status).encode(env),
    )?;

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(MatchingListenerResource::new(listener)),
    ))
}

#[rustler::nif]
fn matching_undeclare_listener(
    matching_listener_resource: rustler::ResourceArc<MatchingListenerResource>,
) -> rustler::NifResult<rustler::Atom> {
    let mut listener_option = matching_listener_resource.lock().unwrap();

    match listener_option.take() {
        Some(listener) => {
            listener
                .undeclare()
                .wait()
                .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

            Ok(rustler::types::atom::ok())
        }
        None => Err(rustler::Error::Term(Box::new("already undeclared"))),
    }
}
