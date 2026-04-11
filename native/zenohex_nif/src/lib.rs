#[macro_export]
macro_rules! zenoh_error {
    ($error:expr) => {
        Box::new(format!(
            "native/zenohex_nif/{}:{}: {}",
            file!(),
            line!(),
            $error.to_string()
        ))
    };
}

mod builder;
mod config;
mod helper;
mod keyexpr;
mod liveliness;
mod matching;
mod publisher;
mod querier;
mod query;
mod queryable;
mod sample;
mod scouting;
mod session;
mod subscriber;

mod atoms {
    rustler::atoms! {
        accept_replies,
        attachment,
        history,
        allowed_destination,
        allowed_origin,
        complete,
        congestion_control,
        consolidation,
        encoding,
        express,
        is_final = "final?",
        parameters,
        payload,
        priority,
        query_timeout,
        target,
        timeout,
        unsupported_entity,
        timestamp,
        zenohex_nif = "Elixir.Zenohex.Nif",
    }
}

fn load(_env: rustler::Env, _term: rustler::Term) -> bool {
    // NOTE: `log::set_boxed_logger` must be called only once during the program's lifetime.
    log::set_boxed_logger(Box::new(helper::logger::NIF_LOGGER.clone())).unwrap();

    true
}

rustler::init!("Elixir.Zenohex.Nif", load = load);
