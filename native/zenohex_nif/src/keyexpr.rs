use zenoh::key_expr::{keyexpr, KeyExpr};

#[rustler::nif]
fn key_expr_intersects(key_expr1: &str, key_expr2: &str) -> bool {
    let key_expr1 = unsafe { KeyExpr::from_str_uncheckend(key_expr1) };
    let key_expr2 = unsafe { KeyExpr::from_str_uncheckend(key_expr2) };
    keyexpr::intersects(&key_expr1, &key_expr2)
}
