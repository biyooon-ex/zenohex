use zenoh::Wait;

#[derive(rustler::NifUnitEnum)]
enum CongestionControl {
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

#[derive(rustler::NifUnitEnum)]
enum Priority {
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

pub fn put_build(
    builder: zenoh::pubsub::PublicationBuilder<
        zenoh::pubsub::PublisherBuilder<'_, '_>,
        zenoh::pubsub::PublicationBuilderPut,
    >,
    opts: rustler::Term,
) -> rustler::NifResult<()> {
    let mut opts_iter: rustler::ListIterator = opts.decode()?;

    let builder = opts_iter.try_fold(builder, |builder, opt| {
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
                Ok(builder.congestion_control(v.decode::<CongestionControl>()?.into()))
            }
            k if k == crate::atoms::express() => Ok(builder.express(v.decode::<bool>()?)),
            k if k == crate::atoms::encoding() => Ok(builder.encoding(v.decode::<&str>()?)),
            k if k == crate::atoms::priority() => {
                Ok(builder.priority(v.decode::<Priority>()?.into()))
            }
            k if k == crate::atoms::timestamp() => todo!(),
            _ => Ok(builder),
        }
    })?;

    builder
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))
}
