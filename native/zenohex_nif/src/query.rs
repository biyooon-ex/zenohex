use std::io::Write;
use std::ops::Deref;
use std::sync::Mutex;

use zenoh::Wait;

use crate::builder::Builder;

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
    attachment: Option<rustler::Binary<'a>>,
    encoding: Option<String>,
    key_expr: String,
    parameters: String,
    payload: Option<rustler::Binary<'a>>,
    selector: String,
    zenoh_query: rustler::ResourceArc<QueryResource>,
}

impl<'a> ZenohexQuery<'a> {
    pub fn from(env: rustler::Env<'a>, query: zenoh::query::Query) -> Self {
        let attachment = query.attachment().map(|attachment| {
            let mut owned_binary = rustler::OwnedBinary::new(attachment.len()).unwrap();

            owned_binary
                .as_mut_slice()
                .write_all(&attachment.to_bytes())
                .unwrap();

            owned_binary.release(env)
        });

        let encoding: Option<String> = query.encoding().map(|encoding| encoding.to_string());

        let payload = query.payload().map(|payload| {
            let mut owned_binary = rustler::OwnedBinary::new(payload.len()).unwrap();

            owned_binary
                .as_mut_slice()
                .write_all(&payload.to_bytes())
                .unwrap();

            owned_binary.release(env)
        });

        ZenohexQuery {
            attachment,
            encoding,
            key_expr: query.key_expr().to_string(),
            parameters: query.parameters().to_string(),
            payload,
            selector: query.selector().to_string(),
            zenoh_query: rustler::ResourceArc::new(QueryResource::new(query)),
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
    pub fn from(env: rustler::Env<'a>, reply_error: zenoh::query::ReplyError) -> Self {
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
        let reply_builder = query.reply(key_expr, payload.as_slice());

        reply_builder
            .apply_opts(opts)?
            .wait()
            .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

        Ok(rustler::types::atom::ok())
    })
}

#[rustler::nif]
fn query_reply_error(
    query_resource: rustler::ResourceArc<QueryResource>,
    payload: rustler::Binary,
    opts: rustler::Term,
) -> rustler::NifResult<rustler::Atom> {
    handle_reply(query_resource, opts, |query| {
        let reply_builder = query.reply_err(payload.as_slice());

        reply_builder
            .apply_opts(opts)?
            .wait()
            .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

        Ok(rustler::types::atom::ok())
    })
}

#[rustler::nif]
fn query_reply_delete(
    query_resource: rustler::ResourceArc<QueryResource>,
    key_expr: &str,
    opts: rustler::Term,
) -> rustler::NifResult<rustler::Atom> {
    handle_reply(query_resource, opts, |query| {
        let reply_builder = query.reply_del(key_expr);

        reply_builder
            .apply_opts(opts)?
            .wait()
            .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

        Ok(rustler::types::atom::ok())
    })
}

fn handle_reply<F>(
    query_resource: rustler::ResourceArc<QueryResource>,
    opts: rustler::Term,
    reply_fn: F,
) -> rustler::NifResult<rustler::Atom>
where
    F: FnOnce(&zenoh::query::Query) -> rustler::NifResult<rustler::Atom>,
{
    let mut option_query = query_resource.lock().unwrap();

    let is_final = match crate::helper::keyword::get_value(opts, crate::atoms::is_final())? {
        Some(val) => val.decode::<bool>()?,
        None => true,
    };

    let error_term = rustler::Error::Term(Box::new(
        "QueryResource has already been dropped, which means ResponseFinal has already been sent.",
    ));

    // NOTE: Dropping the query automatically sends a ResponseFinal.
    //       Therefore, we must drop the query explicitly at the end of the reply.
    if is_final {
        match option_query.take() {
            Some(query) => reply_fn(&query)?,
            None => return Err(error_term),
        };
    } else {
        match option_query.as_ref() {
            Some(query) => reply_fn(query)?,
            None => return Err(error_term),
        };
    }

    Ok(rustler::types::atom::ok())
}
