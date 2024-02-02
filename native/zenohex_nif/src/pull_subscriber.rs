use std::time::Duration;

use flume::Receiver;
use rustler::{types::atom, Encoder, Env, ResourceArc, Term};
use zenoh::{prelude::sync::SyncResolve, sample::Sample, subscriber::PullSubscriber};

#[rustler::nif]
fn pull_subscriber_recv_timeout(
    env: Env,
    resource: ResourceArc<crate::ExPullSubscriberRef>,
    timeout_us: u64,
) -> Result<Term, Term> {
    let pull_subscriber: &PullSubscriber<'_, Receiver<Sample>> = &resource.0;
    match pull_subscriber.recv_timeout(Duration::from_micros(timeout_us)) {
        Ok(sample) => Ok(crate::sample::Sample::from(env, sample).encode(env)),
        Err(_recv_timeout_error) => Err(crate::atoms::timeout().encode(env)),
    }
}

#[rustler::nif]
fn pull_subscriber_pull(env: Env, resource: ResourceArc<crate::ExPullSubscriberRef>) -> Term {
    let pull_subscriber: &PullSubscriber<'_, Receiver<Sample>> = &resource.0;
    match pull_subscriber.pull().res_sync() {
        Ok(_) => atom::ok().encode(env),
        Err(error) => (atom::error(), error.to_string()).encode(env),
    }
}
