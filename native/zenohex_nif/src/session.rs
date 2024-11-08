use std::{sync::Arc, time::Duration};

use flume::{Receiver, RecvTimeoutError};
use rustler::{types::atom, Binary, Encoder, Env, ResourceArc, Term};
use zenoh::{bytes::ZBytes, query::Reply, session::Session};

#[rustler::nif]
fn declare_publisher(
    resource: ResourceArc<crate::SessionRef>,
    key_expr: String,
    opts: crate::publisher::ExPublisherOptions,
) -> Result<ResourceArc<crate::PublisherRef>, String> {
    let session: &Arc<Session> = &resource.0;
    match session
        .declare_publisher(key_expr)
        .congestion_control(opts.congestion_control.into())
        .priority(opts.priority.into())
        .res_sync()
    {
        Ok(publisher) => Ok(ResourceArc::new(crate::PublisherRef(publisher))),
        Err(error) => Err(error.to_string()),
    }
}

#[rustler::nif]
fn declare_subscriber(
    resource: ResourceArc<crate::SessionRef>,
    key_expr: String,
    opts: crate::subscriber::SubscriberOptions,
) -> Result<ResourceArc<crate::SubscriberRef>, String> {
    let session: &Arc<Session> = &resource.0;
    match session
        .declare_subscriber(key_expr)
        .reliability(opts.reliability.into())
        .res_sync()
    {
        Ok(subscriber) => Ok(ResourceArc::new(crate::SubscriberRef(subscriber))),
        Err(error) => Err(error.to_string()),
    }
}

#[rustler::nif]
fn declare_pull_subscriber(
    resource: ResourceArc<crate::SessionRef>,
    key_expr: String,
    opts: crate::subscriber::SubscriberOptions,
) -> Result<ResourceArc<crate::PullSubscriberRef>, String> {
    let session: &Arc<Session> = &resource.0;
    match session
        .declare_subscriber(key_expr)
        .reliability(opts.reliability.into())
        .pull_mode()
        .res_sync()
    {
        Ok(pull_subscriber) => Ok(ResourceArc::new(crate::PullSubscriberRef(pull_subscriber))),
        Err(error) => Err(error.to_string()),
    }
}

#[rustler::nif]
fn declare_queryable(
    resource: ResourceArc<crate::SessionRef>,
    key_expr: String,
    opts: crate::queryable::ExQueryableOptions,
) -> Result<ResourceArc<crate::QueryableRef>, String> {
    let session: &Arc<Session> = &resource.0;
    match session
        .declare_queryable(key_expr)
        .complete(opts.complete)
        .res_sync()
    {
        Ok(queryable) => Ok(ResourceArc::new(crate::QueryableRef(queryable))),
        Err(error) => Err(error.to_string()),
    }
}

#[rustler::nif]
fn session_put_integer(
    env: Env,
    resource: ResourceArc<crate::SessionRef>,
    key_expr: String,
    value: i64,
) -> Term {
    session_put_impl(env, resource, key_expr, value)
}

#[rustler::nif]
fn session_put_float(
    env: Env,
    resource: ResourceArc<crate::SessionRef>,
    key_expr: String,
    value: f64,
) -> Term {
    session_put_impl(env, resource, key_expr, value)
}

#[rustler::nif]
fn session_put_binary<'a>(
    env: Env<'a>,
    resource: ResourceArc<crate::SessionRef>,
    key_expr: String,
    value: Binary<'a>,
) -> Term<'a> {
    session_put_impl(env, resource, key_expr, Value::from(value.as_slice()))
}

fn session_put_impl<T: Into<zenoh::value::Value>>(
    env: Env,
    resource: ResourceArc<crate::SessionRef>,
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
    resource: ResourceArc<crate::SessionRef>,
    selector: String,
    opts: crate::query::ExQueryOptions,
) -> Result<ResourceArc<crate::ReplyReceiverRef>, String> {
    // NOTE: 引数に ExQuery を使うことが妥当と思うが、
    // zenoh の v1.0.0 前にそれらを考えるのが時期焦燥と判断し一旦このままとする
    // TODO: with_value 対応も v1.0.0 が出たら検討する
    let session: &Arc<Session> = &resource.0;
    match session
        .get(selector)
        .target(opts.target.into())
        .consolidation(opts.consolidation)
        .res_sync()
    {
        Ok(receiver) => Ok(ResourceArc::new(crate::ReplyReceiverRef(receiver))),
        Err(error) => Err(error.to_string()),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn session_get_reply_timeout(
    env: Env,
    resource: ResourceArc<crate::ReplyReceiverRef>,
    timeout_us: u64,
) -> Result<Term, Term> {
    let receiver: &Receiver<Reply> = &resource.0;
    match receiver.recv_timeout(Duration::from_micros(timeout_us)) {
        Ok(reply) => match reply.sample {
            Ok(sample) => Ok(crate::sample::ExSample::from(env, sample).encode(env)),
            Err(value) => Err(crate::value::ExValue::from(env, &value).encode(env)),
        },
        Err(RecvTimeoutError::Timeout) => Err(crate::atoms::timeout().encode(env)),
        Err(RecvTimeoutError::Disconnected) => Err(crate::atoms::disconnected().encode(env)),
    }
}

#[rustler::nif]
fn session_delete(env: Env, resource: ResourceArc<crate::SessionRef>, key_expr: String) -> Term {
    let session: &Arc<Session> = &resource.0;
    match session.delete(key_expr).res_sync() {
        Ok(_) => atom::ok().encode(env),
        Err(error) => (atom::error(), error.to_string()).encode(env),
    }
}
