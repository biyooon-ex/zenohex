use futures::executor::block_on;
use rustler::types::atom::ok;
use rustler::types::Encoder;
use rustler::{Env, ResourceArc, Term};
use std::sync::Mutex;
use zenoh::config::Config;
use zenoh::prelude::r#async::*;
use zenoh::publication::Publisher;
pub mod tester;
use tester::tester::{tester_pub, tester_sub};

struct SessionContainer {
    session_mux: Mutex<&'static Session>,
}

struct PublisherContainer {
    publisher_mux: Mutex<Publisher<'static>>,
}

fn load<'a>(env: Env<'a>, _: Term<'a>) -> bool {
    rustler::resource!(SessionContainer, env);
    rustler::resource!(PublisherContainer, env);
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

rustler::init!(
    "Elixir.NifZenoh",
    [
        zenoh_open,
        session_declare_publisher,
        publisher_put,
        tester_pub,
        tester_sub
    ],
    load = load
);
