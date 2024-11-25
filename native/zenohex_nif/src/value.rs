/* TODO: this file may be changed to bytes.rs */
//use std::{borrow::Cow, io::Write};

use rustler::{Env, Term};
use zenoh::bytes::Encoding;

pub(crate) struct ExValue;

impl ExValue {
    pub(crate) fn from<'a>(env: Env<'a>, value: &zenoh::bytes::ZBytes) -> Term<'a> {
        todo!()
        /*
        // match value.encoding.prefix() {
        match value.encoding() {
            // TODO: implement??
            &Encoding::ZENOH_BYTES => unimplemented!(),
            &Encoding::ZENOH_STRING => unimplemented!(),
            &Encoding::ZENOH_SERIALIZED => unimplemented!(),
            /*
            &Encoding::APPLICATION_OCTET_STREAM =>  match Cow::try_from(value) {
                Ok(value) => {
                    let mut binary = OwnedBinary::new(value.len()).unwrap();
                    binary.as_mut_slice().write_all(&value).unwrap();
                    binary.release(env).encode(env)
                }
                Err(error) => panic!("{}", error.to_string()),
            },
            */
            &Encoding::APPLICATION_OCTET_STREAM => unimplemented!(),
            /*
            &Encoding::TEXT_PLAIN => match String::try_from(value) {
                Ok(value) => value.encode(env),
                Err(error) => panic!("{}", error.to_string()),
            },
            */
            &Encoding::TEXT_PLAIN => unimplemented!(),
            &Encoding::APPLICATION_JSON => unimplemented!(),
            &Encoding::TEXT_JSON => unimplemented!(),
            &Encoding::APPLICATION_CDR => unimplemented!(),
            &Encoding::APPLICATION_CBOR => unimplemented!(),
            &Encoding::APPLICATION_YAML => unimplemented!(),
            &Encoding::TEXT_YAML => unimplemented!(),
            &Encoding::TEXT_JSON5 => unimplemented!(),
            &Encoding::APPLICATION_PYTHON_SERIALIZED_OBJECT => unimplemented!(),
            &Encoding::APPLICATION_PROTOBUF => unimplemented!(),
            &Encoding::APPLICATION_JAVA_SERIALIZED_OBJECT => unimplemented!(),
            &Encoding::APPLICATION_OPENMETRICS_TEXT => unimplemented!(),
            &Encoding::IMAGE_PNG => unimplemented!(),
            &Encoding::IMAGE_JPEG => unimplemented!(),
            &Encoding::IMAGE_GIF => unimplemented!(),
            &Encoding::IMAGE_BMP => unimplemented!(),
            &Encoding::IMAGE_WEBP => unimplemented!(),
            &Encoding::APPLICATION_XML => unimplemented!(),
            &Encoding::APPLICATION_X_WWW_FORM_URLENCODED => unimplemented!(),
            &Encoding::TEXT_HTML => unimplemented!(),
            &Encoding::TEXT_XML => unimplemented!(),
            &Encoding::TEXT_CSS => unimplemented!(),
            &Encoding::TEXT_JAVASCRIPT => unimplemented!(),
            &Encoding::TEXT_MARKDOWN => unimplemented!(),
            &Encoding::TEXT_CSV => unimplemented!(),
            &Encoding::APPLICATION_SQL => unimplemented!(),
            &Encoding::APPLICATION_COAP_PAYLOAD => unimplemented!(),
            &Encoding::APPLICATION_JSON_PATCH_JSON => unimplemented!(),
            &Encoding::APPLICATION_JSON_SEQ => unimplemented!(),
            &Encoding::APPLICATION_JSONPATH => unimplemented!(),
            &Encoding::APPLICATION_JWT => unimplemented!(),
            &Encoding::APPLICATION_MP4 => unimplemented!(),
            &Encoding::APPLICATION_SOAP_XML => unimplemented!(),
            &Encoding::APPLICATION_YANG => unimplemented!(),
            &Encoding::AUDIO_AAC => unimplemented!(),
            &Encoding::AUDIO_FLAC => unimplemented!(),
            &Encoding::AUDIO_MP4 => unimplemented!(),
            &Encoding::AUDIO_OGG => unimplemented!(),
            &Encoding::AUDIO_VORBIS => unimplemented!(),
            &Encoding::VIDEO_H261 => unimplemented!(),
            &Encoding::VIDEO_H263 => unimplemented!(),
            &Encoding::VIDEO_H264 => unimplemented!(),
            &Encoding::VIDEO_H265 => unimplemented!(),
            &Encoding::VIDEO_H266 => unimplemented!(),
            &Encoding::VIDEO_MP4 => unimplemented!(),
            &Encoding::VIDEO_OGG => unimplemented!(),
            &Encoding::VIDEO_RAW => unimplemented!(),
            &Encoding::VIDEO_VP8 => unimplemented!(),
            &Encoding::VIDEO_VP9 => unimplemented!(),
            _ => todo!(),
        }
        */
    }
}
