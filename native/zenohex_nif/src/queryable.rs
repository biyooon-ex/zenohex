use std::time::Duration;

use flume::{Receiver, RecvTimeoutError};
use rustler::{Encoder, Env, ResourceArc, Term};
use zenoh::query::{Query, Queryable};

use crate::{atoms, QueryableRef};

#[rustler::nif(schedule = "DirtyIo")]
fn queryable_recv_timeout(
    env: Env,
    resource: ResourceArc<QueryableRef>,
    timeout_us: u64,
) -> Result<Term, Term> {
    let queryable: &Queryable<Receiver<Query>> = &resource.0;
    match queryable.recv_timeout(Duration::from_micros(timeout_us)) {
        Ok(query) => Ok(crate::query::ExQuery::from(env, query).encode(env)),
        Err(RecvTimeoutError::Timeout) => Err(atoms::timeout().encode(env)),
        Err(RecvTimeoutError::Disconnected) => Err(atoms::disconnected().encode(env)),
    }
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Queryable.Options"]
pub(crate) struct ExQueryableOptions {
    pub(crate) complete: bool,
}
