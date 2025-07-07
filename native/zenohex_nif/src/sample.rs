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
    attachment: Option<rustler::Binary<'a>>,
    congestion_control: crate::builder::CongestionControl,
    encoding: String,
    express: bool,
    key_expr: String,
    kind: SampleKind,
    payload: rustler::Binary<'a>,
    priority: crate::builder::Priority,
    timestamp: Option<String>,
}

impl<'a> ZenohexSample<'a> {
    pub fn from(env: rustler::Env<'a>, sample: &zenoh::sample::Sample) -> Self {
        let attachment = sample.attachment().map(|attachment| {
            let mut owned_binary = rustler::OwnedBinary::new(attachment.len()).unwrap();

            owned_binary
                .as_mut_slice()
                .write_all(&attachment.to_bytes())
                .unwrap();

            owned_binary.release(env)
        });

        let payload = {
            let payload = sample.payload();
            let mut owned_binary = rustler::OwnedBinary::new(payload.len()).unwrap();

            owned_binary
                .as_mut_slice()
                .write_all(&payload.to_bytes())
                .unwrap();

            owned_binary.release(env)
        };

        let timestamp = sample
            .timestamp()
            .map(|timestamp| timestamp.to_string_rfc3339_lossy());

        ZenohexSample {
            attachment,
            congestion_control: sample.congestion_control().into(),
            encoding: sample.encoding().to_string(),
            express: sample.express(),
            key_expr: sample.key_expr().to_string(),
            kind: sample.kind().into(),
            payload,
            priority: sample.priority().into(),
            timestamp,
        }
    }
}
