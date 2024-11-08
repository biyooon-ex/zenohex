use std::sync::{Arc, RwLock};

use flume::Receiver;
use rustler::{Env, Resource, ResourceArc, Term};
use zenoh::pubsub::{Publisher, Subscriber};
use zenoh::query::{Query, Queryable, Reply};
use zenoh::sample::Sample;
use zenoh::session::Session;

mod atoms {
    rustler::atoms! {
        timeout,
        disconnected,
    }
}
mod config;
mod keyexpr;
mod publisher;
mod pull_subscriber;
mod query;
mod queryable;
mod sample;
mod session;
mod subscriber;
mod value;

struct SessionRef(Arc<Session>);
struct PublisherRef(Publisher<'static>);
struct SubscriberRef(Subscriber<'static, Receiver<Sample>>);
struct PullSubscriberRef(PullSubscriber<'static, Receiver<Sample>>);
struct QueryableRef(Queryable<'static, Receiver<Query>>);
struct ReplyReceiverRef(Receiver<Reply>);
struct QueryRef(RwLock<Option<Query>>);
struct SampleRef(Sample);

impl Resource for SessionRef {}
impl Resource for PublisherRef {}
impl Resource for SubscriberRef {}
impl Resource for PullSubscriberRef {}
impl Resource for QueryableRef {}
impl Resource for ReplyReceiverRef {}
impl Resource for QueryRef {}
impl Resource for SampleRef {}

#[rustler::nif(schedule = "DirtyIo")]
fn zenoh_open(config: crate::config::ExConfig) -> Result<ResourceArc<SessionRef>, String> {
    let config: zenoh::prelude::config::Config = config.into();
    match zenoh::open(config).res_sync() {
        Ok(session) => Ok(ResourceArc::new(SessionRef(session.into_arc()))),
        Err(error) => Err(error.to_string()),
    }
}

fn load(env: Env, _term: Term) -> bool {
    env.register::<SessionRef>().is_ok()
        && env.register::<PublisherRef>().is_ok()
        && env.register::<SubscriberRef>().is_ok()
        && env.register::<PullSubscriberRef>().is_ok()
        && env.register::<QueryableRef>().is_ok()
        && env.register::<ReplyReceiverRef>().is_ok()
        && env.register::<QueryRef>().is_ok()
        && env.register::<SampleRef>().is_ok()
}

rustler::init!("Elixir.Zenohex.Nif", load = load);
