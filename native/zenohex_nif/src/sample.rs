use rustler::{Env, ResourceArc, Term};

use crate::ExSampleRef;

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Sample"]
pub struct Sample<'a> {
    pub(crate) key_expr: String,
    pub(crate) value: Term<'a>,
    pub(crate) kind: SampleKind,
    pub(crate) reference: ResourceArc<ExSampleRef>,
}

impl Sample<'_> {
    pub(crate) fn from(env: Env, sample: zenoh::sample::Sample) -> Sample {
        Sample {
            key_expr: sample.key_expr.to_string(),
            value: crate::value::Value::to_term(env, &sample.value),
            kind: sample.kind.into(),
            reference: ResourceArc::new(ExSampleRef(sample)),
        }
    }
}

#[derive(rustler::NifUnitEnum)]
pub enum SampleKind {
    Put,
    Delete,
}

impl From<zenoh::prelude::SampleKind> for SampleKind {
    fn from(kind: zenoh::prelude::SampleKind) -> Self {
        match kind {
            zenoh::prelude::SampleKind::Put => SampleKind::Put,
            zenoh::prelude::SampleKind::Delete => SampleKind::Delete,
        }
    }
}
