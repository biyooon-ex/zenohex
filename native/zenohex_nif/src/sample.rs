use rustler::{Env, ErlOption, ResourceArc, Term};

use crate::SampleRef;

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Sample"]
pub(crate) struct ExSample<'a> {
    pub(crate) key_expr: String,
    pub(crate) value: Term<'a>,
    pub(crate) kind: ExSampleKind,
    pub(crate) reference: ErlOption<ResourceArc<SampleRef>>,
}

impl ExSample<'_> {
    pub(crate) fn from(env: Env, sample: zenoh::sample::Sample) -> ExSample {
        ExSample {
            key_expr: sample.key_expr.to_string(),
            value: crate::value::ExValue::from(env, &sample.value),
            kind: sample.kind.into(),
            reference: ErlOption::some(ResourceArc::new(SampleRef(sample))),
        }
    }
}

#[derive(rustler::NifUnitEnum)]
pub(crate) enum ExSampleKind {
    Put,
    Delete,
}

impl From<zenoh::prelude::SampleKind> for ExSampleKind {
    fn from(kind: zenoh::prelude::SampleKind) -> Self {
        match kind {
            zenoh::prelude::SampleKind::Put => ExSampleKind::Put,
            zenoh::prelude::SampleKind::Delete => ExSampleKind::Delete,
        }
    }
}
