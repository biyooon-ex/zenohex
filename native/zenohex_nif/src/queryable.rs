use zenoh::Wait;

#[rustler::nif]
fn queryable_undeclare(
    entity_id_resource: rustler::ResourceArc<crate::session::EntityIdResource>,
) -> rustler::NifResult<rustler::Atom> {
    let session_id = &entity_id_resource.0.zid();
    let entity_id = &entity_id_resource.0;

    let session =
        crate::session::SessionMap::get_session(&crate::session::SESSION_MAP, session_id)?;
    let mut locked_session = session.write().unwrap();
    let entity = locked_session.remove_entity(entity_id)?;

    match entity {
        crate::session::Entity::Queryable(queryable) => {
            queryable
                .undeclare()
                .wait()
                .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

            Ok(rustler::types::atom::ok())
        }
        other => unreachable!("unexpected entity: {:#?}", other),
    }
}
