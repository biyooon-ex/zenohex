use std::io::Write;
use std::sync::Mutex;

use zenoh::Wait;

struct ZenohQuery(Mutex<Option<zenoh::query::Query>>);
#[rustler::resource_impl]
impl rustler::Resource for ZenohQuery {}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Query"]
pub(crate) struct ZenohexQuery<'a> {
    key_expr: String,
    parameters: String,
    payload: Option<rustler::Binary<'a>>,
    encoding: Option<String>,
    zenoh_query: rustler::ResourceArc<ZenohQuery>,
}

impl<'a> ZenohexQuery<'a> {
    pub(crate) fn from(env: rustler::Env<'a>, query: zenoh::query::Query) -> Self {
        let payload_binary = query.payload().map(|payload| {
            let mut payload_binary = rustler::OwnedBinary::new(payload.len()).unwrap();
            payload_binary
                .as_mut_slice()
                .write_all(&payload.to_bytes())
                .unwrap();
            payload_binary.release(env)
        });

        let encoding: Option<String> = query.encoding().map(|encoding| encoding.to_string());

        ZenohexQuery {
            key_expr: query.key_expr().to_string(),
            parameters: query.parameters().to_string(),
            payload: payload_binary,
            encoding,
            zenoh_query: rustler::ResourceArc::new(ZenohQuery(Mutex::new(Some(query)))),
        }
    }
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Query.ReplyError"]
pub(crate) struct ZenohexQueryReplyError<'a> {
    payload: rustler::Binary<'a>,
    encoding: String,
}

impl<'a> ZenohexQueryReplyError<'a> {
    pub(crate) fn from(env: rustler::Env<'a>, reply_error: zenoh::query::ReplyError) -> Self {
        let payload = reply_error.payload();
        let mut payload_binary = rustler::OwnedBinary::new(payload.len()).unwrap();
        payload_binary
            .as_mut_slice()
            .write_all(&payload.to_bytes())
            .unwrap();
        ZenohexQueryReplyError {
            payload: payload_binary.release(env),
            encoding: reply_error.encoding().to_string(),
        }
    }
}

#[rustler::nif]
fn query_reply(zenohex_query: ZenohexQuery) -> rustler::NifResult<rustler::Atom> {
    let mutex = &zenohex_query.zenoh_query.0;
    let mut maybe_query = {
        let mut guard = mutex.lock().unwrap();
        guard.take()
    };
    if let Some(payload) = zenohex_query.payload {
        match Option::take(&mut maybe_query) {
            Some(query) => {
                match query
                    .reply(zenohex_query.key_expr, payload.as_slice())
                    .wait()
                {
                    Ok(()) => {
                        // NOTE: Dropping the query automatically sends a ResponseFinal.
                        //       Therefore, we must drop the query explicitly at the end of the reply.
                        drop(query);
                        Ok(rustler::types::atom::ok())
                    }
                    Err(error) => Err(rustler::Error::Term(Box::new(error.to_string()))),
                }
            }
            None => Err(rustler::Error::Term(Box::new(
                "ZenohQuery has already been dropped, which means ResponseFinal has already been sent.".to_string(),
            ))),
        }
    } else {
        Err(rustler::Error::Term(Box::new(
            "payload not found".to_string(),
        )))
    }
}
