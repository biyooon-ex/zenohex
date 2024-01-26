#[derive(rustler::NifStruct)]
#[module = "Zenohex.Queryable.Options"]
pub struct QueryableOptions {
    pub(crate) complete: bool,
}
