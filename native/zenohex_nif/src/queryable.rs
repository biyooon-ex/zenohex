use std::time::Duration;

use flume::Receiver;
use rustler::{Encoder, Env, ResourceArc, Term};
use zenoh::queryable::{Query, Queryable};

use crate::{atoms, QueryableRef};

#[rustler::nif(schedule = "DirtyIo")]
fn queryable_recv_timeout(
    env: Env,
    resource: ResourceArc<QueryableRef>,
    timeout_us: u64,
) -> Result<Term, Term> {
    let queryable: &Queryable<'_, Receiver<Query>> = &resource.0;
    match queryable.recv_timeout(Duration::from_micros(timeout_us)) {
        Ok(query) => Ok(crate::query::Query::from(env, query).encode(env)),
        Err(_recv_timeout_error) => Err(atoms::timeout().encode(env)),
    }
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Queryable.Options"]
pub(crate) struct QueryableOptions {
    pub(crate) complete: bool,
}
