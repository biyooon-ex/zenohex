use std::{sync::Arc, time::Duration};

use rustler::{types::atom, Atom, Binary, Encoder, Env, ResourceArc, Term};
use zenoh::{prelude::sync::SyncResolve, value::Value, Session};

#[rustler::nif]
fn session_put_integer(
    resource: ResourceArc<crate::ExSessionRef>,
    key_expr: String,
    value: i64,
) -> Atom {
    let session: &Arc<Session> = &resource.0;
    session
        .put(key_expr, value)
        .res_sync()
        .expect("session_put_integer failed");
    atom::ok()
}

#[rustler::nif]
fn session_put_float(
    resource: ResourceArc<crate::ExSessionRef>,
    key_expr: String,
    value: f64,
) -> Atom {
    let session: &Arc<Session> = &resource.0;
    session
        .put(key_expr, value)
        .res_sync()
        .expect("session_put_float failed");
    atom::ok()
}

#[rustler::nif]
fn session_put_binary(
    resource: ResourceArc<crate::ExSessionRef>,
    key_expr: String,
    value: Binary,
) -> Atom {
    let session: &Arc<Session> = &resource.0;
    session
        .put(key_expr, Value::from(value.as_slice()))
        .res_sync()
        .expect("session_put_float failed");
    atom::ok()
}

#[rustler::nif]
fn session_get_timeout(
    env: Env,
    resource: ResourceArc<crate::ExSessionRef>,
    selector: String,
    timeout_us: u64,
) -> Term {
    let session: &Arc<Session> = &resource.0;
    let receiver = session
        .get(selector)
        .res_sync()
        .expect("session_get failed");
    match receiver.recv_timeout(Duration::from_micros(timeout_us)) {
        Ok(reply) => match reply.sample {
            Ok(sample) => crate::to_term(&sample.value, env).encode(env),
            Err(value) => crate::to_term(&value, env).encode(env),
        },
        Err(_recv_timeout_error) => crate::atoms::timeout().encode(env),
    }
}

#[rustler::nif]
fn session_delete(resource: ResourceArc<crate::ExSessionRef>, key_expr: String) -> Atom {
    let session: &Arc<Session> = &resource.0;
    session
        .delete(key_expr)
        .res_sync()
        .expect("session_delete failed");
    atom::ok()
}
