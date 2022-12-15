use futures::executor::block_on;
use futures::prelude::*;
use futures::select;
use rustler::resource::ResourceTypeProvider;
use rustler::types::atom::{error, ok};
use rustler::types::{Decoder, Encoder};
use rustler::OwnedBinary;
use rustler::{Env, ResourceArc, Term};
use std::convert::TryFrom;
use std::sync::Mutex;
use std::time::Duration;
use zenoh::config::Config;
use zenoh::prelude::r#async::*;
use zenoh::publication::Publisher;

struct SessionWrapper {
    pub session: Mutex<Session>,
}
struct PublisherWrapper {
    pub publisher: Mutex<Publisher<'static>>,
}

fn load(env: Env, _: Term) -> bool {
    rustler::resource!(SessionWrapper, env);
    rustler::resource!(PublisherWrapper, env);
    true
}

#[rustler::nif]
fn open(env: Env) -> Term {
    let resource = ResourceArc::new(SessionWrapper {
        session: Mutex::new(block_on(zenoh::open(Config::default()).res()).unwrap()),
    });
    (ok(), resource).encode(env)
}

#[rustler::nif]
fn nif_declare_publisher(
    env: Env,
    resource_session: ResourceArc<SessionWrapper>,
    keyexpr: String,
) -> Term {
    let session = &resource_session.session;
    let publisher = session.lock().unwrap().declare_publisher("");
    let resource_publisher = ResourceArc::new(PublisherWrapper {
        publisher: Mutex::new(block_on(publisher.res()).unwrap()),
    });
    (ok(), resource_publisher).encode(env)
}

rustler::init!("Elixir.NifZenoh", [open], load = load);
