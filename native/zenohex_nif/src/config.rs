#[rustler::nif]
fn config_default() -> String {
    zenoh::Config::default().to_string()
}

#[rustler::nif]
fn config_from_json5(json5_binary: &str) -> rustler::NifResult<(rustler::Atom, String)> {
    let config = zenoh::Config::from_json5(json5_binary)
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    Ok((rustler::types::atom::ok(), config.to_string()))
}
