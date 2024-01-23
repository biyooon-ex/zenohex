use std::borrow::Cow;
use std::io::Write;
use std::sync::Arc;
use std::time::Duration;

use flume::Receiver;
use rustler::types::atom;
use rustler::{thread, Binary, Encoder, ListIterator, OwnedBinary};
use rustler::{Atom, Env, ResourceArc, Term};
use zenoh::prelude::sync::*;
use zenoh::subscriber::SubscriberBuilder;
use zenoh::{
    publication::Publisher, sample::Sample, subscriber::PullSubscriber, subscriber::Subscriber,
    Session,
};

mod atoms {
    rustler::atoms! {
        timeout,
        congestion_control,
            drop,
            block,
        priority,
            realtime,
            interactive_high,
            interactive_low,
            data_high,
            data,
            data_low,
            background,
        mode,
            push,
            pull,
        reliability,
            best_effort,
            reliable,
    }
}

pub struct ExSessionRef(Arc<Session>);
pub struct ExPublisherRef(Publisher<'static>);
pub struct ExSubscriberRef(Subscriber<'static, Receiver<Sample>>);
pub struct ExPullSubscriberRef(PullSubscriber<'static, Receiver<Sample>>);

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
    opts: ListIterator,
) -> ResourceArc<ExPublisherRef> {
    let session: &Arc<Session> = &resource.0;
    let publisher: Publisher = session
        .declare_publisher(key_expr)
        .res_sync()
        .expect("declare_publisher failed");

    let publisher = opts.fold(publisher, |acc, kv: Term| {
        match kv.decode::<(Atom, Atom)>().unwrap() {
            (k, v) if k == atoms::congestion_control() => publisher_congestion_control_impl(acc, v),
            (k, v) if k == atoms::priority() => publisher_priority_impl(acc, v),
            _ => acc,
        }
    });

    ResourceArc::new(ExPublisherRef(publisher))
}

#[rustler::nif]
fn publisher_congestion_control(
    resource: ResourceArc<ExPublisherRef>,
    value: Atom,
) -> ResourceArc<ExPublisherRef> {
    let publisher: &Publisher = &resource.0;
    let publisher: Publisher = publisher_congestion_control_impl(publisher.clone(), value);

    ResourceArc::new(ExPublisherRef(publisher))
}

fn publisher_congestion_control_impl(publisher: Publisher, value: Atom) -> Publisher {
    match value {
        v if v == atoms::drop() => publisher.congestion_control(CongestionControl::Drop),
        v if v == atoms::block() => publisher.congestion_control(CongestionControl::Block),
        _ => unreachable!(),
    }
}

#[rustler::nif]
fn publisher_priority(
    resource: ResourceArc<ExPublisherRef>,
    value: Atom,
) -> ResourceArc<ExPublisherRef> {
    let publisher: &Publisher = &resource.0;
    let publisher: Publisher = publisher_priority_impl(publisher.clone(), value);

    ResourceArc::new(ExPublisherRef(publisher))
}

fn publisher_priority_impl(publisher: Publisher, value: Atom) -> Publisher {
    match value {
        v if v == atoms::realtime() => publisher.priority(Priority::RealTime),
        v if v == atoms::interactive_high() => publisher.priority(Priority::InteractiveHigh),
        v if v == atoms::interactive_low() => publisher.priority(Priority::InteractiveLow),
        v if v == atoms::data_high() => publisher.priority(Priority::DataHigh),
        v if v == atoms::data() => publisher.priority(Priority::Data),
        v if v == atoms::data_low() => publisher.priority(Priority::DataLow),
        v if v == atoms::background() => publisher.priority(Priority::Background),
        _ => unreachable!(),
    }
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
fn publisher_delete(resource: ResourceArc<ExPublisherRef>) -> Atom {
    let publisher: &Publisher = &resource.0;
    publisher
        .delete()
        .res_sync()
        .expect("publisher_delete failed.");
    atom::ok()
}

#[rustler::nif]
fn declare_subscriber(
    resource: ResourceArc<ExSessionRef>,
    key_expr: String,
    opts: ListIterator,
) -> ResourceArc<ExSubscriberRef> {
    let session: &Arc<Session> = &resource.0;
    let builder: SubscriberBuilder<_, _> = session.declare_subscriber(key_expr);

    let builder = opts.fold(builder, |acc, kv: Term| {
        match kv.decode::<(Atom, Atom)>().unwrap() {
            (k, v) if k == atoms::reliability() => match v {
                v if v == atoms::best_effort() => acc.best_effort(),
                v if v == atoms::reliable() => acc.reliable(),
                _ => unreachable!(),
            },
            _ => acc,
        }
    });

    let subscriber: Subscriber<'_, Receiver<Sample>> =
        builder.res_sync().expect("declare_subscriber failed");

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

#[rustler::nif]
fn declare_pull_subscriber(
    resource: ResourceArc<ExSessionRef>,
    key_expr: String,
    opts: ListIterator,
) -> ResourceArc<ExPullSubscriberRef> {
    let session: &Arc<Session> = &resource.0;
    let builder: SubscriberBuilder<_, _> = session.declare_subscriber(key_expr).pull_mode();

    let builder = opts.fold(builder, |acc, kv: Term| {
        match kv.decode::<(Atom, Atom)>().unwrap() {
            (k, v) if k == atoms::reliability() => match v {
                v if v == atoms::best_effort() => acc.best_effort(),
                v if v == atoms::reliable() => acc.reliable(),
                _ => unreachable!(),
            },
            _ => acc,
        }
    });

    let pull_subscriber: PullSubscriber<'_, Receiver<Sample>> =
        builder.res_sync().expect("declare_pull_subscriber failed");

    ResourceArc::new(ExPullSubscriberRef(pull_subscriber))
}

#[rustler::nif]
fn pull_subscriber_recv_timeout(
    env: Env,
    resource: ResourceArc<ExPullSubscriberRef>,
    timeout_us: u64,
) -> Term {
    let pull_subscriber: &PullSubscriber<'_, Receiver<Sample>> = &resource.0;
    match pull_subscriber.recv_timeout(Duration::from_micros(timeout_us)) {
        Ok(sample) => to_term(&sample, env),
        Err(_recv_timeout_error) => atoms::timeout().encode(env),
    }
}

#[rustler::nif]
fn pull_subscriber_pull(resource: ResourceArc<ExPullSubscriberRef>) -> Atom {
    let pull_subscriber: &PullSubscriber<'_, Receiver<Sample>> = &resource.0;
    pull_subscriber
        .pull()
        .res_sync()
        .expect("pull_subscriber_pull failed");
    atom::ok()
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
    rustler::resource!(ExPullSubscriberRef, env);
    true
}

rustler::init!(
    "Elixir.Zenohex.Nif",
    [
        add,
        test_thread,
        zenoh_open,
        declare_publisher,
        publisher_put_integer,
        publisher_put_float,
        publisher_put_binary,
        publisher_delete,
        publisher_congestion_control,
        publisher_priority,
        declare_subscriber,
        subscriber_recv_timeout,
        declare_pull_subscriber,
        pull_subscriber_pull,
        pull_subscriber_recv_timeout,
    ],
    load = load
);
