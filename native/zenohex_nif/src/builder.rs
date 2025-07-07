#[derive(rustler::NifUnitEnum)]
pub enum CongestionControl {
    Drop,
    Block,
}

impl From<CongestionControl> for zenoh::qos::CongestionControl {
    fn from(value: CongestionControl) -> Self {
        match value {
            CongestionControl::Drop => zenoh::qos::CongestionControl::Drop,
            CongestionControl::Block => zenoh::qos::CongestionControl::Block,
        }
    }
}

impl From<zenoh::qos::CongestionControl> for CongestionControl {
    fn from(value: zenoh::qos::CongestionControl) -> Self {
        match value {
            zenoh::qos::CongestionControl::Drop => CongestionControl::Drop,
            zenoh::qos::CongestionControl::Block => CongestionControl::Block,
        }
    }
}

#[derive(rustler::NifUnitEnum)]
pub enum Priority {
    RealTime,
    InteractiveHigh,
    InteractiveLow,
    DataHigh,
    Data,
    DataLow,
    Background,
}

impl From<Priority> for zenoh::qos::Priority {
    fn from(value: Priority) -> Self {
        match value {
            Priority::RealTime => zenoh::qos::Priority::RealTime,
            Priority::InteractiveHigh => zenoh::qos::Priority::InteractiveHigh,
            Priority::InteractiveLow => zenoh::qos::Priority::InteractiveLow,
            Priority::DataHigh => zenoh::qos::Priority::DataHigh,
            Priority::Data => zenoh::qos::Priority::Data,
            Priority::DataLow => zenoh::qos::Priority::DataLow,
            Priority::Background => zenoh::qos::Priority::Background,
        }
    }
}

impl From<zenoh::qos::Priority> for Priority {
    fn from(value: zenoh::qos::Priority) -> Self {
        match value {
            zenoh::qos::Priority::RealTime => Priority::RealTime,
            zenoh::qos::Priority::InteractiveHigh => Priority::InteractiveHigh,
            zenoh::qos::Priority::InteractiveLow => Priority::InteractiveLow,
            zenoh::qos::Priority::DataHigh => Priority::DataHigh,
            zenoh::qos::Priority::Data => Priority::Data,
            zenoh::qos::Priority::DataLow => Priority::DataLow,
            zenoh::qos::Priority::Background => Priority::Background,
        }
    }
}

#[derive(rustler::NifUnitEnum)]
enum QueryTarget {
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
enum QueryConsolidation {
    Auto,
    None,
    Monotonic,
    Latest,
}

impl From<QueryConsolidation> for zenoh::query::ConsolidationMode {
    fn from(value: QueryConsolidation) -> Self {
        match value {
            QueryConsolidation::Auto => zenoh::query::ConsolidationMode::Auto,
            QueryConsolidation::None => zenoh::query::ConsolidationMode::None,
            QueryConsolidation::Monotonic => zenoh::query::ConsolidationMode::Monotonic,
            QueryConsolidation::Latest => zenoh::query::ConsolidationMode::Latest,
        }
    }
}

pub trait Builder: Sized {
    fn apply_opts(self, opts: rustler::Term) -> rustler::NifResult<Self>
    where
        Self: Sized;
}

impl Builder
    for zenoh::pubsub::PublicationBuilder<
        zenoh::pubsub::PublisherBuilder<'_, '_>,
        zenoh::pubsub::PublicationBuilderPut,
    >
{
    fn apply_opts(self, opts: rustler::Term) -> rustler::NifResult<Self> {
        let mut opts_iter: rustler::ListIterator = opts.decode()?;

        opts_iter.try_fold(self, |builder, opt| {
            let (k, v): (rustler::Atom, rustler::Term) = opt.decode()?;
            match k {
                k if k == crate::atoms::attachment() => {
                    if let Some(binary) = v.decode::<Option<rustler::Binary>>()? {
                        Ok(builder.attachment(binary.as_slice()))
                    } else {
                        Ok(builder)
                    }
                }
                k if k == crate::atoms::congestion_control() => {
                    let congestion_control = v.decode::<CongestionControl>()?;
                    Ok(builder.congestion_control(congestion_control.into()))
                }
                k if k == crate::atoms::encoding() => {
                    let encoding = v.decode::<&str>()?;
                    Ok(builder.encoding(encoding))
                }
                k if k == crate::atoms::express() => {
                    let express = v.decode()?;
                    Ok(builder.express(express))
                }
                k if k == crate::atoms::priority() => {
                    Ok(builder.priority(v.decode::<Priority>()?.into()))
                }
                k if k == crate::atoms::timestamp() => todo!(),
                _ => Ok(builder),
            }
        })
    }
}

impl Builder
    for zenoh::pubsub::PublicationBuilder<
        zenoh::pubsub::PublisherBuilder<'_, '_>,
        zenoh::pubsub::PublicationBuilderDelete,
    >
{
    fn apply_opts(self, opts: rustler::Term) -> rustler::NifResult<Self> {
        let mut opts_iter: rustler::ListIterator = opts.decode()?;

        opts_iter.try_fold(self, |builder, opt| {
            let (k, v): (rustler::Atom, rustler::Term) = opt.decode()?;
            match k {
                k if k == crate::atoms::attachment() => {
                    if let Some(binary) = v.decode::<Option<rustler::Binary>>()? {
                        Ok(builder.attachment(binary.as_slice()))
                    } else {
                        Ok(builder)
                    }
                }
                k if k == crate::atoms::congestion_control() => {
                    let congestion_control = v.decode::<CongestionControl>()?;
                    Ok(builder.congestion_control(congestion_control.into()))
                }
                k if k == crate::atoms::express() => {
                    let express = v.decode()?;
                    Ok(builder.express(express))
                }
                k if k == crate::atoms::priority() => {
                    Ok(builder.priority(v.decode::<Priority>()?.into()))
                }
                k if k == crate::atoms::timestamp() => todo!(),
                _ => Ok(builder),
            }
        })
    }
}

impl Builder for zenoh::session::SessionGetBuilder<'_, '_, zenoh::handlers::DefaultHandler> {
    fn apply_opts(self, opts: rustler::Term) -> rustler::NifResult<Self> {
        let mut opts_iter: rustler::ListIterator = opts.decode()?;

        opts_iter.try_fold(self, |builder, opt| {
            let (k, v): (rustler::Atom, rustler::Term) = opt.decode()?;
            match k {
                k if k == crate::atoms::attachment() => {
                    if let Some(binary) = v.decode::<Option<rustler::Binary>>()? {
                        Ok(builder.attachment(binary.as_slice()))
                    } else {
                        Ok(builder)
                    }
                }
                k if k == crate::atoms::congestion_control() => {
                    let congestion_control = v.decode::<CongestionControl>()?;
                    Ok(builder.congestion_control(congestion_control.into()))
                }
                k if k == crate::atoms::consolidation() => {
                    let consolidation = v.decode::<QueryConsolidation>()?;
                    Ok(builder
                        .consolidation::<zenoh::query::ConsolidationMode>(consolidation.into()))
                }
                k if k == crate::atoms::express() => {
                    let express = v.decode()?;
                    Ok(builder.express(express))
                }
                k if k == crate::atoms::encoding() => {
                    let encoding = v.decode::<&str>()?;
                    Ok(builder.encoding(encoding))
                }
                k if k == crate::atoms::payload() => {
                    if let Some(binary) = v.decode::<Option<rustler::Binary>>()? {
                        Ok(builder.payload(binary.as_slice()))
                    } else {
                        Ok(builder)
                    }
                }
                k if k == crate::atoms::priority() => {
                    let priority = v.decode::<Priority>()?;
                    Ok(builder.priority(priority.into()))
                }
                k if k == crate::atoms::target() => {
                    let target = v.decode::<QueryTarget>()?;
                    Ok(builder.target(target.into()))
                }
                _ => Ok(builder),
            }
        })
    }
}

impl Builder for zenoh::pubsub::PublisherBuilder<'_, '_> {
    fn apply_opts(self, opts: rustler::Term) -> rustler::NifResult<Self> {
        let mut opts_iter: rustler::ListIterator = opts.decode()?;

        opts_iter.try_fold(self, |builder, opt| {
            let (k, v): (rustler::Atom, rustler::Term) = opt.decode()?;
            match k {
                k if k == crate::atoms::congestion_control() => {
                    let congestion_control = v.decode::<CongestionControl>()?;
                    Ok(builder.congestion_control(congestion_control.into()))
                }
                k if k == crate::atoms::encoding() => {
                    let encoding = v.decode::<&str>()?;
                    Ok(builder.encoding(encoding))
                }
                k if k == crate::atoms::express() => {
                    let express = v.decode()?;
                    Ok(builder.express(express))
                }
                k if k == crate::atoms::priority() => {
                    Ok(builder.priority(v.decode::<Priority>()?.into()))
                }
                _ => Ok(builder),
            }
        })
    }
}

impl Builder for zenoh::pubsub::SubscriberBuilder<'_, '_, zenoh::handlers::DefaultHandler> {
    fn apply_opts(self, opts: rustler::Term) -> rustler::NifResult<Self> {
        let mut opts_iter: rustler::ListIterator = opts.decode()?;

        opts_iter.try_fold(self, |builder, opt| {
            let (_k, _v): (rustler::Atom, rustler::Term) = opt.decode()?;
            Ok(builder)
        })
    }
}

impl Builder for zenoh::query::QueryableBuilder<'_, '_, zenoh::handlers::DefaultHandler> {
    fn apply_opts(self, opts: rustler::Term) -> rustler::NifResult<Self> {
        let mut opts_iter: rustler::ListIterator = opts.decode()?;

        opts_iter.try_fold(self, |builder, opt| {
            let (k, v): (rustler::Atom, rustler::Term) = opt.decode()?;
            match k {
                k if k == crate::atoms::complete() => {
                    let complete = v.decode()?;
                    Ok(builder.complete(complete))
                }
                _ => Ok(builder),
            }
        })
    }
}
