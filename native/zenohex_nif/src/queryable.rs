use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

pub static QUERYABLES: LazyLock<
    Mutex<HashMap<zenoh::session::EntityGlobalId, zenoh::query::Queryable<()>>>,
> = LazyLock::new(|| Mutex::new(HashMap::new()));

pub struct ZenohQueryableId(pub zenoh::session::EntityGlobalId);
#[rustler::resource_impl]
impl rustler::Resource for ZenohQueryableId {}
