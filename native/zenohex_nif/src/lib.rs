mod config;
mod publisher;
mod session;

fn load(_env: rustler::Env, _term: rustler::Term) -> bool {
    true
}

rustler::init!("Elixir.Zenohex.Nif", load = load);
