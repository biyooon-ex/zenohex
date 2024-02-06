use zenoh::key_expr::{keyexpr, KeyExpr};

#[rustler::nif]
fn key_expr_intersects(l: String, r: String) -> bool {
    let lke = unsafe { KeyExpr::from_string_unchecked(l) };
    let rke = unsafe { KeyExpr::from_string_unchecked(r) };
    keyexpr::intersects(&lke, &rke)
}
