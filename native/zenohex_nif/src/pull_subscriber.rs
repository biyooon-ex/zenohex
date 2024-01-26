use std::time::Duration;

use flume::Receiver;
use rustler::{types::atom, Atom, Encoder, Env, ResourceArc, Term};
use zenoh::{prelude::sync::SyncResolve, sample::Sample, subscriber::PullSubscriber};

#[rustler::nif]
fn pull_subscriber_recv_timeout(
    env: Env,
    resource: ResourceArc<crate::ExPullSubscriberRef>,
    timeout_us: u64,
) -> Term {
    let pull_subscriber: &PullSubscriber<'_, Receiver<Sample>> = &resource.0;
    match pull_subscriber.recv_timeout(Duration::from_micros(timeout_us)) {
        Ok(sample) => crate::to_term(&sample.value, env),
        Err(_recv_timeout_error) => crate::atoms::timeout().encode(env),
    }
}

#[rustler::nif]
fn pull_subscriber_pull(resource: ResourceArc<crate::ExPullSubscriberRef>) -> Atom {
    let pull_subscriber: &PullSubscriber<'_, Receiver<Sample>> = &resource.0;
    pull_subscriber
        .pull()
        .res_sync()
        .expect("pull_subscriber_pull failed");
    atom::ok()
}
