use std::ops::Deref;
use std::sync::RwLock;
use std::time::Duration;
use std::time::Instant;

use zenoh::Wait;

#[derive(rustler::NifStruct)]
#[module = "Zenohex.Scouting.Hello"]
pub struct ZenohexScoutingHello {
    locators: Vec<String>,
    whatami: crate::config::WhatAmI,
    zid: String,
}

impl ZenohexScoutingHello {
    pub fn from(hello: zenoh::scouting::Hello) -> Self {
        let locators = hello.locators().iter().fold(
            Vec::<String>::new(),
            |mut locators: Vec<String>, locator: &zenoh::config::Locator| {
                locators.push(crate::config::Locator::from(locator.clone()).to_string());
                locators
            },
        );

        ZenohexScoutingHello {
            locators,
            whatami: hello.whatami().into(),
            zid: hello.zid().to_string(),
        }
    }
}

struct ScoutResource(RwLock<Option<zenoh::scouting::Scout<()>>>);

#[rustler::resource_impl]
impl rustler::Resource for ScoutResource {}

impl Deref for ScoutResource {
    type Target = RwLock<Option<zenoh::scouting::Scout<()>>>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl Drop for ScoutResource {
    fn drop(&mut self) {
        let mut scout_option = self.write().unwrap();
        match scout_option.take() {
            Some(scout) => scout.stop(),
            None => log::debug!("scout already stopped"),
        }
    }
}

impl ScoutResource {
    fn new(scout: zenoh::scouting::Scout<()>) -> ScoutResource {
        ScoutResource(RwLock::new(Some(scout)))
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn scouting_scout(
    what: crate::config::WhatAmI,
    json5_binary: &str,
    timeout: u64,
) -> rustler::NifResult<(rustler::Atom, Vec<crate::scouting::ZenohexScoutingHello>)> {
    let config = zenoh::Config::from_json5(json5_binary)
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    let scout = zenoh::scout(zenoh::config::WhatAmI::from(what), config)
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    let deadline = Instant::now() + Duration::from_millis(timeout);
    let mut hellos = Vec::new();

    loop {
        // NOTE: `recv_deadline` document says following,
        //       > If the deadline has expired, this will return None.
        let option_hello = scout
            .recv_deadline(deadline)
            .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

        let Some(hello) = option_hello else {
            // the deadline has expired
            return Err(rustler::Error::Term(Box::new("timeout")));
        };

        hellos.push(crate::scouting::ZenohexScoutingHello::from(hello));

        if scout.is_empty() {
            break;
        }
    }

    Ok((rustler::types::atom::ok(), hellos))
}

#[rustler::nif]
fn scouting_declare_scout(
    what: crate::config::WhatAmI,
    json5_binary: &str,
    // WHY: Pass `pid` instead of using `env.pid()`
    //      so the user can specify any receiver process
    pid: rustler::LocalPid,
) -> rustler::NifResult<(rustler::Atom, rustler::ResourceArc<ScoutResource>)> {
    let config = zenoh::Config::from_json5(json5_binary)
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    let scout = zenoh::scout(zenoh::config::WhatAmI::from(what), config)
        .callback(move |hello| {
            // WHY: Spawn a thread inside this callback.
            //      If we don't spawn a thread, a panic will occur.
            //      See: https://docs.rs/rustler/latest/rustler/env/struct.OwnedEnv.html#panics
            std::thread::spawn(move || {
                let _ = rustler::OwnedEnv::new()
                    .run(|env: rustler::Env| env.send(&pid, ZenohexScoutingHello::from(hello)));
            });
        })
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(ScoutResource::new(scout)),
    ))
}

#[rustler::nif]
fn scouting_stop_scout(
    scout: rustler::ResourceArc<ScoutResource>,
) -> rustler::NifResult<rustler::Atom> {
    let scout_option = &mut scout.write().unwrap();
    match scout_option.take() {
        Some(scout) => {
            scout.stop();
            Ok(rustler::types::atom::ok())
        }
        None => Err(rustler::Error::Term(Box::new("already stopped"))),
    }
}
