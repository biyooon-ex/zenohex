use std::sync::Arc;
use std::time::Duration;

use flume::Receiver;
use rustler::types::atom;
use rustler::{thread, Encoder};
use rustler::{Atom, Env, ResourceArc, Term};
use zenoh::prelude::sync::*;
use zenoh::{publication::Publisher, sample::Sample, subscriber::Subscriber, Session};

mod atoms {
    rustler::atoms! {timeout}
}

pub struct ExSessionRef(Arc<Session>);
pub struct ExPublisherRef(Publisher<'static>);
pub struct ExSubscriberRef(Subscriber<'static, Receiver<Sample>>);

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
fn zenoh_open(env: Env) -> Term {
    let config = config::peer();
    match zenoh::open(config).res_sync() {
        Ok(session) => {
            let session: Session = session;
            ResourceArc::new(ExSessionRef(session.into_arc())).encode(env)
        }
        Err(_err) => atom::error().encode(env),
    }
}

#[rustler::nif]
fn declare_publisher(env: Env, resource: ResourceArc<ExSessionRef>, key_expr: String) -> Term {
    let session: &Arc<Session> = &resource.0;
    match session.declare_publisher(key_expr).res_sync() {
        Ok(publisher) => {
            let publisher: Publisher<'_> = publisher;
            ResourceArc::new(ExPublisherRef(publisher)).encode(env)
        }
        Err(_err) => atom::error().encode(env),
    }
}

#[rustler::nif]
fn publisher_put_string(resource: ResourceArc<ExPublisherRef>, value: String) -> Atom {
    publisher_put_impl(resource, value)
}

#[rustler::nif]
fn publisher_put_integer(resource: ResourceArc<ExPublisherRef>, value: i64) -> Atom {
    publisher_put_impl(resource, value)
}

#[rustler::nif]
fn publisher_put_float(resource: ResourceArc<ExPublisherRef>, value: f64) -> Atom {
    publisher_put_impl(resource, value)
}

fn publisher_put_impl<T: Into<zenoh::value::Value>>(
    resource: ResourceArc<ExPublisherRef>,
    value: T,
) -> Atom {
    let publisher: &Publisher = &resource.0;
    match publisher.put(value).res_sync() {
        Ok(()) => atom::ok(),
        Err(_err) => atom::error(),
    }
}

#[rustler::nif]
fn declare_subscriber(env: Env, resource: ResourceArc<ExSessionRef>, key_expr: String) -> Term {
    let session: &Arc<Session> = &resource.0;
    match session.declare_subscriber(key_expr).res_sync() {
        Ok(subscriber) => {
            let subscriber: Subscriber<'_, Receiver<Sample>> = subscriber;
            ResourceArc::new(ExSubscriberRef(subscriber)).encode(env)
        }
        Err(_err) => atom::error().encode(env),
    }
}

#[rustler::nif]
fn subscriber_recv_timeout(
    env: Env,
    resource: ResourceArc<ExSubscriberRef>,
    timeout_us: u64,
) -> Term {
    let subscriber: &Subscriber<'_, Receiver<Sample>> = &resource.0;
    match subscriber.recv_timeout(Duration::from_micros(timeout_us)) {
        Ok(sample) => to_term(&sample, env),
        Err(_recv_timeout_error) => atoms::timeout().encode(env),
    }
}

fn to_term<'a>(sample: &Sample, env: Env<'a>) -> Term<'a> {
    match sample.value.encoding.prefix() {
        KnownEncoding::Empty => todo!(),
        KnownEncoding::AppOctetStream => todo!(),
        KnownEncoding::AppCustom => todo!(),
        KnownEncoding::TextPlain => match String::try_from(&sample.value) {
            Ok(value) => value.encode(env),
            Err(_err) => atom::error().encode(env),
        },
        KnownEncoding::AppProperties => todo!(),
        KnownEncoding::AppJson => todo!(),
        KnownEncoding::AppSql => todo!(),
        KnownEncoding::AppInteger => match i64::try_from(&sample.value) {
            Ok(value) => value.encode(env),
            Err(_err) => atom::error().encode(env),
        },
        KnownEncoding::AppFloat => match f64::try_from(&sample.value) {
            Ok(value) => value.encode(env),
            Err(_err) => atom::error().encode(env),
        },
        KnownEncoding::AppXml => todo!(),
        KnownEncoding::AppXhtmlXml => todo!(),
        KnownEncoding::AppXWwwFormUrlencoded => todo!(),
        KnownEncoding::TextJson => todo!(),
        KnownEncoding::TextHtml => todo!(),
        KnownEncoding::TextXml => todo!(),
        KnownEncoding::TextCss => todo!(),
        KnownEncoding::TextCsv => todo!(),
        KnownEncoding::TextJavascript => todo!(),
        KnownEncoding::ImageJpeg => todo!(),
        KnownEncoding::ImagePng => todo!(),
        KnownEncoding::ImageGif => todo!(),
    }
}

fn load(env: Env, _term: Term) -> bool {
    rustler::resource!(ExSessionRef, env);
    rustler::resource!(ExPublisherRef, env);
    rustler::resource!(ExSubscriberRef, env);
    true
}

rustler::init!(
    "Elixir.Zenohex.Nif",
    [
        add,
        test_thread,
        zenoh_open,
        declare_publisher,
        publisher_put_string,
        publisher_put_integer,
        publisher_put_float,
        declare_subscriber,
        subscriber_recv_timeout
    ],
    load = load
);
