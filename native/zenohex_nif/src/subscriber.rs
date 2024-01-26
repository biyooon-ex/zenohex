use std::time::Duration;

use flume::Receiver;
use rustler::{Encoder, Env, ResourceArc, Term};
use zenoh::{sample::Sample, subscriber::Subscriber};

#[rustler::nif]
fn subscriber_recv_timeout(
    env: Env,
    resource: ResourceArc<crate::ExSubscriberRef>,
    timeout_us: u64,
) -> Term {
    let subscriber: &Subscriber<'_, Receiver<Sample>> = &resource.0;
    match subscriber.recv_timeout(Duration::from_micros(timeout_us)) {
        Ok(sample) => crate::to_term(&sample.value, env),
        Err(_recv_timeout_error) => crate::atoms::timeout().encode(env),
    }
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Subscriber.Options"]
pub struct SubscriberOptions {
    pub(crate) reliability: Reliability,
}

#[derive(rustler::NifUnitEnum)]
pub enum Reliability {
    BestEffort,
    Reliable,
}

impl From<Reliability> for zenoh::subscriber::Reliability {
    fn from(value: Reliability) -> Self {
        match value {
            Reliability::BestEffort => zenoh::subscriber::Reliability::BestEffort,
            Reliability::Reliable => zenoh::subscriber::Reliability::Reliable,
        }
    }
}
