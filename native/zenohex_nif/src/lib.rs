use std::borrow::Cow;
use std::io::Write;
use std::sync::Arc;
use std::time::Duration;

use flume::Receiver;
use rustler::types::atom;
use rustler::{thread, Binary, Encoder, OwnedBinary};
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
fn zenoh_open() -> ResourceArc<ExSessionRef> {
    let config = config::peer();
    let session: Session = zenoh::open(config).res_sync().expect("zenoh_open failed");
    ResourceArc::new(ExSessionRef(session.into_arc()))
}

#[rustler::nif]
fn declare_publisher(
    resource: ResourceArc<ExSessionRef>,
    key_expr: String,
) -> ResourceArc<ExPublisherRef> {
    let session: &Arc<Session> = &resource.0;
    let publisher: Publisher<'_> = session
        .declare_publisher(key_expr)
        .res_sync()
        .expect("declare_publisher failed");
    ResourceArc::new(ExPublisherRef(publisher))
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

#[rustler::nif]
fn publisher_put_binary(resource: ResourceArc<ExPublisherRef>, value: Binary) -> Atom {
    publisher_put_impl(resource, Value::from(value.as_slice()))
}

fn publisher_put_impl<T: Into<zenoh::value::Value>>(
    resource: ResourceArc<ExPublisherRef>,
    value: T,
) -> Atom {
    let publisher: &Publisher = &resource.0;
    publisher
        .put(value)
        .res_sync()
        .expect("publisher_put_impl failed");
    atom::ok()
}

#[rustler::nif]
fn declare_subscriber(
    resource: ResourceArc<ExSessionRef>,
    key_expr: String,
) -> ResourceArc<ExSubscriberRef> {
    let session: &Arc<Session> = &resource.0;
    let subscriber: Subscriber<'_, Receiver<Sample>> = session
        .declare_subscriber(key_expr)
        .res_sync()
        .expect("declare_subscriber failed");
    ResourceArc::new(ExSubscriberRef(subscriber))
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
        KnownEncoding::Empty => unimplemented!(),
        KnownEncoding::AppOctetStream => match Cow::try_from(&sample.value) {
            Ok(value) => {
                let mut binary = OwnedBinary::new(value.len()).unwrap();
                binary.as_mut_slice().write_all(&value).unwrap();
                binary.release(env).encode(env)
            }
            Err(_err) => atom::error().encode(env),
        },
        KnownEncoding::AppCustom => unimplemented!(),
        KnownEncoding::TextPlain => match String::try_from(&sample.value) {
            Ok(value) => value.encode(env),
            Err(_err) => atom::error().encode(env),
        },
        KnownEncoding::AppProperties => unimplemented!(),
        KnownEncoding::AppJson => unimplemented!(),
        KnownEncoding::AppSql => unimplemented!(),
        KnownEncoding::AppInteger => match i64::try_from(&sample.value) {
            Ok(value) => value.encode(env),
            Err(_err) => atom::error().encode(env),
        },
        KnownEncoding::AppFloat => match f64::try_from(&sample.value) {
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
        publisher_put_binary,
        declare_subscriber,
        subscriber_recv_timeout
    ],
    load = load
);
