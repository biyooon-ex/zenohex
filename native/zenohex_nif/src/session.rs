use std::{sync::Arc, time::Duration};

use rustler::{types::atom, Binary, Encoder, Env, ResourceArc, Term};
use zenoh::{prelude::sync::SyncResolve, value::Value, Session};

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
fn session_get_timeout(
    env: Env,
    resource: ResourceArc<crate::ExSessionRef>,
    selector: String,
    timeout_us: u64,
) -> Result<Term, Term> {
    let session: &Arc<Session> = &resource.0;
    let receiver = match session.get(selector).res_sync() {
        Ok(receiver) => receiver,
        Err(error) => return Err(error.to_string().encode(env)),
    };
    match receiver.recv_timeout(Duration::from_micros(timeout_us)) {
        Ok(reply) => match reply.sample {
            Ok(sample) => crate::to_result(&sample.value, env),
            Err(value) => crate::to_result(&value, env),
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
