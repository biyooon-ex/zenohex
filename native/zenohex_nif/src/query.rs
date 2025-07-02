use std::io::Write;
use std::ops::Deref;
use std::sync::Mutex;

use zenoh::Wait;

struct QueryResource(Mutex<Option<zenoh::query::Query>>);

#[rustler::resource_impl]
impl rustler::Resource for QueryResource {}

impl Deref for QueryResource {
    type Target = Mutex<Option<zenoh::query::Query>>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl QueryResource {
    fn new(query: zenoh::query::Query) -> QueryResource {
        QueryResource(Mutex::new(Some(query)))
    }
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Query"]
pub struct ZenohexQuery<'a> {
    selector: String,
    key_expr: String,
    parameters: String,
    payload: Option<rustler::Binary<'a>>,
    encoding: Option<String>,
    attachment: Option<rustler::Binary<'a>>,
    zenoh_query: rustler::ResourceArc<QueryResource>,
}

impl<'a> ZenohexQuery<'a> {
    pub fn from(env: rustler::Env<'a>, query: &zenoh::query::Query) -> Self {
        let payload_binary = query.payload().map(|payload| {
            let mut payload_binary = rustler::OwnedBinary::new(payload.len()).unwrap();

            payload_binary
                .as_mut_slice()
                .write_all(&payload.to_bytes())
                .unwrap();

            payload_binary.release(env)
        });

        let attachment_binary = query.attachment().map(|attachment| {
            let mut attachment_binary = rustler::OwnedBinary::new(attachment.len()).unwrap();

            attachment_binary
                .as_mut_slice()
                .write_all(&attachment.to_bytes())
                .unwrap();

            attachment_binary.release(env)
        });

        let encoding: Option<String> = query.encoding().map(|encoding| encoding.to_string());

        ZenohexQuery {
            selector: query.selector().to_string(),
            key_expr: query.key_expr().to_string(),
            parameters: query.parameters().to_string(),
            payload: payload_binary,
            encoding,
            attachment: attachment_binary,
            zenoh_query: rustler::ResourceArc::new(QueryResource::new(query.clone())),
        }
    }
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Query.ReplyError"]
pub struct ZenohexQueryReplyError<'a> {
    payload: rustler::Binary<'a>,
    encoding: String,
}

impl<'a> ZenohexQueryReplyError<'a> {
    pub fn from(env: rustler::Env<'a>, reply_error: &zenoh::query::ReplyError) -> Self {
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
    query_resource: rustler::ResourceArc<QueryResource>,
    key_expr: &str,
    payload: rustler::Binary,
    opts: rustler::Term,
) -> rustler::NifResult<rustler::Atom> {
    handle_reply(query_resource, opts, |query| {
        query.reply(key_expr, payload.as_slice()).wait()
    })
}

#[rustler::nif]
fn query_reply_error(
    query_resource: rustler::ResourceArc<QueryResource>,
    payload: rustler::Binary,
    opts: rustler::Term,
) -> rustler::NifResult<rustler::Atom> {
    handle_reply(query_resource, opts, |query| {
        query.reply_err(payload.as_slice()).wait()
    })
}

fn handle_reply<F>(
    query_resource: rustler::ResourceArc<QueryResource>,
    opts: rustler::Term,
    reply_fn: F,
) -> rustler::NifResult<rustler::Atom>
where
    F: FnOnce(&zenoh::query::Query) -> Result<(), zenoh::Error>,
{
    let query_resource = &query_resource;
    let mut option_query = query_resource.lock().unwrap();

    let query = option_query.as_ref().ok_or_else(|| {
        rustler::Error::Term(Box::new(
            "QueryResource has already been dropped, which means ResponseFinal has already been sent.",
        ))
    })?;

    reply_fn(query).map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    if let Some(opt_value) = crate::helper::keyword::get_value(opts, crate::atoms::is_final())? {
        // NOTE: Dropping the query automatically sends a ResponseFinal.
        //       Therefore, we must drop the query explicitly at the end of the reply.
        let is_final: bool = opt_value.decode()?;
        if is_final {
            option_query.take();
        }
    }

    Ok(rustler::types::atom::ok())
}
