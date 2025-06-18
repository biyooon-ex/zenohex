use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

use zenoh::Wait;

pub static QUERYABLES: LazyLock<
    Mutex<HashMap<zenoh::session::EntityGlobalId, zenoh::query::Queryable<()>>>,
> = LazyLock::new(|| Mutex::new(HashMap::new()));

pub struct ZenohQueryableId(pub zenoh::session::EntityGlobalId);
#[rustler::resource_impl]
impl rustler::Resource for ZenohQueryableId {}

#[rustler::nif]
fn queryable_undeclare(
    zenoh_queryable_id_resource: rustler::ResourceArc<ZenohQueryableId>,
) -> rustler::NifResult<rustler::Atom> {
    let mut queryables = QUERYABLES.lock().unwrap();
    let queryable_id = zenoh_queryable_id_resource.0;

    let queryable = queryables
        .remove(&queryable_id)
        .ok_or_else(|| rustler::Error::Term(Box::new("queryable not found")))?;

    queryable
        .undeclare()
        .wait()
        .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

    Ok(rustler::types::atom::ok())
}
