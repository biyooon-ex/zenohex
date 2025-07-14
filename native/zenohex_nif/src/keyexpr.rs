#[rustler::nif]
fn keyexpr_autocanonize(key_expr: String) -> rustler::NifResult<(rustler::Atom, String)> {
    match zenoh::key_expr::keyexpr::autocanonize(&mut key_expr.clone()) {
        Ok(key_expr) => Ok((rustler::types::atom::ok(), key_expr.to_string())),
        Err(error) => Err(rustler::Error::Term(Box::new(error.to_string()))),
    }
}

#[rustler::nif(name = "keyexpr_valid?")]
fn keyexpr_valid(key_expr: &str) -> bool {
    new(key_expr).is_some()
}

#[rustler::nif(name = "keyexpr_intersects?")]
fn keyexpr_intersects(key_expr1: &str, key_expr2: &str) -> bool {
    let Some(key_expr1) = new(key_expr1) else {
        return false;
    };
    let Some(key_expr2) = new(key_expr2) else {
        return false;
    };

    key_expr1.intersects(key_expr2)
}

#[rustler::nif(name = "keyexpr_includes?")]
fn keyexpr_includes(key_expr1: &str, key_expr2: &str) -> bool {
    let Some(key_expr1) = new(key_expr1) else {
        return false;
    };
    let Some(key_expr2) = new(key_expr2) else {
        return false;
    };

    key_expr1.includes(key_expr2)
}

fn new(key_expr: &str) -> Option<&zenoh::key_expr::keyexpr> {
    match zenoh::key_expr::keyexpr::new(key_expr) {
        Ok(key_expr) => Some(key_expr),
        Err(error) => {
            log::error!("{}", error.to_string());
            None
        }
    }
}
