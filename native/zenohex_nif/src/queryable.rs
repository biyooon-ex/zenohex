use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

use zenoh::Wait;

pub static QUERYABLES: LazyLock<
    Mutex<HashMap<zenoh::session::EntityGlobalId, zenoh::query::Queryable<()>>>,
> = LazyLock::new(|| Mutex::new(HashMap::new()));

pub struct ZenohQueryableId(pub zenoh::session::EntityGlobalId);
#[rustler::resource_impl]
impl rustler::Resource for ZenohQueryableId {}
// NOTE: Release the Zenoh subscriber when the Elixir process holding the ZenohQueryableId terminates.
impl Drop for ZenohQueryableId {
    fn drop(&mut self) {
        let mut queryables = QUERYABLES.lock().unwrap();
        if let Some(queryable) = queryables.remove(&self.0) {
            let _ = queryable.undeclare().wait();
        };
    }
}
