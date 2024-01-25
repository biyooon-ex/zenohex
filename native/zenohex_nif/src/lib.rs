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
    opts: PublisherOptions,
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
fn publisher_congestion_control(
    resource: ResourceArc<ExPublisherRef>,
    value: CongestionControl,
) -> ResourceArc<ExPublisherRef> {
    let publisher: &Publisher = &resource.0;
    let publisher: Publisher = publisher.clone().congestion_control(value.into());

    ResourceArc::new(ExPublisherRef(publisher))
}

#[rustler::nif]
fn publisher_priority(
    resource: ResourceArc<ExPublisherRef>,
    value: Priority,
) -> ResourceArc<ExPublisherRef> {
    let publisher: &Publisher = &resource.0;
    let publisher: Publisher = publisher.clone().priority(value.into());

    ResourceArc::new(ExPublisherRef(publisher))
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
    opts: SubscriberOptions,
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
fn subscriber_recv_timeout(
    env: Env,
    resource: ResourceArc<ExSubscriberRef>,
    timeout_us: u64,
) -> Term {
    let subscriber: &Subscriber<'_, Receiver<Sample>> = &resource.0;
    match subscriber.recv_timeout(Duration::from_micros(timeout_us)) {
        Ok(sample) => to_term(&sample.value, env),
        Err(_recv_timeout_error) => atoms::timeout().encode(env),
    }
}

#[rustler::nif]
fn declare_pull_subscriber(
    resource: ResourceArc<ExSessionRef>,
    key_expr: String,
    opts: SubscriberOptions,
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
fn pull_subscriber_recv_timeout(
    env: Env,
    resource: ResourceArc<ExPullSubscriberRef>,
    timeout_us: u64,
) -> Term {
    let pull_subscriber: &PullSubscriber<'_, Receiver<Sample>> = &resource.0;
    match pull_subscriber.recv_timeout(Duration::from_micros(timeout_us)) {
        Ok(sample) => to_term(&sample.value, env),
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
#[module = "Zenohex.Publisher.Options"]
pub struct PublisherOptions {
    congestion_control: CongestionControl,
    priority: Priority,
}

#[derive(rustler::NifUnitEnum)]
pub enum CongestionControl {
    Drop,
    Block,
}

impl From<CongestionControl> for zenoh::publication::CongestionControl {
    fn from(value: CongestionControl) -> Self {
        match value {
            CongestionControl::Drop => zenoh::publication::CongestionControl::Drop,
            CongestionControl::Block => zenoh::publication::CongestionControl::Block,
        }
    }
}

#[derive(rustler::NifUnitEnum)]
pub enum Priority {
    RealTime,
    InteractiveHigh,
    InteractiveLow,
    DataHigh,
    Data,
    DataLow,
    Background,
}

impl From<Priority> for zenoh::publication::Priority {
    fn from(value: Priority) -> Self {
        match value {
            Priority::RealTime => zenoh::publication::Priority::RealTime,
            Priority::InteractiveHigh => zenoh::publication::Priority::InteractiveHigh,
            Priority::InteractiveLow => zenoh::publication::Priority::InteractiveLow,
            Priority::DataHigh => zenoh::publication::Priority::DataHigh,
            Priority::Data => zenoh::publication::Priority::Data,
            Priority::DataLow => zenoh::publication::Priority::DataLow,
            Priority::Background => zenoh::publication::Priority::Background,
        }
    }
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Subscriber.Options"]
pub struct SubscriberOptions {
    reliability: Reliability,
}

#[derive(rustler::NifUnitEnum)]
pub enum Reliability {
    BestEffort,
    Reliable,
}

impl From<Reliability> for zenoh::subscriber::Reliability {
    fn from(value: Reliability) -> Self {
        match value {
            Reliability::BestEffort => zenoh::subscriber::Reliability::BestEffort,
            Reliability::Reliable => zenoh::subscriber::Reliability::Reliable,
        }
    }
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
        declare_queryable,
    ],
    load = load
);
