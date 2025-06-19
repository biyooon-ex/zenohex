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

mod atoms {
    rustler::atoms! {
        is_final = "final?",
    }
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
fn query_reply(
    zenoh_query: rustler::ResourceArc<ZenohQuery>,
    key_expr: &str,
    payload: &str,
    opts: rustler::Term,
) -> rustler::NifResult<rustler::Atom> {
    handle_reply(zenoh_query, opts, |query| {
        query.reply(key_expr, payload).wait()
    })
}

#[rustler::nif]
fn query_reply_error(
    zenoh_query: rustler::ResourceArc<ZenohQuery>,
    payload: &str,
    opts: rustler::Term,
) -> rustler::NifResult<rustler::Atom> {
    handle_reply(zenoh_query, opts, |query| query.reply_err(payload).wait())
}

fn handle_reply<F>(
    zenoh_query: rustler::ResourceArc<ZenohQuery>,
    opts: rustler::Term,
    reply_fn: F,
) -> rustler::NifResult<rustler::Atom>
where
    F: FnOnce(&zenoh::query::Query) -> Result<(), zenoh::Error>,
{
    let zenoh_query = &zenoh_query.0;
    let mut option_query = zenoh_query.lock().unwrap();

    let query = option_query.as_ref().ok_or_else(|| {
        rustler::Error::Term(Box::new(
            "ZenohQuery has already been dropped, which means ResponseFinal has already been sent.",
        ))
    })?;

    reply_fn(query).map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

    if let Some(opt_value) = get_opt_value(opts, crate::query::atoms::is_final())? {
        // NOTE: Dropping the query automatically sends a ResponseFinal.
        //       Therefore, we must drop the query explicitly at the end of the reply.
        let is_final: bool = opt_value.decode()?;
        if is_final {
            option_query.take();
        }
    }

    Ok(rustler::types::atom::ok())
}

fn get_opt_value(
    opts: rustler::Term,
    key: rustler::Atom,
) -> rustler::NifResult<Option<rustler::Term>> {
    let opts_iter: rustler::ListIterator = opts.decode()?;

    for opt in opts_iter {
        let (k, v): (rustler::Atom, rustler::Term) = opt.decode()?;
        if k == key {
            return Ok(Some(v));
        }
    }

    Ok(None)
}
