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
    pub(crate) fn from(env: rustler::Env<'a>, query: &zenoh::query::Query) -> Self {
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
            zenoh_query: rustler::ResourceArc::new(ZenohQuery(Mutex::new(Some(query.clone())))),
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
    pub(crate) fn from(env: rustler::Env<'a>, reply_error: &zenoh::query::ReplyError) -> Self {
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
    let zenoh_query = &zenohex_query.zenoh_query.0;
    let mut option_query = zenoh_query.lock().unwrap().take();

    let query = option_query.take().ok_or_else(|| {
        rustler::Error::Term(Box::new(
            "ZenohQuery has already been dropped, which means ResponseFinal has already been sent.",
        ))
    })?;

    let payload = zenohex_query
        .payload
        .ok_or_else(|| rustler::Error::Term(Box::new("payload not found")))?;

    query
        .reply(zenohex_query.key_expr, payload.as_slice())
        .wait()
        .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

    // NOTE: Dropping the query automatically sends a ResponseFinal.
    //       Therefore, we must drop the query explicitly at the end of the reply.
    drop(query);

    Ok(rustler::types::atom::ok())
}
