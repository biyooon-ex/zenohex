use std::{sync::Arc, time::Duration};

use flume::Receiver;
use rustler::{types::atom, Binary, Encoder, Env, ResourceArc, Term};
use zenoh::{prelude::sync::*, query::Reply, value::Value, Session};

#[rustler::nif]
fn declare_publisher(
    resource: ResourceArc<crate::ExSessionRef>,
    key_expr: String,
    opts: crate::publisher::PublisherOptions,
) -> Result<ResourceArc<crate::ExPublisherRef>, String> {
    let session: &Arc<Session> = &resource.0;
    match session
        .declare_publisher(key_expr)
        .congestion_control(opts.congestion_control.into())
        .priority(opts.priority.into())
        .res_sync()
    {
        Ok(publisher) => Ok(ResourceArc::new(crate::ExPublisherRef(publisher))),
        Err(error) => Err(error.to_string()),
    }
}

#[rustler::nif]
fn declare_subscriber(
    resource: ResourceArc<crate::ExSessionRef>,
    key_expr: String,
    opts: crate::subscriber::SubscriberOptions,
) -> Result<ResourceArc<crate::ExSubscriberRef>, String> {
    let session: &Arc<Session> = &resource.0;
    match session
        .declare_subscriber(key_expr)
        .reliability(opts.reliability.into())
        .res_sync()
    {
        Ok(subscriber) => Ok(ResourceArc::new(crate::ExSubscriberRef(subscriber))),
        Err(error) => Err(error.to_string()),
    }
}

#[rustler::nif]
fn declare_pull_subscriber(
    resource: ResourceArc<crate::ExSessionRef>,
    key_expr: String,
    opts: crate::subscriber::SubscriberOptions,
) -> Result<ResourceArc<crate::ExPullSubscriberRef>, String> {
    let session: &Arc<Session> = &resource.0;
    match session
        .declare_subscriber(key_expr)
        .reliability(opts.reliability.into())
        .pull_mode()
        .res_sync()
    {
        Ok(pull_subscriber) => Ok(ResourceArc::new(crate::ExPullSubscriberRef(
            pull_subscriber,
        ))),
        Err(error) => Err(error.to_string()),
    }
}

#[rustler::nif]
fn declare_queryable(
    resource: ResourceArc<crate::ExSessionRef>,
    key_expr: String,
    opts: crate::queryable::QueryableOptions,
) -> Result<ResourceArc<crate::ExQueryableRef>, String> {
    let session: &Arc<Session> = &resource.0;
    match session
        .declare_queryable(key_expr)
        .complete(opts.complete)
        .res_sync()
    {
        Ok(queryable) => Ok(ResourceArc::new(crate::ExQueryableRef(queryable))),
        Err(error) => Err(error.to_string()),
    }
}

#[rustler::nif]
fn session_put_integer(
    env: Env,
    resource: ResourceArc<crate::ExSessionRef>,
    key_expr: String,
    value: i64,
) -> Term {
    session_put_impl(env, resource, key_expr, value)
}

#[rustler::nif]
fn session_put_float(
    env: Env,
    resource: ResourceArc<crate::ExSessionRef>,
    key_expr: String,
    value: f64,
) -> Term {
    session_put_impl(env, resource, key_expr, value)
}

#[rustler::nif]
fn session_put_binary<'a>(
    env: Env<'a>,
    resource: ResourceArc<crate::ExSessionRef>,
    key_expr: String,
    value: Binary<'a>,
) -> Term<'a> {
    session_put_impl(env, resource, key_expr, Value::from(value.as_slice()))
}

fn session_put_impl<T: Into<zenoh::value::Value>>(
    env: Env,
    resource: ResourceArc<crate::ExSessionRef>,
    key_expr: String,
    value: T,
) -> Term {
    let session: &Arc<Session> = &resource.0;
    match session.put(key_expr, value).res_sync() {
        Ok(_) => atom::ok().encode(env),
        Err(error) => (atom::error(), error.to_string()).encode(env),
    }
}

#[rustler::nif]
fn session_get_reply_receiver(
    resource: ResourceArc<crate::ExSessionRef>,
    selector: String,
    opts: crate::query::QueryOptions,
) -> Result<ResourceArc<crate::ExReplyReceiverRef>, String> {
    let session: &Arc<Session> = &resource.0;
    // TODO: with_value の実装は用途が出てきたら検討
    match session
        .get(selector)
        .target(opts.target.into())
        .consolidation(opts.consolidation)
        .res_sync()
    {
        Ok(receiver) => Ok(ResourceArc::new(crate::ExReplyReceiverRef(receiver))),
        Err(error) => Err(error.to_string()),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn session_get_reply_timeout(
    env: Env,
    resource: ResourceArc<crate::ExReplyReceiverRef>,
    timeout_us: u64,
) -> Result<Term, Term> {
    let receiver: &Receiver<Reply> = &resource.0;
    match receiver.recv_timeout(Duration::from_micros(timeout_us)) {
        Ok(reply) => match reply.sample {
            Ok(sample) => Ok(crate::sample::Sample::from(env, sample).encode(env)),
            Err(value) => Err(crate::value::Value::to_term(env, &value)),
        },
        Err(_recv_timeout_error) => Err(crate::atoms::timeout().encode(env)),
    }
}

#[rustler::nif]
fn session_delete(env: Env, resource: ResourceArc<crate::ExSessionRef>, key_expr: String) -> Term {
    let session: &Arc<Session> = &resource.0;
    match session.delete(key_expr).res_sync() {
        Ok(_) => atom::ok().encode(env),
        Err(error) => (atom::error(), error.to_string()).encode(env),
    }
}
