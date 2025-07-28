#[rustler::nif]
fn keyword_get_value(
    keyword: rustler::Term,
    key: rustler::Atom,
) -> rustler::NifResult<Option<rustler::Term>> {
    get_value(keyword, key)
}

pub fn get_value(
    keyword: rustler::Term,
    key: rustler::Atom,
) -> rustler::NifResult<Option<rustler::Term>> {
    let iter: rustler::ListIterator = keyword.decode()?;

    for tuple in iter {
        let (k, v): (rustler::Atom, rustler::Term) = tuple.decode()?;
        if k == key {
            return Ok(Some(v));
        }
    }

    Ok(None)
}
