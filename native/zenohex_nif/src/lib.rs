use std::sync::{Arc, RwLock};

use flume::Receiver;
use rustler::{Env, Resource, ResourceArc, Term};
use zenoh::{
    prelude::sync::*, publication::Publisher, query::Reply, queryable::Query, queryable::Queryable,
    sample::Sample, subscriber::PullSubscriber, subscriber::Subscriber, Session,
};

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
    env.register::<SessionRef>().unwrap();
    env.register::<PublisherRef>().unwrap();
    env.register::<SubscriberRef>().unwrap();
    env.register::<PullSubscriberRef>().unwrap();
    env.register::<QueryableRef>().unwrap();
    env.register::<ReplyReceiverRef>().unwrap();
    env.register::<QueryRef>().unwrap();
    env.register::<SampleRef>().unwrap();
    true
}

rustler::init!("Elixir.Zenohex.Nif", load = load);
