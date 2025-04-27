mod config;
mod publisher;
mod session;
mod subscriber;

mod atoms {
    rustler::atoms! {
        zenohex_nif = "Elixir.Zenohex.Nif"
    }
}

fn load(_env: rustler::Env, _term: rustler::Term) -> bool {
    true
}

rustler::init!("Elixir.Zenohex.Nif", load = load);
