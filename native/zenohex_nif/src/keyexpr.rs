#[rustler::nif]
fn keyexpr_autocanonize(key_expr: String) -> rustler::NifResult<(rustler::Atom, String)> {
    let mut key_expr = key_expr;
    match zenoh::key_expr::keyexpr::autocanonize(&mut key_expr) {
        Ok(key_expr) => Ok((rustler::types::atom::ok(), key_expr.to_string())),
        Err(error) => Err(rustler::Error::Term(crate::zenoh_error!(error))),
    }
}

#[rustler::nif(name = "keyexpr_valid?")]
fn keyexpr_valid(key_expr: &str) -> rustler::NifResult<bool> {
    match zenoh::key_expr::keyexpr::new(key_expr) {
        Ok(_) => Ok(true),
        Err(error) => {
            log::error!("{}", error);
            Ok(false)
        }
    }
}

#[rustler::nif(name = "keyexpr_intersects?")]
fn keyexpr_intersects(key_expr1: &str, key_expr2: &str) -> rustler::NifResult<bool> {
    let key_expr1 = new(key_expr1)?;
    let key_expr2 = new(key_expr2)?;

    Ok(key_expr1.intersects(key_expr2))
}

#[rustler::nif(name = "keyexpr_includes?")]
fn keyexpr_includes(key_expr1: &str, key_expr2: &str) -> rustler::NifResult<bool> {
    let key_expr1 = new(key_expr1)?;
    let key_expr2 = new(key_expr2)?;

    Ok(key_expr1.includes(key_expr2))
}

#[rustler::nif]
fn keyexpr_join(key_expr1: &str, key_expr2: &str) -> rustler::NifResult<(rustler::Atom, String)> {
    let ke1 = zenoh::key_expr::keyexpr::new(key_expr1)
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;
    ke1.join(key_expr2)
        .map(|ke| (rustler::types::atom::ok(), ke.to_string()))
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))
}

fn new(key_expr: &str) -> rustler::NifResult<&zenoh::key_expr::keyexpr> {
    match zenoh::key_expr::keyexpr::new(key_expr) {
        Ok(key_expr) => Ok(key_expr),
        Err(error) => Err(rustler::Error::RaiseTerm(Box::new(
            crate::helper::exception::ArgumentError {
                message: error.to_string(),
            },
        ))),
    }
}
