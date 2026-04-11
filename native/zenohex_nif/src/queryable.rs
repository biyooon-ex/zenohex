use zenoh::Wait;

#[rustler::nif]
fn queryable_undeclare(
    entity_global_id_resource: rustler::ResourceArc<crate::session::EntityGlobalIdResource>,
) -> rustler::NifResult<rustler::Atom> {
    let session_id = &entity_global_id_resource.zid();
    let entity_global_id = &entity_global_id_resource;

    let session =
        crate::session::SessionMap::get_session(&crate::session::SESSION_MAP, session_id)?;
    let mut session_locked = session.write().unwrap();

    let is_queryable = matches!(
        session_locked.get_entity(entity_global_id)?,
        crate::session::Entity::Queryable(_, _)
    );

    if !is_queryable {
        return Err(rustler::Error::Term(Box::new(
            crate::atoms::unsupported_entity(),
        )));
    }

    let entity = session_locked.remove_entity(entity_global_id)?;
    let crate::session::Entity::Queryable(queryable, _) = entity else {
        unreachable!("entity kind changed after queryable check")
    };

    queryable
        .undeclare()
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    Ok(rustler::types::atom::ok())
}
