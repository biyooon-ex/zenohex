use flume::Receiver;
use futures::executor::block_on;
use rustler::types::atom::ok;
use rustler::types::Encoder;
use rustler::{Env, OwnedEnv, ResourceArc, Term};
use std::sync::Mutex;
use zenoh::config::Config;
use zenoh::prelude::r#async::*;
use zenoh::publication::Publisher;
use zenoh::subscriber::{self, Subscriber};
pub mod tester;
use tester::tester::{tester_pub, tester_sub};

struct SessionContainer {
    session_mux: Mutex<&'static Session>,
}

struct PublisherContainer {
    publisher_mux: Mutex<Publisher<'static>>,
}

// struct SubscriberContainer {
//     subscriber_mux: Mutex<Subscriber<'static, Receiver<Sample>>>,
// }

fn load<'a>(env: Env<'a>, _: Term<'a>) -> bool {
    rustler::resource!(SessionContainer, env);
    rustler::resource!(PublisherContainer, env);
    // rustler::resource!(SubscriberContainer, env);
    true
}

#[rustler::nif]
fn zenoh_open<'a>() -> ResourceArc<SessionContainer> {
    ResourceArc::new(SessionContainer {
        session_mux: Mutex::new(Session::leak(
            block_on(zenoh::open(Config::default()).res()).unwrap(),
        )),
    })
}

#[rustler::nif]
fn session_declare_publisher<'a>(
    env: Env<'a>,
    resource_session: ResourceArc<SessionContainer>,
    keyexpr: String,
) -> Term<'a> {
    let session = resource_session.session_mux.lock().unwrap();
    let publisher = session.declare_publisher(keyexpr);
    let resource_publisher = ResourceArc::new(PublisherContainer {
        publisher_mux: Mutex::new(block_on(publisher.res()).unwrap()),
    });
    (ok(), resource_publisher).encode(env)
}

#[rustler::nif]
fn publisher_put<'a>(
    env: Env<'a>,
    resource_session: ResourceArc<PublisherContainer>,
    value: String,
) -> Term<'a> {
    let publisher = &resource_session.publisher_mux.lock().unwrap();
    block_on(publisher.put(value).res()).unwrap();
    (ok()).encode(env)
}

#[rustler::nif]
fn session_declare_subscriber<'a>(
    env: Env<'a>,
    resource_session: ResourceArc<SessionContainer>,
    keyexpr: String,
) -> Term<'a> {
    let pid = env.pid();
    let mut subscriber_env = OwnedEnv::new();

    let session = resource_session.session_mux.lock().unwrap();
    let subscriber = block_on(session.declare_subscriber(keyexpr).res()).unwrap();

    std::thread::spawn(move || {
        loop {
            let sample = block_on(subscriber.recv_async()).unwrap();
            subscriber_env.send_and_clear(&pid, |env| {sample.value.to_string().encode(env)});
        }
    }
    );

    ok().encode(env)
}

// #[rustler::nif]
// fn send_message<'a>(env: Env<'a>, value: String) -> Term<'a> {
//     env.send(&(env.pid()), value.encode(env));
//     (ok()).encode(env)
// }

rustler::init!(
    "Elixir.NifZenoh",
    [
        zenoh_open,
        session_declare_publisher,
        publisher_put,
        tester_pub,
        tester_sub,
        session_declare_subscriber,
        // send_message
    ],
    load = load
);
