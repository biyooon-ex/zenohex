use rustler::ErlOption;

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Config"]
pub(crate) struct ExConfig {
    scouting: ExConfigScouting,
}

impl From<ExConfig> for zenoh::prelude::config::Config {
    fn from(value: ExConfig) -> Self {
        let mut config = zenoh::prelude::config::peer();
        config.scouting = value.scouting.into();
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
