use rustler::ErlOption;

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Config"]
pub(crate) struct ExConfig {
    connect: ExConfigConnect,
    scouting: ExConfigScouting,
}

impl From<ExConfig> for zenoh::Config {
    fn from(value: ExConfig) -> Self {
        /*
        let mut config = zenoh::Config::default();
        config.connect = value.connect.into();
        config.scouting = value.scouting.into();
        */
        let config = zenoh::Config::default();
        value;
        config
    }
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Config.Connect"]
pub(crate) struct ExConfigConnect {
    endpoints: Vec<String>,
}

impl From<ExConfigConnect> for zenoh::config::Config {
    fn from(value: ExConfigConnect) -> Self {
        /*
        let endpoints = value
            .endpoints
            .iter()
            .map(|endpoint| {
                zenoh::config::EndPoint::try_from(endpoint.clone())
                    .unwrap_or_else(|error| panic!("{}", error.to_string()))
            })
            .collect();
        let mut config = zenoh::Config::ConnectConfig::default();
        let _ = config.set_endpoints(endpoints);
        */
        let config = zenoh::Config::default();
        value;
        config
    }
}

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Config.Scouting"]
pub(crate) struct ExConfigScouting {
    delay: ErlOption<u64>,
}

// TODO: may be the below
// impl From<ExConfigScouting> for zenoh::scouting::Scout<Receiver<T>> {
impl From<ExConfigScouting> for zenoh::config::Config {
    fn from(value: ExConfigScouting) -> Self {
        /*
        let mut config = zenoh::Config::ScoutingConf::default();
        let _ = match Option::<u64>::from(value.delay) {
            Some(delay) => config.set_delay(Some(delay)),
            None => config.set_delay(None),
        };
        */
        let config = zenoh::Config::default();
        value;
        config
    }
}
