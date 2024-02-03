use rustler::{types::atom, Encoder, Env, ResourceArc, Term};
use zenoh::prelude::sync::SyncResolve;

use crate::ExQueryRef;

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Query"]
pub struct Query<'a> {
    key_expr: String,
    parameters: String,
    value: Term<'a>,
    reference: ResourceArc<ExQueryRef>,
}

impl Query<'_> {
    pub(crate) fn from(env: Env, query: zenoh::queryable::Query) -> Query {
        Query {
            key_expr: query.key_expr().to_string(),
            parameters: query.parameters().to_string(),
            value: match query.value() {
                Some(value) => crate::value::Value::to_term(env, value),
                None => atom::nil().encode(env),
            },
            reference: ResourceArc::new(ExQueryRef(query)),
        }
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn query_reply<'a>(env: Env<'a>, query: Query<'a>, sample: crate::sample::Sample<'a>) -> Term<'a> {
    let query: &zenoh::queryable::Query = &query.reference.0;
    let sample: &zenoh::sample::Sample = &sample.reference.0;
    match query.reply(Ok(sample.clone())).res_sync() {
        Ok(_) => atom::ok().encode(env),
        Err(error) => (atom::error(), error.to_string()).encode(env),
    }
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Query.Options"]
pub struct QueryOptions {
    pub(crate) target: QueryTarget,
    pub(crate) consolidation: ConsolidationMode,
}

#[derive(rustler::NifUnitEnum)]
pub enum QueryTarget {
    BestMatching,
    All,
    AllComplete,
}

impl From<QueryTarget> for zenoh::query::QueryTarget {
    fn from(value: QueryTarget) -> Self {
        match value {
            QueryTarget::BestMatching => zenoh::query::QueryTarget::BestMatching,
            QueryTarget::All => zenoh::query::QueryTarget::All,
            QueryTarget::AllComplete => zenoh::query::QueryTarget::AllComplete,
        }
    }
}

#[derive(rustler::NifUnitEnum)]
pub enum ConsolidationMode {
    Auto,
    None,
    Monotonic,
    Latest,
}

impl From<ConsolidationMode> for zenoh::query::QueryConsolidation {
    fn from(value: ConsolidationMode) -> Self {
        match value {
            ConsolidationMode::Auto => zenoh::query::Mode::Auto.into(),
            ConsolidationMode::None => zenoh::query::ConsolidationMode::None.into(),
            ConsolidationMode::Monotonic => zenoh::query::ConsolidationMode::Monotonic.into(),
            ConsolidationMode::Latest => zenoh::query::ConsolidationMode::Latest.into(),
        }
    }
}
