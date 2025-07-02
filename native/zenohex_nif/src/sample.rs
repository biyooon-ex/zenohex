use std::io::Write;

#[derive(rustler::NifUnitEnum)]
enum SampleKind {
    Put,
    Delete,
}

impl From<zenoh::sample::SampleKind> for SampleKind {
    fn from(value: zenoh::sample::SampleKind) -> Self {
        match value {
            zenoh::sample::SampleKind::Put => SampleKind::Put,
            zenoh::sample::SampleKind::Delete => SampleKind::Delete,
        }
    }
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Sample"]
pub struct ZenohexSample<'a> {
    encoding: String,
    key_expr: String,
    kind: SampleKind,
    payload: rustler::Binary<'a>,
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
            encoding: sample.encoding().to_string(),
            key_expr: sample.key_expr().to_string(),
            kind: SampleKind::from(sample.kind()),
            payload: payload_binary.release(env),
        }
    }
}
