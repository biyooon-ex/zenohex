use crate::PublisherRef;
use rustler::{types::atom, Binary, Encoder, Env, ResourceArc, Term};
use zenoh::{bytes::ZBytes, pubsub::Publisher};

#[rustler::nif]
fn publisher_put_integer(env: Env, resource: ResourceArc<PublisherRef>, value: i64) -> Term {
    publisher_put_impl(env, resource, value)
}

#[rustler::nif]
fn publisher_put_float(env: Env, resource: ResourceArc<PublisherRef>, value: f64) -> Term {
    publisher_put_impl(env, resource, value)
}

#[rustler::nif]
fn publisher_put_binary<'a>(
    env: Env<'a>,
    resource: ResourceArc<PublisherRef>,
    value: Binary<'a>,
) -> Term<'a> {
    publisher_put_impl(env, resource, Value::from(value.as_slice()))
}

fn publisher_put_impl<T: Into<zenoh::value::Value>>(
    env: Env,
    resource: ResourceArc<PublisherRef>,
    value: T,
) -> Term {
    let publisher: &Publisher = &resource.0;
    match publisher.put(value).res_sync() {
        Ok(_) => atom::ok().encode(env),
        Err(error) => (atom::error(), error.to_string()).encode(env),
    }
}

#[rustler::nif]
fn publisher_delete(env: Env, resource: ResourceArc<PublisherRef>) -> Term {
    let publisher: &Publisher = &resource.0;
    match publisher.delete().res_sync() {
        Ok(_) => atom::ok().encode(env),
        Err(error) => (atom::error(), error.to_string()).encode(env),
    }
}

#[rustler::nif]
fn publisher_congestion_control(
    resource: ResourceArc<PublisherRef>,
    value: ExCongestionControl,
) -> ResourceArc<PublisherRef> {
    let publisher: &Publisher = &resource.0;
    let publisher: Publisher = publisher.clone().congestion_control(value.into());

    ResourceArc::new(PublisherRef(publisher))
}

#[rustler::nif]
fn publisher_priority(
    resource: ResourceArc<PublisherRef>,
    value: ExPriority,
) -> ResourceArc<PublisherRef> {
    let publisher: &Publisher = &resource.0;
    let publisher: Publisher = publisher.clone().priority(value.into());

    ResourceArc::new(PublisherRef(publisher))
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Publisher.Options"]
pub(crate) struct ExPublisherOptions {
    pub(crate) congestion_control: ExCongestionControl,
    pub(crate) priority: ExPriority,
}

#[derive(rustler::NifUnitEnum)]
pub(crate) enum ExCongestionControl {
    Drop,
    Block,
}

impl From<ExCongestionControl> for zenoh::publication::CongestionControl {
    fn from(value: ExCongestionControl) -> Self {
        match value {
            ExCongestionControl::Drop => zenoh::publication::CongestionControl::Drop,
            ExCongestionControl::Block => zenoh::publication::CongestionControl::Block,
        }
    }
}

#[derive(rustler::NifUnitEnum)]
pub(crate) enum ExPriority {
    RealTime,
    InteractiveHigh,
    InteractiveLow,
    DataHigh,
    Data,
    DataLow,
    Background,
}

impl From<ExPriority> for zenoh::publication::Priority {
    fn from(value: ExPriority) -> Self {
        match value {
            ExPriority::RealTime => zenoh::publication::Priority::RealTime,
            ExPriority::InteractiveHigh => zenoh::publication::Priority::InteractiveHigh,
            ExPriority::InteractiveLow => zenoh::publication::Priority::InteractiveLow,
            ExPriority::DataHigh => zenoh::publication::Priority::DataHigh,
            ExPriority::Data => zenoh::publication::Priority::Data,
            ExPriority::DataLow => zenoh::publication::Priority::DataLow,
            ExPriority::Background => zenoh::publication::Priority::Background,
        }
    }
}
