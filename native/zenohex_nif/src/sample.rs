use rustler::{Binary, Env, ErlOption, ResourceArc, Term};

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

impl From<ExSample<'_>> for zenoh::sample::Sample {
    fn from(sample: ExSample) -> Self {
        let key_expr = unsafe { zenoh::key_expr::KeyExpr::from_string_unchecked(sample.key_expr) };
        let value = match sample.value.get_type() {
            rustler::TermType::Atom => unimplemented!(),
            rustler::TermType::Binary => {
                let binary = sample.value.decode::<Binary>().unwrap();
                zenoh::bytes::ZBytes::from(binary.as_slice())
            }
            rustler::TermType::Fun => unimplemented!(),
            rustler::TermType::List => unimplemented!(),
            rustler::TermType::Map => unimplemented!(),
            rustler::TermType::Integer => {
                zenoh::bytes::ZBytes::from(sample.value.decode::<i64>().unwrap())
            }
            rustler::TermType::Float => {
                zenoh::bytes::ZBytes::from(sample.value.decode::<f64>().unwrap())
            }
            rustler::TermType::Pid => unimplemented!(),
            rustler::TermType::Port => unimplemented!(),
            rustler::TermType::Ref => unimplemented!(),
            rustler::TermType::Tuple => unimplemented!(),
            rustler::TermType::Unknown => unimplemented!(),
        };
        zenoh::sample::Sample::new(key_expr, value)
    }
}

#[derive(rustler::NifUnitEnum)]
pub(crate) enum ExSampleKind {
    Put,
    Delete,
}

impl From<zenoh::sample::SampleKind> for ExSampleKind {
    fn from(kind: zenoh::sample::SampleKind) -> Self {
        match kind {
            zenoh::sample::SampleKind::Put => ExSampleKind::Put,
            zenoh::sample::SampleKind::Delete => ExSampleKind::Delete,
        }
    }
}
