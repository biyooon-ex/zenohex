use std::io::Write;

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Sample"]
pub struct ZenohexSample<'a> {
    key_expr: String,
    payload: rustler::Binary<'a>,
    encoding: String,
}

impl<'a> ZenohexSample<'a> {
    pub fn from(env: rustler::Env<'a>, sample: &zenoh::sample::Sample) -> Self {
        let payload = sample.payload();
        let mut payload_binary = rustler::OwnedBinary::new(payload.len()).unwrap();

        payload_binary
            .as_mut_slice()
            .write_all(&payload.to_bytes())
            .unwrap();

        ZenohexSample {
            key_expr: sample.key_expr().to_string(),
            payload: payload_binary.release(env),
            encoding: sample.encoding().to_string(),
        }
    }
}
