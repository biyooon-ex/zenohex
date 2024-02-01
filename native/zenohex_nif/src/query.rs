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
