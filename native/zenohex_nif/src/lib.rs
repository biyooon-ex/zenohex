use std::borrow::Cow;
use std::io::Write;
use std::sync::Arc;
use std::time::Duration;

use flume::Receiver;
use rustler::types::atom;
use rustler::{thread, Binary, Encoder, OwnedBinary};
use rustler::{Atom, Env, ResourceArc, Term};
use zenoh::prelude::sync::*;
use zenoh::{
    publication::Publisher, queryable::Queryable, subscriber::PullSubscriber,
    subscriber::Subscriber, Session,
};
use zenoh::{queryable::Query, sample::Sample};

mod atoms {
    rustler::atoms! {
        timeout,
    }
}
mod publisher;
mod pull_subscriber;
mod subscriber;

pub struct ExSessionRef(Arc<Session>);
pub struct ExPublisherRef(Publisher<'static>);
pub struct ExSubscriberRef(Subscriber<'static, Receiver<Sample>>);
pub struct ExPullSubscriberRef(PullSubscriber<'static, Receiver<Sample>>);
pub struct ExQueryableRef(Queryable<'static, Receiver<Query>>);

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
fn zenoh_open() -> ResourceArc<ExSessionRef> {
    let config = config::peer();
    let session: Session = zenoh::open(config).res_sync().expect("zenoh_open failed");
    ResourceArc::new(ExSessionRef(session.into_arc()))
}

#[rustler::nif]
fn session_put_integer(resource: ResourceArc<ExSessionRef>, key_expr: String, value: i64) -> Atom {
    let session: &Arc<Session> = &resource.0;
    session
        .put(key_expr, value)
        .res_sync()
        .expect("session_put_integer failed");
    atom::ok()
}

#[rustler::nif]
fn session_put_float(resource: ResourceArc<ExSessionRef>, key_expr: String, value: f64) -> Atom {
    let session: &Arc<Session> = &resource.0;
    session
        .put(key_expr, value)
        .res_sync()
        .expect("session_put_float failed");
    atom::ok()
}

#[rustler::nif]
fn session_put_binary(
    resource: ResourceArc<ExSessionRef>,
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
    resource: ResourceArc<ExSessionRef>,
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
            Ok(sample) => to_term(&sample.value, env).encode(env),
            Err(value) => to_term(&value, env).encode(env),
        },
        Err(_recv_timeout_error) => atoms::timeout().encode(env),
    }
}

#[rustler::nif]
fn session_delete(resource: ResourceArc<ExSessionRef>, key_expr: String) -> Atom {
    let session: &Arc<Session> = &resource.0;
    session
        .delete(key_expr)
        .res_sync()
        .expect("session_delete failed");
    atom::ok()
}

#[rustler::nif]
fn declare_publisher(
    resource: ResourceArc<ExSessionRef>,
    key_expr: String,
    opts: publisher::PublisherOptions,
) -> ResourceArc<ExPublisherRef> {
    let session: &Arc<Session> = &resource.0;
    let publisher: Publisher = session
        .declare_publisher(key_expr)
        .congestion_control(opts.congestion_control.into())
        .priority(opts.priority.into())
        .res_sync()
        .expect("declare_publisher failed");

    ResourceArc::new(ExPublisherRef(publisher))
}

#[rustler::nif]
fn declare_subscriber(
    resource: ResourceArc<ExSessionRef>,
    key_expr: String,
    opts: subscriber::SubscriberOptions,
) -> ResourceArc<ExSubscriberRef> {
    let session: &Arc<Session> = &resource.0;
    let subscriber: Subscriber<'_, Receiver<Sample>> = session
        .declare_subscriber(key_expr)
        .reliability(opts.reliability.into())
        .res_sync()
        .expect("declare_subscriber failed");

    ResourceArc::new(ExSubscriberRef(subscriber))
}

#[rustler::nif]
fn declare_pull_subscriber(
    resource: ResourceArc<ExSessionRef>,
    key_expr: String,
    opts: subscriber::SubscriberOptions,
) -> ResourceArc<ExPullSubscriberRef> {
    let session: &Arc<Session> = &resource.0;
    let pull_subscriber: PullSubscriber<'_, Receiver<Sample>> = session
        .declare_subscriber(key_expr)
        .reliability(opts.reliability.into())
        .pull_mode()
        .res_sync()
        .expect("declare_pull_subscriber failed");

    ResourceArc::new(ExPullSubscriberRef(pull_subscriber))
}

#[rustler::nif]
fn declare_queryable(
    resource: ResourceArc<ExSessionRef>,
    key_expr: String,
    opts: QueryableOptions,
) -> ResourceArc<ExQueryableRef> {
    let session: &Arc<Session> = &resource.0;
    let queryable: Queryable<'_, Receiver<Query>> = session
        .declare_queryable(key_expr)
        .complete(opts.complete)
        .res_sync()
        .expect("declare_queryable failed");

    ResourceArc::new(ExQueryableRef(queryable))
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Queryable.Options"]
pub struct QueryableOptions {
    complete: bool,
}

fn to_term<'a>(value: &Value, env: Env<'a>) -> Term<'a> {
    match value.encoding.prefix() {
        KnownEncoding::Empty => unimplemented!(),
        KnownEncoding::AppOctetStream => match Cow::try_from(value) {
            Ok(value) => {
                let mut binary = OwnedBinary::new(value.len()).unwrap();
                binary.as_mut_slice().write_all(&value).unwrap();
                binary.release(env).encode(env)
            }
            Err(_err) => atom::error().encode(env),
        },
        KnownEncoding::AppCustom => unimplemented!(),
        KnownEncoding::TextPlain => match String::try_from(value) {
            Ok(value) => value.encode(env),
            Err(_err) => atom::error().encode(env),
        },
        KnownEncoding::AppProperties => unimplemented!(),
        KnownEncoding::AppJson => unimplemented!(),
        KnownEncoding::AppSql => unimplemented!(),
        KnownEncoding::AppInteger => match i64::try_from(value) {
            Ok(value) => value.encode(env),
            Err(_err) => atom::error().encode(env),
        },
        KnownEncoding::AppFloat => match f64::try_from(value) {
            Ok(value) => value.encode(env),
            Err(_err) => atom::error().encode(env),
        },
        KnownEncoding::AppXml => unimplemented!(),
        KnownEncoding::AppXhtmlXml => unimplemented!(),
        KnownEncoding::AppXWwwFormUrlencoded => unimplemented!(),
        KnownEncoding::TextJson => unimplemented!(),
        KnownEncoding::TextHtml => unimplemented!(),
        KnownEncoding::TextXml => unimplemented!(),
        KnownEncoding::TextCss => unimplemented!(),
        KnownEncoding::TextCsv => unimplemented!(),
        KnownEncoding::TextJavascript => unimplemented!(),
        KnownEncoding::ImageJpeg => unimplemented!(),
        KnownEncoding::ImagePng => unimplemented!(),
        KnownEncoding::ImageGif => unimplemented!(),
    }
}

fn load(env: Env, _term: Term) -> bool {
    rustler::resource!(ExSessionRef, env);
    rustler::resource!(ExPublisherRef, env);
    rustler::resource!(ExSubscriberRef, env);
    rustler::resource!(ExPullSubscriberRef, env);
    rustler::resource!(ExQueryableRef, env);
    true
}

rustler::init!(
    "Elixir.Zenohex.Nif",
    [
        add,
        test_thread,
        zenoh_open,
        session_put_integer,
        session_put_float,
        session_put_binary,
        session_get_timeout,
        session_delete,
        declare_publisher,
        publisher::publisher_put_integer,
        publisher::publisher_put_float,
        publisher::publisher_put_binary,
        publisher::publisher_delete,
        publisher::publisher_congestion_control,
        publisher::publisher_priority,
        declare_subscriber,
        subscriber::subscriber_recv_timeout,
        declare_pull_subscriber,
        pull_subscriber::pull_subscriber_pull,
        pull_subscriber::pull_subscriber_recv_timeout,
        declare_queryable,
    ],
    load = load
);
