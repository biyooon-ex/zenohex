use std::ops::Deref;
use std::path::PathBuf;

#[derive(rustler::NifUnitEnum)]
pub enum WhatAmI {
    Router,
    Peer,
    Client,
}

impl From<zenoh::config::WhatAmI> for WhatAmI {
    fn from(value: zenoh::config::WhatAmI) -> Self {
        match value {
            zenoh::config::WhatAmI::Router => WhatAmI::Router,
            zenoh::config::WhatAmI::Peer => WhatAmI::Peer,
            zenoh::config::WhatAmI::Client => WhatAmI::Client,
        }
    }
}

impl From<WhatAmI> for zenoh::config::WhatAmI {
    fn from(value: WhatAmI) -> Self {
        match value {
            WhatAmI::Router => zenoh::config::WhatAmI::Router,
            WhatAmI::Peer => zenoh::config::WhatAmI::Peer,
            WhatAmI::Client => zenoh::config::WhatAmI::Client,
        }
    }
}

pub struct Locator(String);

impl Deref for Locator {
    type Target = String;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl From<zenoh::config::Locator> for Locator {
    fn from(value: zenoh::config::Locator) -> Self {
        Locator(String::from(value.as_str()))
    }
}

#[rustler::nif]
fn config_default() -> String {
    zenoh::Config::default().to_string()
}

#[rustler::nif]
fn config_from_env(path: String) -> rustler::NifResult<(rustler::Atom, String)> {
    // Here, we intentionally call `zenoh::Config::from_file` instead of
    // `zenoh::Config::from_env` to handle cases where ZENOH_CONFIG is set
    // using `System.put_env/2`. Since this function is merely emulated by
    // BEAM, so it does not update the OS environment variables including
    // the Rust side.
    // See: https://github.com/biyooon-ex/zenohex/pull/174#discussion_r3069406217
    let config = zenoh::Config::from_file(PathBuf::from(path))
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;
    Ok((rustler::types::atom::ok(), config.to_string()))
}

#[rustler::nif]
fn config_from_file(path: String) -> rustler::NifResult<(rustler::Atom, String)> {
    let config = zenoh::Config::from_file(PathBuf::from(path))
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;
    Ok((rustler::types::atom::ok(), config.to_string()))
}

#[rustler::nif]
fn config_from_json5(json5_binary: &str) -> rustler::NifResult<(rustler::Atom, String)> {
    let config = zenoh::Config::from_json5(json5_binary)
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    Ok((rustler::types::atom::ok(), config.to_string()))
}

#[rustler::nif]
fn config_get_json(json5_binary: &str, key: &str) -> rustler::NifResult<(rustler::Atom, String)> {
    let config = zenoh::Config::from_json5(json5_binary)
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;
    let value = config
        .get_json(key)
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;
    Ok((rustler::types::atom::ok(), value.to_string()))
}

#[rustler::nif]
fn config_insert_json5(
    json5_binary: &str,
    key: &str,
    value: &str,
) -> rustler::NifResult<(rustler::Atom, String)> {
    let mut config = zenoh::Config::from_json5(json5_binary)
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;
    config
        .insert_json5(key, value)
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;
    Ok((rustler::types::atom::ok(), config.to_string()))
}
