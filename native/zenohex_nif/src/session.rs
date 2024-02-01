use std::{sync::Arc, time::Duration};

use flume::Receiver;
use rustler::{types::atom, Binary, Encoder, Env, ResourceArc, Term};
use zenoh::{prelude::sync::SyncResolve, query::Reply, value::Value, Session};

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

#[rustler::nif]
fn session_get_reply_timeout(
    env: Env,
    resource: ResourceArc<crate::ExReplyReceiverRef>,
    timeout_us: u64,
) -> Result<Term, Term> {
    let receiver: &Receiver<Reply> = &resource.0;
    match receiver.recv_timeout(Duration::from_micros(timeout_us)) {
        Ok(reply) => match reply.sample {
            Ok(sample) => crate::to_result(&sample.value, env),
            Err(value) => match crate::to_result(&value, env) {
                Ok(term) => Err(term),
                Err(term) => Err(term),
            },
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
