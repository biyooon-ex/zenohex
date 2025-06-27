use zenoh::Wait;

pub mod atoms {
    rustler::atoms! {
        encoding,
    }
}

#[rustler::nif]
fn publisher_put(
    entity_id_resource: rustler::ResourceArc<crate::session::EntityIdResource>,
    payload: String,
) -> rustler::NifResult<rustler::Atom> {
    let session_id = &entity_id_resource.0.zid();
    let entity_id = &entity_id_resource.0;

    let session =
        crate::session::SessionMap::get_session(&crate::session::SESSION_MAP, session_id)?;
    let locked_session = session.read().unwrap();
    let entity = locked_session.get_entity(entity_id)?;

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
    entity_id_resource: rustler::ResourceArc<crate::session::EntityIdResource>,
) -> rustler::NifResult<rustler::Atom> {
    let session_id = &entity_id_resource.0.zid();
    let entity_id = &entity_id_resource.0;

    let session =
        crate::session::SessionMap::get_session(&crate::session::SESSION_MAP, session_id)?;
    let mut locked_session = session.write().unwrap();
    let entity = locked_session.remove_entity(entity_id)?;

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
