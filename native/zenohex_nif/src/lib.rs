use std::sync::Arc;

use flume::Receiver;
use rustler::{Env, ResourceArc, Term};
use zenoh::{
    prelude::sync::*, publication::Publisher, query::Reply, queryable::Query, queryable::Queryable,
    sample::Sample, subscriber::PullSubscriber, subscriber::Subscriber, Session,
};

mod atoms {
    rustler::atoms! {
        timeout,
    }
}
mod publisher;
mod pull_subscriber;
mod query;
mod queryable;
mod sample;
mod session;
mod subscriber;
mod value;

struct ExSessionRef(Arc<Session>);
struct ExPublisherRef(Publisher<'static>);
struct ExSubscriberRef(Subscriber<'static, Receiver<Sample>>);
struct ExPullSubscriberRef(PullSubscriber<'static, Receiver<Sample>>);
struct ExQueryableRef(Queryable<'static, Receiver<Query>>);
struct ExReplyReceiverRef(Receiver<Reply>);
struct ExQueryRef(Query);
struct ExSampleRef(Sample);

#[rustler::nif(schedule = "DirtyIo")]
fn zenoh_open() -> Result<ResourceArc<ExSessionRef>, String> {
    let config = config::peer();
    match zenoh::open(config).res_sync() {
        Ok(session) => Ok(ResourceArc::new(ExSessionRef(session.into_arc()))),
        Err(error) => Err(error.to_string()),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn zenoh_scouting_delay_zero_session() -> Result<ResourceArc<ExSessionRef>, String> {
    let mut config = config::peer();
    let config = match config.scouting.set_delay(Some(0)) {
        Ok(_) => config,
        Err(_) => return Err("set_delay failed".to_string()),
    };

    match zenoh::open(config).res_sync() {
        Ok(session) => Ok(ResourceArc::new(ExSessionRef(session.into_arc()))),
        Err(error) => Err(error.to_string()),
    }
}

fn load(env: Env, _term: Term) -> bool {
    rustler::resource!(ExSessionRef, env);
    rustler::resource!(ExPublisherRef, env);
    rustler::resource!(ExSubscriberRef, env);
    rustler::resource!(ExPullSubscriberRef, env);
    rustler::resource!(ExQueryableRef, env);
    rustler::resource!(ExReplyReceiverRef, env);
    rustler::resource!(ExQueryRef, env);
    rustler::resource!(ExSampleRef, env);
    true
}

rustler::init!(
    "Elixir.Zenohex.Nif",
    [
        zenoh_open,
        zenoh_scouting_delay_zero_session,
        session::declare_publisher,
        session::declare_subscriber,
        session::declare_pull_subscriber,
        session::declare_queryable,
        session::session_put_integer,
        session::session_put_float,
        session::session_put_binary,
        session::session_get_reply_receiver,
        session::session_get_reply_timeout,
        session::session_delete,
        publisher::publisher_put_integer,
        publisher::publisher_put_float,
        publisher::publisher_put_binary,
        publisher::publisher_delete,
        publisher::publisher_congestion_control,
        publisher::publisher_priority,
        subscriber::subscriber_recv_timeout,
        pull_subscriber::pull_subscriber_pull,
        pull_subscriber::pull_subscriber_recv_timeout,
        queryable::queryable_recv_timeout,
        query::query_reply,
    ],
    load = load
);
