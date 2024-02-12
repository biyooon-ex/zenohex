use rustler::ErlOption;

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Config"]
pub(crate) struct ExConfig {
    connect: ExConfigConnect,
    scouting: ExConfigScouting,
}

impl From<ExConfig> for zenoh::prelude::config::Config {
    fn from(value: ExConfig) -> Self {
        let mut config = zenoh::prelude::config::peer();
        config.connect = value.connect.into();
        config.scouting = value.scouting.into();
        config
    }
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Config.Connect"]
pub(crate) struct ExConfigConnect {
    endpoints: Vec<String>,
}

impl From<ExConfigConnect> for zenoh::prelude::config::ConnectConfig {
    fn from(value: ExConfigConnect) -> Self {
        let endpoints = value
            .endpoints
            .iter()
            .map(|endpoint| {
                zenoh::prelude::config::EndPoint::try_from(endpoint.clone())
                    .unwrap_or_else(|error| panic!("{}", error.to_string()))
            })
            .collect();
        let mut config = zenoh::prelude::config::ConnectConfig::default();
        let _ = config.set_endpoints(endpoints);
        config
    }
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Config.Scouting"]
pub(crate) struct ExConfigScouting {
    delay: ErlOption<u64>,
}

impl From<ExConfigScouting> for zenoh::prelude::config::ScoutingConf {
    fn from(value: ExConfigScouting) -> Self {
        let mut config = zenoh::prelude::config::ScoutingConf::default();
        let _ = match Option::<u64>::from(value.delay) {
            Some(delay) => config.set_delay(Some(delay)),
            None => config.set_delay(None),
        };
        config
    }
}
