pub mod tester {
    use async_std::task::sleep;
    use futures::executor::block_on;
    use futures::prelude::*;
    use futures::select;
    use std::time::Duration;
    use zenoh::config::Config;
    use zenoh::prelude::r#async::*;

    pub async fn pub_zenoh(key_expr: String, value: String) {
        env_logger::init();

        let session = zenoh::open(Config::default()).res().await.unwrap();
        println!("Declaring Publisher on '{}'...", key_expr);
        let publisher = session.declare_publisher(&key_expr).res().await.unwrap();

        for idx in 0..u32::MAX {
            sleep(Duration::from_secs(1)).await;
            let buf = format!("[{:4}] {}", idx, value);
            println!("Putting Data ('{}': '{}')...", &key_expr, buf);
            publisher.put(buf).res().await.unwrap();
        }
    }

    pub async fn sub_zenoh(key_expr: String) {
        env_logger::init();

        println!("Opening session...");
        let session = zenoh::open(Config::default()).res().await.unwrap();

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
    fn call_pub_zenoh(key_expr: String, value: String) {
        block_on(pub_zenoh(key_expr, value));
    }
    #[rustler::nif]
    pub fn call_sub_zenoh(key_exprt: String) {
        block_on(sub_zenoh(key_exprt));
    }
}
