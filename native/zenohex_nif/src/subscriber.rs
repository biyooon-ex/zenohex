use std::time::Duration;

use flume::Receiver;
use rustler::{Encoder, Env, ResourceArc, Term};
use zenoh::{sample::Sample, subscriber::Subscriber};

#[rustler::nif(schedule = "DirtyIo")]
fn subscriber_recv_timeout(
    env: Env,
    resource: ResourceArc<crate::SubscriberRef>,
    timeout_us: u64,
) -> Result<Term, Term> {
    let subscriber: &Subscriber<'_, Receiver<Sample>> = &resource.0;
    match subscriber.recv_timeout(Duration::from_micros(timeout_us)) {
        Ok(sample) => Ok(crate::sample::ExSample::from(env, sample).encode(env)),
        Err(_recv_timeout_error) => Err(crate::atoms::timeout().encode(env)),
    }
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Subscriber.Options"]
pub(crate) struct SubscriberOptions {
    pub(crate) reliability: ExReliability,
}

#[derive(rustler::NifUnitEnum)]
pub(crate) enum ExReliability {
    BestEffort,
    Reliable,
}

impl From<ExReliability> for zenoh::subscriber::Reliability {
    fn from(value: ExReliability) -> Self {
        match value {
            ExReliability::BestEffort => zenoh::subscriber::Reliability::BestEffort,
            ExReliability::Reliable => zenoh::subscriber::Reliability::Reliable,
        }
    }
}
