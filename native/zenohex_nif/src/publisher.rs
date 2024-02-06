use crate::PublisherRef;
use rustler::{types::atom, Binary, Encoder, Env, ResourceArc, Term};
use zenoh::{prelude::sync::SyncResolve, publication::Publisher, value::Value};

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
    value: CongestionControl,
) -> ResourceArc<PublisherRef> {
    let publisher: &Publisher = &resource.0;
    let publisher: Publisher = publisher.clone().congestion_control(value.into());

    ResourceArc::new(PublisherRef(publisher))
}

#[rustler::nif]
fn publisher_priority(
    resource: ResourceArc<PublisherRef>,
    value: Priority,
) -> ResourceArc<PublisherRef> {
    let publisher: &Publisher = &resource.0;
    let publisher: Publisher = publisher.clone().priority(value.into());

    ResourceArc::new(PublisherRef(publisher))
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Publisher.Options"]
pub(crate) struct PublisherOptions {
    pub(crate) congestion_control: CongestionControl,
    pub(crate) priority: Priority,
}

#[derive(rustler::NifUnitEnum)]
pub(crate) enum CongestionControl {
    Drop,
    Block,
}

impl From<CongestionControl> for zenoh::publication::CongestionControl {
    fn from(value: CongestionControl) -> Self {
        match value {
            CongestionControl::Drop => zenoh::publication::CongestionControl::Drop,
            CongestionControl::Block => zenoh::publication::CongestionControl::Block,
        }
    }
}

#[derive(rustler::NifUnitEnum)]
pub(crate) enum Priority {
    RealTime,
    InteractiveHigh,
    InteractiveLow,
    DataHigh,
    Data,
    DataLow,
    Background,
}

impl From<Priority> for zenoh::publication::Priority {
    fn from(value: Priority) -> Self {
        match value {
            Priority::RealTime => zenoh::publication::Priority::RealTime,
            Priority::InteractiveHigh => zenoh::publication::Priority::InteractiveHigh,
            Priority::InteractiveLow => zenoh::publication::Priority::InteractiveLow,
            Priority::DataHigh => zenoh::publication::Priority::DataHigh,
            Priority::Data => zenoh::publication::Priority::Data,
            Priority::DataLow => zenoh::publication::Priority::DataLow,
            Priority::Background => zenoh::publication::Priority::Background,
        }
    }
}
