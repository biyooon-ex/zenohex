defmodule Zenohex.MixProject do
  use Mix.Project

  @version "0.2.0+zenoh-0.10.1-rc"
  @source_url "https://github.com/b5g-ex/zenohex"

  def project do
    [
      app: :zenohex,
      version: @version,
      elixir: "~> 1.13",
      description: "Zenoh client library for elixir.",
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      # Docs
      name: "Zenohex",
      source_url: @source_url,
      docs: docs(),
      test_coverage: test_coverage(),
      dialyzer: dialyzer(),
      aliases: [
        {:test, [&suggest/1, "test"]},
        {:"test.watch", [&suggest/1, "test.watch"]}
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler_precompiled, "~> 0.7.1"},
      {:rustler, ">= 0.31.0", optional: true},
      {:ex_doc, "~> 0.31.0", only: :dev},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:toml, "~> 0.7", runtime: false}
    ]
  end

  defp package() do
    [
      name: "zenohex",
      files: [
        "lib/zenohex.ex",
        "lib/zenohex/config",
        "lib/zenohex/*.ex",
        "native/zenohex_nif/.cargo",
        "native/zenohex_nif/src",
        "native/zenohex_nif/Cargo*",
        "LICENSE",
        "README.md",
        "checksum-*.exs",
        "mix.exs"
      ],
      maintainers: ["s-hosoai"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs() do
    [
      extras: ["README.md", "LICENSE"],
      main: "readme",
      groups_for_modules: [
        Configs: [
          Zenohex.Config,
          Zenohex.Config.Connect,
          Zenohex.Config.Scouting
        ],
        Options: [
          Zenohex.Publisher.Options,
          Zenohex.Query.Options,
          Zenohex.Queryable.Options,
          Zenohex.Subscriber.Options
        ]
      ]
    ]
  end

  defp test_coverage() do
    [
      ignore_modules: [Zenohex.Nif]
    ]
  end

  defp dialyzer() do
    [
      plt_file: {:no_warn, "priv/plts/project.plt"},
      plt_core_path: "priv/plts/core.plt"
    ]
  end

  defp suggest(_args) do
    if is_nil(System.get_env("API_OPEN_SESSION_DELAY")) do
      """
      ====================================================================
      HEY, ZENOHEX DEVELOPER. IF YOU WANNA REDUCE TEST TIME, DO FOLLOWINGS
      export API_OPEN_SESSION_DELAY=0 && mix compile --force
      ====================================================================
      """
      |> String.trim_trailing()
      |> Mix.shell().info()
    end

    if is_nil(System.get_env("SCOUTING_DELAY")) do
      """
      ====================================================================
      HEY, ZENOHEX DEVELOPER. IF YOU WANNA REDUCE TEST TIME,
      YOU CAN ADJUST SCOUTING DELAY, LIKE FOLLOWINGS
      SCOUTING_DELAY=30 mix test
      ====================================================================
      """
      |> String.trim_trailing()
      |> Mix.shell().info()
    end
  end
end
