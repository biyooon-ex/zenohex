use std::sync::Arc;

use flume::Receiver;
use rustler::types::atom;
use rustler::{thread, Encoder};
use rustler::{Atom, Env, ResourceArc, Term};
use zenoh::prelude::sync::*;
use zenoh::{
    publication::Publisher, queryable::Queryable, subscriber::PullSubscriber,
    subscriber::Subscriber, Session,
};
use zenoh::{query::Reply, queryable::Query, sample::Sample};

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

pub struct ExSessionRef(Arc<Session>);
pub struct ExPublisherRef(Publisher<'static>);
pub struct ExSubscriberRef(Subscriber<'static, Receiver<Sample>>);
pub struct ExPullSubscriberRef(PullSubscriber<'static, Receiver<Sample>>);
pub struct ExQueryableRef(Queryable<'static, Receiver<Query>>);
pub struct ExReplyReceiverRef(Receiver<Reply>);

#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

#[rustler::nif]
fn test_thread(env: Env) -> Atom {
    let pid = env.pid();
    thread::spawn::<thread::ThreadSpawner, _>(env, move |thread_env| pid.encode(thread_env));
    atom::ok()
}

#[rustler::nif]
fn zenoh_open() -> Result<ResourceArc<ExSessionRef>, String> {
    let config = config::peer();
    match zenoh::open(config).res_sync() {
        Ok(session) => Ok(ResourceArc::new(ExSessionRef(session.into_arc()))),
        Err(error) => Err(error.to_string()),
    }
}

#[rustler::nif]
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

#[rustler::nif]
fn declare_publisher(
    resource: ResourceArc<ExSessionRef>,
    key_expr: String,
    opts: publisher::PublisherOptions,
) -> Result<ResourceArc<ExPublisherRef>, String> {
    let session: &Arc<Session> = &resource.0;
    match session
        .declare_publisher(key_expr)
        .congestion_control(opts.congestion_control.into())
        .priority(opts.priority.into())
        .res_sync()
    {
        Ok(publisher) => Ok(ResourceArc::new(ExPublisherRef(publisher))),
        Err(error) => Err(error.to_string()),
    }
}

#[rustler::nif]
fn declare_subscriber(
    resource: ResourceArc<ExSessionRef>,
    key_expr: String,
    opts: subscriber::SubscriberOptions,
) -> Result<ResourceArc<ExSubscriberRef>, String> {
    let session: &Arc<Session> = &resource.0;
    match session
        .declare_subscriber(key_expr)
        .reliability(opts.reliability.into())
        .res_sync()
    {
        Ok(subscriber) => Ok(ResourceArc::new(ExSubscriberRef(subscriber))),
        Err(error) => Err(error.to_string()),
    }
}

#[rustler::nif]
fn declare_pull_subscriber(
    resource: ResourceArc<ExSessionRef>,
    key_expr: String,
    opts: subscriber::SubscriberOptions,
) -> Result<ResourceArc<ExPullSubscriberRef>, String> {
    let session: &Arc<Session> = &resource.0;
    match session
        .declare_subscriber(key_expr)
        .reliability(opts.reliability.into())
        .pull_mode()
        .res_sync()
    {
        Ok(pull_subscriber) => Ok(ResourceArc::new(ExPullSubscriberRef(pull_subscriber))),
        Err(error) => Err(error.to_string()),
    }
}

#[rustler::nif]
fn declare_queryable(
    resource: ResourceArc<ExSessionRef>,
    key_expr: String,
    opts: queryable::QueryableOptions,
) -> Result<ResourceArc<ExQueryableRef>, String> {
    let session: &Arc<Session> = &resource.0;
    match session
        .declare_queryable(key_expr)
        .complete(opts.complete)
        .res_sync()
    {
        Ok(queryable) => Ok(ResourceArc::new(ExQueryableRef(queryable))),
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
    true
}

rustler::init!(
    "Elixir.Zenohex.Nif",
    [
        add,
        test_thread,
        zenoh_open,
        zenoh_scouting_delay_zero_session,
        declare_publisher,
        declare_subscriber,
        declare_pull_subscriber,
        declare_queryable,
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
    ],
    load = load
);
