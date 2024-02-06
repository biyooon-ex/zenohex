use std::sync::RwLock;

use rustler::{types::atom, Encoder, Env, ErlOption, ResourceArc, Term};
use zenoh::prelude::sync::SyncResolve;

use crate::{QueryRef, SampleRef};

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Query"]
pub(crate) struct Query<'a> {
    key_expr: String,
    parameters: String,
    value: ErlOption<Term<'a>>,
    reference: ResourceArc<QueryRef>,
}

impl Query<'_> {
    pub(crate) fn from(env: Env, query: zenoh::queryable::Query) -> Query {
        Query {
            key_expr: query.key_expr().to_string(),
            parameters: query.parameters().to_string(),
            value: match query.value() {
                Some(value) => ErlOption::some(crate::value::Value::to_term(env, value)),
                None => ErlOption::none(),
            },
            reference: ResourceArc::new(QueryRef(RwLock::new(Some(query)))),
        }
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn query_reply<'a>(env: Env<'a>, query: Query<'a>, sample: crate::sample::Sample<'a>) -> Term<'a> {
    let lock: &RwLock<Option<zenoh::queryable::Query>> = &query.reference.0;
    let guard = match lock.read() {
        Ok(guard) => guard,
        Err(error) => return (atom::error(), error.to_string()).encode(env),
    };
    let query: &zenoh::queryable::Query = match &*guard {
        Some(query) => query,
        None => {
            return (
                atom::error(),
                "ResponseFinal has already been sent".to_string(),
            )
                .encode(env)
        }
    };
    let sample: zenoh::sample::Sample =
        match Option::<ResourceArc<SampleRef>>::from(sample.reference) {
            Some(resource) => resource.0.clone(),
            None => todo!(), // TODO: Zenoh 外のデータから Sample を作る場合に実装する
        };
    match query.reply(Ok(sample)).res_sync() {
        Ok(_) => atom::ok().encode(env),
        Err(error) => (atom::error(), error.to_string()).encode(env),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn query_finish_reply<'a>(env: Env<'a>, query: Query<'a>) -> Term<'a> {
    let lock: &RwLock<Option<zenoh::queryable::Query>> = &query.reference.0;
    let mut guard = match lock.write() {
        Ok(guard) => guard,
        Err(error) => return (atom::error(), error.to_string()).encode(env),
    };
    match Option::take(&mut *guard) {
        Some(query) => {
            // When Query drops, ResponseFinal is sent.
            // So we need to drop the query at the end of the reply by calling this function.
            drop(query);
            atom::ok().encode(env)
        }
        None => {
            return (
                atom::error(),
                "ResponseFinal has already been sent".to_string(),
            )
                .encode(env)
        }
    }
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Query.Options"]
pub(crate) struct QueryOptions {
    pub(crate) target: QueryTarget,
    pub(crate) consolidation: ConsolidationMode,
}

#[derive(rustler::NifUnitEnum)]
pub(crate) enum QueryTarget {
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
pub(crate) enum ConsolidationMode {
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
