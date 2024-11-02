use std::sync::{Arc, RwLock};

use flume::Receiver;
use rustler::{Env, ResourceArc, Term};
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

#[rustler::nif(schedule = "DirtyIo")]
fn zenoh_open(config: crate::config::ExConfig) -> Result<ResourceArc<SessionRef>, String> {
    let config: zenoh::prelude::config::Config = config.into();
    match zenoh::open(config).res_sync() {
        Ok(session) => Ok(ResourceArc::new(SessionRef(session.into_arc()))),
        Err(error) => Err(error.to_string()),
    }
}

fn load(env: Env, _term: Term) -> bool {
    rustler::resource!(SessionRef, env);
    rustler::resource!(PublisherRef, env);
    rustler::resource!(SubscriberRef, env);
    rustler::resource!(PullSubscriberRef, env);
    rustler::resource!(QueryableRef, env);
    rustler::resource!(ReplyReceiverRef, env);
    rustler::resource!(QueryRef, env);
    rustler::resource!(SampleRef, env);
    true
}

rustler::init!("Elixir.Zenohex.Nif", load = load);
