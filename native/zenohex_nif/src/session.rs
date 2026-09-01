use core::fmt;
use std::collections::HashMap;
use std::ops::Deref;
use std::sync::atomic::AtomicU64;
use std::sync::atomic::Ordering;
use std::sync::Arc;
use std::sync::LazyLock;
use std::sync::RwLock;
use std::time::Duration;
use std::time::Instant;

use rustler::Encoder;
use zenoh::Wait;

use crate::builder::Builder;

pub enum Entity<'a> {
    Publisher(
        zenoh::pubsub::Publisher<'a>,
        #[allow(dead_code)] rustler::ResourceArc<SessionIdResource>,
    ),
    Querier(
        zenoh::query::Querier<'a>,
        #[allow(dead_code)] rustler::ResourceArc<SessionIdResource>,
    ),
    Subscriber(
        zenoh::pubsub::Subscriber<crate::helper::forwarder::ChannelHandler<zenoh::sample::Sample>>,
        #[allow(dead_code)] rustler::ResourceArc<SessionIdResource>,
    ),
    Queryable(
        zenoh::query::Queryable<crate::helper::forwarder::ChannelHandler<zenoh::query::Query>>,
        #[allow(dead_code)] rustler::ResourceArc<SessionIdResource>,
    ),
}

impl fmt::Display for Entity<'_> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Entity::Publisher(_, _) => write!(f, "Publisher"),
            Entity::Querier(_, _) => write!(f, "Querier"),
            Entity::Subscriber(_, _) => write!(f, "Subscriber"),
            Entity::Queryable(_, _) => write!(f, "Queryable"),
        }
    }
}

pub struct Session<'a> {
    inner: zenoh::Session,
    entities: HashMap<zenoh::session::EntityGlobalId, Entity<'a>>,
}

impl<'a> Session<'a> {
    pub fn insert_entity(
        &mut self,
        entity_global_id: zenoh::session::EntityGlobalId,
        entity: Entity<'a>,
    ) -> rustler::NifResult<rustler::Atom> {
        match self.entities.insert(entity_global_id, entity) {
            Some(_entity) => Err(rustler::Error::Term(Box::new("entity already existed"))),
            None => Ok(rustler::types::atom::ok()),
        }
    }

    pub fn get_entity(
        &self,
        entity_global_id: &zenoh::session::EntityGlobalId,
    ) -> rustler::NifResult<&Entity<'a>> {
        self.entities
            .get(entity_global_id)
            .ok_or_else(|| rustler::Error::Term(Box::new("entity not found")))
    }

    pub fn remove_entity(
        &mut self,
        entity_global_id: &zenoh::session::EntityGlobalId,
    ) -> rustler::NifResult<Entity<'a>> {
        self.entities
            .remove(entity_global_id)
            .ok_or_else(|| rustler::Error::Term(Box::new("entity not found")))
    }
}

impl Deref for Session<'_> {
    type Target = zenoh::Session;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub struct SessionId(u64);

static NEXT_SESSION_ID: AtomicU64 = AtomicU64::new(1);

pub struct SessionMap<'a>(RwLock<HashMap<SessionId, Arc<RwLock<Session<'a>>>>>);

impl<'a> SessionMap<'_> {
    fn new() -> SessionMap<'a> {
        SessionMap(RwLock::new(HashMap::new()))
    }

    fn insert_session(session_map: &SessionMap, session: zenoh::Session) -> SessionId {
        let mut map = session_map.0.write().unwrap();

        let session_id = loop {
            let candidate = SessionId(NEXT_SESSION_ID.fetch_add(1, Ordering::Relaxed));
            if !map.contains_key(&candidate) {
                break candidate;
            }
        };

        map.insert(
            session_id,
            Arc::new(RwLock::new(Session {
                inner: session,
                entities: HashMap::new(),
            })),
        );

        session_id
    }

    pub fn get_session(
        session_map: &'a SessionMap<'a>,
        session_id: &SessionId,
    ) -> rustler::NifResult<Arc<RwLock<Session<'a>>>> {
        let map = session_map.0.read().unwrap();
        map.get(session_id)
            .cloned()
            .ok_or_else(|| rustler::Error::Term(Box::new("session not found")))
    }

    fn remove_session(
        session_map: &'a SessionMap<'a>,
        session_id: &SessionId,
    ) -> rustler::NifResult<Arc<RwLock<Session<'a>>>> {
        let mut map = session_map.0.write().unwrap();
        map.remove(session_id)
            .ok_or_else(|| rustler::Error::Term(Box::new("session not found")))
    }
}

pub static SESSION_MAP: LazyLock<SessionMap> = LazyLock::new(SessionMap::new);

// WHY: Use a Zenohex-specific session ID for resource, instead of zenoh::Session itself
//      If we use the session for resource, we got the following error.
//      the trait std::panic::RefUnwindSafe is not implemented for
//      std::cell::UnsafeCell<std::collections::HashSet<zenoh_protocol::core::ZenohIdProto>>

pub struct SessionIdResource(SessionId);

#[rustler::resource_impl]
impl rustler::Resource for SessionIdResource {}
impl Deref for SessionIdResource {
    type Target = SessionId;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl Drop for SessionIdResource {
    fn drop(&mut self) {
        let session_id = &self.0;

        match SessionMap::remove_session(&SESSION_MAP, session_id) {
            Ok(session) => {
                let (close_result, success_message) = {
                    let session_locked = session.read().unwrap();
                    if session_locked.is_closed() {
                        (Ok(()), "session already closed")
                    } else {
                        (session_locked.close().wait(), "session closed by drop")
                    }
                };

                match close_result {
                    Ok(()) => log::debug!("{}", success_message),
                    Err(error) => log::error!("failed to close session by drop: {}", error),
                }
            }
            Err(_error) => log::debug!("session already removed"),
        };
    }
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Session.Info"]
pub struct ZenohexSessionInfo {
    zid: String,
    routers_zid: Vec<String>,
    peers_zid: Vec<String>,
}

impl From<zenoh::session::SessionInfo> for ZenohexSessionInfo {
    fn from(value: zenoh::session::SessionInfo) -> Self {
        let zid = value.zid().wait().to_string();

        let routers_zid = value
            .routers_zid()
            .wait()
            .fold(Vec::new(), |mut vec, router_zid| {
                vec.push(router_zid.to_string());
                vec
            });

        let peers_zid = value.peers_zid().wait().fold(Vec::new(), |mut vec, zid| {
            vec.push(zid.to_string());
            vec
        });

        ZenohexSessionInfo {
            zid,
            routers_zid,
            peers_zid,
        }
    }
}

pub struct EntityGlobalIdResource {
    session_id: SessionId,
    entity_global_id: zenoh::session::EntityGlobalId,
}

#[rustler::resource_impl]
impl rustler::Resource for EntityGlobalIdResource {}

impl EntityGlobalIdResource {
    pub fn new(
        session_id: SessionId,
        entity_global_id: zenoh::session::EntityGlobalId,
    ) -> EntityGlobalIdResource {
        EntityGlobalIdResource {
            session_id,
            entity_global_id,
        }
    }

    pub fn session_id(&self) -> &SessionId {
        &self.session_id
    }
}

impl Deref for EntityGlobalIdResource {
    type Target = zenoh::session::EntityGlobalId;

    fn deref(&self) -> &Self::Target {
        &self.entity_global_id
    }
}

impl Drop for EntityGlobalIdResource {
    fn drop(&mut self) {
        let session_id = &self.session_id;
        let entity_global_id = &self.entity_global_id;

        if let Ok(session) = SessionMap::get_session(&SESSION_MAP, session_id) {
            let mut session_locked = session.write().unwrap();
            let result = session_locked.remove_entity(entity_global_id);
            let message = match result {
                Ok(entity) => format!("entity {:#} removed by drop", entity),
                Err(_) => "entity already removed".to_string(),
            };
            log::debug!("{}", message);
        }
    }
}

#[rustler::nif]
fn session_open(
    json5_binary: &str,
) -> rustler::NifResult<(rustler::Atom, rustler::ResourceArc<SessionIdResource>)> {
    let config = zenoh::Config::from_json5(json5_binary)
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    let session = zenoh::open(config)
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    let session_id = SessionMap::insert_session(&SESSION_MAP, session);

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(SessionIdResource(session_id)),
    ))
}

#[rustler::nif]
fn session_close(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
) -> rustler::NifResult<rustler::Atom> {
    let session_id = &session_id_resource;
    let session = SessionMap::remove_session(&SESSION_MAP, session_id)?;
    let session_locked = session.read().unwrap();

    session_locked
        .close()
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    Ok(rustler::types::atom::ok())
}

#[rustler::nif]
fn session_is_closed(session_id_resource: rustler::ResourceArc<SessionIdResource>) -> bool {
    let session_id = &session_id_resource;

    match SessionMap::get_session(&SESSION_MAP, session_id) {
        Ok(session) => session.read().unwrap().is_closed(),
        Err(_) => true,
    }
}

#[rustler::nif]
fn session_put(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
    key_expr: &str,
    payload: rustler::Binary,
    opts: rustler::Term,
) -> rustler::NifResult<rustler::Atom> {
    let session_id = &session_id_resource;
    let session = SessionMap::get_session(&SESSION_MAP, session_id)?;
    let session_locked = session.read().unwrap();
    let publication_builder = session_locked.put(key_expr, payload.as_slice());

    publication_builder
        .apply_opts(opts)?
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    Ok(rustler::types::atom::ok())
}

#[rustler::nif]
fn session_delete(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
    key_expr: &str,
    opts: rustler::Term,
) -> rustler::NifResult<rustler::Atom> {
    let session_id = &session_id_resource;
    let session = SessionMap::get_session(&SESSION_MAP, session_id)?;
    let session_locked = session.read().unwrap();
    let publication_builder = session_locked.delete(key_expr);

    publication_builder
        .apply_opts(opts)?
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    Ok(rustler::types::atom::ok())
}

#[rustler::nif(schedule = "DirtyIo")]
fn session_get<'a>(
    env: rustler::Env<'a>,
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
    selector: &'a str,
    timeout: u64,
    opts: rustler::Term,
) -> rustler::NifResult<(rustler::Atom, Vec<rustler::Term<'a>>)> {
    let session_id = &session_id_resource;
    let session = SessionMap::get_session(&SESSION_MAP, session_id)?;
    // WHY: Keep the read lock only around handler creation.
    //      If session_locked lives through the reply loop, write-lock operations such as
    //      undeclare or session close can be blocked until timeout.
    let channel_handler = {
        let session_locked = session.read().unwrap();
        let session_get_builder = session_locked.get(selector);

        session_get_builder
            .apply_opts(opts)?
            .wait()
            .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?
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
fn session_new_timestamp(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
) -> rustler::NifResult<(rustler::Atom, String)> {
    let session_id = &session_id_resource;
    let session = SessionMap::get_session(&SESSION_MAP, session_id)?;
    let session_locked = session.read().unwrap();
    let timestamp = session_locked.new_timestamp().to_string_rfc3339_lossy();

    Ok((rustler::types::atom::ok(), timestamp))
}

#[rustler::nif]
fn session_info(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
) -> rustler::NifResult<(rustler::Atom, ZenohexSessionInfo)> {
    let session_id = &session_id_resource;
    let session = SessionMap::get_session(&SESSION_MAP, session_id)?;
    let session_locked = session.read().unwrap();
    let zenohex_session_info = session_locked.info().into();

    Ok((rustler::types::atom::ok(), zenohex_session_info))
}

#[rustler::nif]
fn session_declare_publisher(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
    key_expr: String,
    opts: rustler::Term,
) -> rustler::NifResult<(rustler::Atom, rustler::ResourceArc<EntityGlobalIdResource>)> {
    let session_id = **session_id_resource;
    let session = SessionMap::get_session(&SESSION_MAP, &session_id)?;
    let mut session_locked = session.write().unwrap();

    let publisher_builder = session_locked.declare_publisher(key_expr);

    let publisher = publisher_builder
        .apply_opts(opts)?
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    let publisher_id = publisher.id();
    session_locked.insert_entity(
        publisher_id,
        Entity::Publisher(publisher, session_id_resource),
    )?;

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(EntityGlobalIdResource::new(session_id, publisher_id)),
    ))
}

#[rustler::nif]
fn session_declare_querier(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
    key_expr: String,
    opts: rustler::Term,
) -> rustler::NifResult<(rustler::Atom, rustler::ResourceArc<EntityGlobalIdResource>)> {
    let session_id = **session_id_resource;
    let session = SessionMap::get_session(&SESSION_MAP, &session_id)?;
    let mut session_locked = session.write().unwrap();

    let querier_builder = session_locked.declare_querier(key_expr);

    let querier = querier_builder
        .apply_opts(opts)?
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    let querier_id = querier.id();
    session_locked.insert_entity(querier_id, Entity::Querier(querier, session_id_resource))?;

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(EntityGlobalIdResource::new(session_id, querier_id)),
    ))
}

#[rustler::nif]
fn session_declare_subscriber(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
    key_expr: String,
    // WHY: Pass `pid` instead of using `env.pid()`
    //      so the user can specify any receiver process
    pid: rustler::LocalPid,
    opts: rustler::Term,
    channel_kind: crate::helper::forwarder::ChannelKind,
) -> rustler::NifResult<(rustler::Atom, rustler::ResourceArc<EntityGlobalIdResource>)> {
    let session_id = **session_id_resource;
    let session = SessionMap::get_session(&SESSION_MAP, &session_id)?;
    let mut session_locked = session.write().unwrap();

    let subscriber_buidler = session_locked.declare_subscriber(key_expr);

    let subscriber = subscriber_buidler
        .apply_opts(opts)?
        .with(channel_kind)
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    crate::helper::forwarder::spawn_forwarder(pid, subscriber.handler().clone(), |env, sample| {
        crate::sample::ZenohexSample::from(env, sample).encode(env)
    })?;

    let subscriber_id = subscriber.id();
    session_locked.insert_entity(
        subscriber_id,
        Entity::Subscriber(subscriber, session_id_resource),
    )?;

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(EntityGlobalIdResource::new(session_id, subscriber_id)),
    ))
}

#[rustler::nif]
fn session_declare_queryable(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
    key_expr: String,
    // WHY: Pass `pid` instead of using `env.pid()`
    //      so the user can specify any receiver process
    pid: rustler::LocalPid,
    opts: rustler::Term,
    channel_kind: crate::helper::forwarder::ChannelKind,
) -> rustler::NifResult<(rustler::Atom, rustler::ResourceArc<EntityGlobalIdResource>)> {
    let session_id = **session_id_resource;
    let session = SessionMap::get_session(&SESSION_MAP, &session_id)?;
    let mut session_locked = session.write().unwrap();

    let queryable_builder = session_locked.declare_queryable(key_expr);

    let queryable = queryable_builder
        .apply_opts(opts)?
        .with(channel_kind)
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    crate::helper::forwarder::spawn_forwarder(pid, queryable.handler().clone(), |env, query| {
        crate::query::ZenohexQuery::from(env, query).encode(env)
    })?;

    let queryable_id = queryable.id();
    session_locked.insert_entity(
        queryable_id,
        Entity::Queryable(queryable, session_id_resource),
    )?;

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(EntityGlobalIdResource::new(session_id, queryable_id)),
    ))
}
