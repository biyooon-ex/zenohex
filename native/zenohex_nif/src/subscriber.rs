use std::time::Duration;

use flume::{Receiver, RecvTimeoutError};
use rustler::{Encoder, Env, ResourceArc, Term};
use zenoh::{pubsub::Subscriber, sample::Sample};

#[rustler::nif(schedule = "DirtyIo")]
fn subscriber_recv_timeout(
    env: Env,
    resource: ResourceArc<crate::SubscriberRef>,
    timeout_us: u64,
) -> Result<Term, Term> {
    let subscriber: &Subscriber<'_, Receiver<Sample>> = &resource.0;
    match subscriber.recv_timeout(Duration::from_micros(timeout_us)) {
        Ok(sample) => Ok(crate::sample::ExSample::from(env, sample).encode(env)),
        Err(RecvTimeoutError::Timeout) => Err(crate::atoms::timeout().encode(env)),
        Err(RecvTimeoutError::Disconnected) => Err(crate::atoms::disconnected().encode(env)),
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
