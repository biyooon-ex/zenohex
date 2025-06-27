mod config;
mod helper;
mod publisher;
mod query;
mod queryable;
mod sample;
mod session;
mod subscriber;

mod atoms {
    rustler::atoms! {
        attachment,
        encoding,
        is_final = "final?",
        zenohex_nif = "Elixir.Zenohex.Nif",
    }
}

fn load(_env: rustler::Env, _term: rustler::Term) -> bool {
    true
}

rustler::init!("Elixir.Zenohex.Nif", load = load);
