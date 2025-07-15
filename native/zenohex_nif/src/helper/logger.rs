use std::sync::mpsc;
use std::sync::Arc;
use std::sync::LazyLock;
use std::sync::RwLock;
use std::time::Duration;

pub static NIF_LOGGER: LazyLock<Arc<NifLogger>> = LazyLock::new(|| Arc::new(NifLogger::new()));

struct NifLoggerInner {
    enabled: bool,
    target: String,
    level: log::LevelFilter,
}

pub struct NifLogger {
    inner: RwLock<NifLoggerInner>,
}

impl NifLogger {
    fn new() -> NifLogger {
        let inner = RwLock::new(NifLoggerInner {
            enabled: false,
            target: String::from("zenohex_nif"),
            level: log::LevelFilter::Debug,
        });

        NifLogger { inner }
    }
    fn enable(&self) {
        let mut inner = self.inner.write().unwrap();
        inner.enabled = true;
    }

    fn disable(&self) {
        let mut inner = self.inner.write().unwrap();
        inner.enabled = false;
    }

    fn get_target(&self) -> String {
        let inner = self.inner.read().unwrap();
        inner.target.clone()
    }

    fn set_target(&self, target: String) {
        let mut inner = self.inner.write().unwrap();
        inner.target = target;
    }

    fn get_level(&self) -> log::LevelFilter {
        let inner = self.inner.read().unwrap();
        inner.level
    }

    fn set_level(&self, level: log::LevelFilter) {
        let mut inner = self.inner.write().unwrap();
        inner.level = level;
    }
}

impl log::Log for NifLogger {
    fn enabled(&self, metadata: &log::Metadata) -> bool {
        let inner = self.inner.read().unwrap();
        inner.enabled && metadata.target().starts_with(&inner.target)
    }

    fn log(&self, record: &log::Record) {
        if !self.enabled(record.metadata()) {
            return;
        }

        let message = if let Some(message) = record.args().as_str() {
            message
        } else {
            &record.args().to_string()
        };

        let message = format!("[{}] {}", record.target(), message);

        match record.level() {
            log::Level::Error => nif_logger_send(NifLoggerLevel::Error, message.as_ref()),
            log::Level::Warn => nif_logger_send(NifLoggerLevel::Warning, message.as_ref()),
            log::Level::Info => nif_logger_send(NifLoggerLevel::Info, message.as_ref()),
            log::Level::Debug => nif_logger_send(NifLoggerLevel::Debug, message.as_ref()),
            log::Level::Trace => unimplemented!(),
        }
    }

    fn flush(&self) {
        unimplemented!()
    }
}

#[derive(rustler::NifUnitEnum)]
enum NifLoggerLevel {
    Error,
    Warning,
    Info,
    Debug,
}

impl From<NifLoggerLevel> for log::LevelFilter {
    fn from(value: NifLoggerLevel) -> Self {
        match value {
            NifLoggerLevel::Error => log::LevelFilter::Error,
            NifLoggerLevel::Warning => log::LevelFilter::Warn,
            NifLoggerLevel::Info => log::LevelFilter::Info,
            NifLoggerLevel::Debug => log::LevelFilter::Debug,
        }
    }
}

type NifLoggerTuple = (NifLoggerLevel, String);
type NifLoggerSender = std::sync::mpsc::Sender<NifLoggerTuple>;
type NifLoggerReceiver = std::sync::mpsc::Receiver<NifLoggerTuple>;

static NIF_LOG_SENDER: LazyLock<RwLock<Option<NifLoggerSender>>> =
    LazyLock::new(|| RwLock::new(None));

#[rustler::nif]
fn nif_logger_init(
    pid: rustler::LocalPid,
    level: NifLoggerLevel,
) -> rustler::NifResult<rustler::Atom> {
    let mut sender = NIF_LOG_SENDER.write().unwrap();
    let (tx, rx): (NifLoggerSender, NifLoggerReceiver) = mpsc::channel();
    sender.replace(tx);

    let level = level.into();
    NIF_LOGGER.set_level(level);
    log::set_max_level(level);

    std::thread::spawn(move || {
        let owned_env = rustler::OwnedEnv::new();

        loop {
            // The Elixir process is no longer alive; exiting the thread.
            if owned_env.run(|env| !pid.is_alive(env)) {
                break;
            };

            let _ = match rx.recv_timeout(Duration::from_millis(100)) {
                Ok(message) => owned_env.run(|env| env.send(&pid, message)),
                Err(mpsc::RecvTimeoutError::Timeout) => continue,
                Err(mpsc::RecvTimeoutError::Disconnected) => break,
            };
        }
    });

    Ok(rustler::types::atom::ok())
}

#[rustler::nif]
fn nif_logger_enable() -> rustler::NifResult<rustler::Atom> {
    NIF_LOGGER.enable();
    Ok(rustler::types::atom::ok())
}

#[rustler::nif]
fn nif_logger_disable() -> rustler::NifResult<rustler::Atom> {
    NIF_LOGGER.disable();
    Ok(rustler::types::atom::ok())
}

#[rustler::nif]
fn nif_logger_get_target() -> rustler::NifResult<(rustler::Atom, String)> {
    let target = NIF_LOGGER.get_target();
    Ok((rustler::types::atom::ok(), target))
}

#[rustler::nif]
fn nif_logger_set_target(target: String) -> rustler::NifResult<rustler::Atom> {
    NIF_LOGGER.set_target(target);
    Ok(rustler::types::atom::ok())
}

#[rustler::nif]
fn nif_logger_get_level() -> rustler::NifResult<(rustler::Atom, NifLoggerLevel)> {
    let level = match NIF_LOGGER.get_level() {
        log::LevelFilter::Off => unimplemented!(),
        log::LevelFilter::Error => NifLoggerLevel::Error,
        log::LevelFilter::Warn => NifLoggerLevel::Warning,
        log::LevelFilter::Info => NifLoggerLevel::Info,
        log::LevelFilter::Debug => NifLoggerLevel::Debug,
        log::LevelFilter::Trace => unimplemented!(),
    };
    Ok((rustler::types::atom::ok(), level))
}

#[rustler::nif]
fn nif_logger_set_level(level: NifLoggerLevel) -> rustler::NifResult<rustler::Atom> {
    let level = level.into();
    NIF_LOGGER.set_level(level);
    log::set_max_level(level);
    Ok(rustler::types::atom::ok())
}

// This function is for testing purposes only.
#[rustler::nif]
fn nif_logger_log(level: NifLoggerLevel, message: &str) -> rustler::NifResult<rustler::Atom> {
    match level {
        NifLoggerLevel::Error => log::error!("{}", message),
        NifLoggerLevel::Warning => log::warn!("{}", message),
        NifLoggerLevel::Info => log::info!("{}", message),
        NifLoggerLevel::Debug => log::debug!("{}", message),
    };
    Ok(rustler::types::atom::ok())
}

fn nif_logger_send(level: NifLoggerLevel, message: &str) {
    let sender = NIF_LOG_SENDER.read().unwrap();
    if let Some(tx) = sender.as_ref() {
        match tx.send((level, message.to_string())) {
            Ok(_) => {}
            Err(_error) => {
                // The channel is closed; nothing more can be done.
            }
        }
    }
}
