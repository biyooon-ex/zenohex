use std::sync::RwLock;

use rustler::{types::atom, Encoder, Env, ErlOption, ResourceArc, Term};

use crate::{QueryRef, SampleRef};

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Query"]
pub(crate) struct ExQuery<'a> {
    key_expr: String,
    parameters: String,
    value: ErlOption<Term<'a>>,
    reference: ResourceArc<QueryRef>,
}

impl ExQuery<'_> {
    pub(crate) fn from(env: Env, query: zenoh::query::Query) -> ExQuery {
        ExQuery {
            key_expr: query.key_expr().to_string(),
            parameters: query.parameters().to_string(),
            value: match query.payload() {
                Some(value) => ErlOption::some(crate::value::ExValue::from(env, value)),
                None => ErlOption::none(),
            },
            reference: ResourceArc::new(QueryRef(RwLock::new(Some(query)))),
        }
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn query_reply<'a>(
    env: Env<'a>,
    query: ExQuery<'a>,
    sample: crate::sample::ExSample<'a>,
) -> Term<'a> {
    let lock: &RwLock<Option<zenoh::query::Query>> = &query.reference.0;
    let guard = match lock.read() {
        Ok(guard) => guard,
        Err(error) => return (atom::error(), error.to_string()).encode(env),
    };
    let query: &zenoh::query::Query = match &*guard {
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
        match Option::<ResourceArc<SampleRef>>::from(sample.reference.clone()) {
            Some(resource) => resource.0.clone(),
            None => sample.into(),
        };
    match query.reply(Ok(sample)).wait() {
        Ok(_) => atom::ok().encode(env),
        Err(error) => (atom::error(), error.to_string()).encode(env),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn query_finish_reply<'a>(env: Env<'a>, query: ExQuery<'a>) -> Term<'a> {
    let lock: &RwLock<Option<zenoh::query::Query>> = &query.reference.0;
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
pub(crate) struct ExQueryOptions {
    pub(crate) target: ExQueryTarget,
    pub(crate) consolidation: ExConsolidationMode,
}

#[derive(rustler::NifUnitEnum)]
pub(crate) enum ExQueryTarget {
    BestMatching,
    All,
    AllComplete,
}

impl From<ExQueryTarget> for zenoh::query::QueryTarget {
    fn from(value: ExQueryTarget) -> Self {
        match value {
            ExQueryTarget::BestMatching => zenoh::query::QueryTarget::BestMatching,
            ExQueryTarget::All => zenoh::query::QueryTarget::All,
            ExQueryTarget::AllComplete => zenoh::query::QueryTarget::AllComplete,
        }
    }
}

#[derive(rustler::NifUnitEnum)]
pub(crate) enum ExConsolidationMode {
    Auto,
    None,
    Monotonic,
    Latest,
}

impl From<ExConsolidationMode> for zenoh::query::QueryConsolidation {
    fn from(value: ExConsolidationMode) -> Self {
        match value {
            ExConsolidationMode::Auto => zenoh::query::ConsolidationMode::Auto.into(),
            ExConsolidationMode::None => zenoh::query::ConsolidationMode::None.into(),
            ExConsolidationMode::Monotonic => zenoh::query::ConsolidationMode::Monotonic.into(),
            ExConsolidationMode::Latest => zenoh::query::ConsolidationMode::Latest.into(),
        }
    }
}
