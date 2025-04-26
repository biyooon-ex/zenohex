#[rustler::nif]
fn config_default() -> String {
    zenoh::Config::default().to_string()
}

#[rustler::nif]
fn config_from_json5(json5_binary: &str) -> rustler::NifResult<(rustler::Atom, String)> {
    match zenoh::Config::from_json5(json5_binary) {
        Ok(config) => Ok((rustler::types::atom::ok(), config.to_string())),
        Err(error) => {
            let reason = error.to_string();
            Err(rustler::Error::Term(Box::new(reason)))
        }
    }
}
