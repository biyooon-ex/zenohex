use zenoh::Wait;

#[rustler::nif]
fn publisher_put(
    entity_global_id_resource: rustler::ResourceArc<crate::session::EntityGlobalIdResource>,
    payload: String,
) -> rustler::NifResult<rustler::Atom> {
    let session_id = &entity_global_id_resource.zid();
    let entity_global_id = &entity_global_id_resource;

    let session =
        crate::session::SessionMap::get_session(&crate::session::SESSION_MAP, session_id)?;
    let session_locked = session.read().unwrap();
    let entity = session_locked.get_entity(entity_global_id)?;

    match entity {
        crate::session::Entity::Publisher(publisher, _) => {
            publisher
                .put(payload)
                .wait()
                .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

            Ok(rustler::types::atom::ok())
        }
        _ => unreachable!("unexpected entity"),
    }
}

#[rustler::nif]
fn publisher_undeclare(
    entity_global_id_resource: rustler::ResourceArc<crate::session::EntityGlobalIdResource>,
) -> rustler::NifResult<rustler::Atom> {
    let session_id = &entity_global_id_resource.zid();
    let entity_global_id = &entity_global_id_resource;

    let session =
        crate::session::SessionMap::get_session(&crate::session::SESSION_MAP, session_id)?;
    let mut session_locked = session.write().unwrap();
    let entity = session_locked.remove_entity(entity_global_id)?;

    match entity {
        crate::session::Entity::Publisher(publisher, _) => {
            publisher
                .undeclare()
                .wait()
                .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

            Ok(rustler::types::atom::ok())
        }
        _ => unreachable!("unexpected entity"),
    }
}
