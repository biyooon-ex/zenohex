use std::{borrow::Cow, io::Write};

use rustler::{Encoder, Env, OwnedBinary, Term};
use zenoh::prelude::KnownEncoding;

pub(crate) struct ExValue;

impl ExValue {
    pub(crate) fn from<'a>(env: Env<'a>, value: &zenoh::value::Value) -> Term<'a> {
        match value.encoding.prefix() {
            KnownEncoding::Empty => unimplemented!(),
            KnownEncoding::AppOctetStream => match Cow::try_from(value) {
                Ok(value) => {
                    let mut binary = OwnedBinary::new(value.len()).unwrap();
                    binary.as_mut_slice().write_all(&value).unwrap();
                    binary.release(env).encode(env)
                }
                Err(error) => panic!("{}", error.to_string()),
            },
            KnownEncoding::AppCustom => unimplemented!(),
            KnownEncoding::TextPlain => match String::try_from(value) {
                Ok(value) => value.encode(env),
                Err(error) => panic!("{}", error.to_string()),
            },
            KnownEncoding::AppProperties => unimplemented!(),
            KnownEncoding::AppJson => unimplemented!(),
            KnownEncoding::AppSql => unimplemented!(),
            KnownEncoding::AppInteger => match i64::try_from(value) {
                Ok(value) => value.encode(env),
                Err(error) => panic!("{}", error.to_string()),
            },
            KnownEncoding::AppFloat => match f64::try_from(value) {
                Ok(value) => value.encode(env),
                Err(error) => panic!("{}", error.to_string()),
            },
            KnownEncoding::AppXml => unimplemented!(),
            KnownEncoding::AppXhtmlXml => unimplemented!(),
            KnownEncoding::AppXWwwFormUrlencoded => unimplemented!(),
            KnownEncoding::TextJson => unimplemented!(),
            KnownEncoding::TextHtml => unimplemented!(),
            KnownEncoding::TextXml => unimplemented!(),
            KnownEncoding::TextCss => unimplemented!(),
            KnownEncoding::TextCsv => unimplemented!(),
            KnownEncoding::TextJavascript => unimplemented!(),
            KnownEncoding::ImageJpeg => unimplemented!(),
            KnownEncoding::ImagePng => unimplemented!(),
            KnownEncoding::ImageGif => unimplemented!(),
        }
    }
}
