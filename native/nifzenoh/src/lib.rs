use async_std::task::sleep;
use futures::executor::block_on;
use futures::prelude::*;
use futures::select;
use rustler::types::atom::{error, ok};
use rustler::types::Encoder;
use rustler::{Env, ResourceArc, Term};
use std::sync::Mutex;
use std::time::Duration;
use zenoh::config::Config;
use zenoh::prelude::r#async::*;
use zenoh::publication::Publisher;

pub struct SessionWrapper {
    session: &'static Session,
}
struct SessionContainer {
    mutex: Mutex<SessionWrapper>,
}

pub struct PublisherWrapper {
    publisher: Publisher<'static>,
}
struct PublisherContainer {
    mutex: Mutex<PublisherWrapper>,
}

fn load<'a>(env: Env<'a>, _: Term<'a>) -> bool {
    rustler::resource!(SessionContainer, env);
    rustler::resource!(PublisherContainer, env);
    true
}

#[rustler::nif]
fn open<'a>() -> ResourceArc<SessionContainer> {
    ResourceArc::new(SessionContainer {
        mutex: Mutex::new(SessionWrapper {
            session: Session::leak(block_on(zenoh::open(Config::default()).res()).unwrap()),
        }),
    })
}

#[rustler::nif]
fn nif_declare_publisher<'a>(
    env: Env<'a>,
    resource_session: ResourceArc<SessionContainer>,
    keyexpr: String,
) -> Term<'a> {
    let session = resource_session.mutex.lock().unwrap().session;
    let publisher = session.declare_publisher(keyexpr);
    let resource_publisher = ResourceArc::new(PublisherContainer {
        mutex: Mutex::new(PublisherWrapper {
            publisher: block_on(publisher.res()).unwrap(),
        }),
    });
    (ok(), resource_publisher).encode(env)
}

#[rustler::nif]
fn nif_put<'a>(
    env: Env<'a>,
    resource_session: ResourceArc<PublisherContainer>,
    value: String,
) -> Term<'a> {
    let publisher = &resource_session.mutex.lock().unwrap().publisher;
    block_on(publisher.put(value).res()).unwrap();
    (ok()).encode(env)
}

pub async fn sub_zenoh() {
    env_logger::init();

    println!("Opening session...");
    let session = zenoh::open(Config::default()).res().await.unwrap();
    let key_expr = "demo/example/zenoh-rs-pub".to_string();

    println!("Declaring Subscriber on '{}'...", &key_expr);
    let subscriber = session.declare_subscriber(&key_expr).res().await.unwrap();

    println!("Enter 'q' to quit...");
    let mut stdin = async_std::io::stdin();
    let mut input = [0_u8];
    loop {
        select!(
            sample = subscriber.recv_async() => {
                let sample = sample.unwrap();
                println!(">> [Subscriber] Received {} ('{}': '{}')",
                    sample.kind, sample.key_expr.as_str(), sample.value);
            },

            _ = stdin.read_exact(&mut input).fuse() => {
                match input[0] {
                    b'q' => break,
                    0 => sleep(Duration::from_secs(1)).await,
                    _ => (),
                }
            }
        );
    }
}

#[rustler::nif]
fn call_sub_zenoh() -> i64 {
    block_on(sub_zenoh());
    0
}

rustler::init!(
    "Elixir.NifZenoh",
    [open, nif_declare_publisher, nif_put, call_sub_zenoh],
    load = load
);
