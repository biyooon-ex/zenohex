defmodule Zenohex.MixProject do
  use Mix.Project

  @version "0.4.0"
  @source_url "https://github.com/biyooon-ex/zenohex"

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
      dialyzer: dialyzer()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Zenohex.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler_precompiled, "~> 0.8.2"},
      {:rustler, "== 0.36.2", optional: true},
      {:ex_doc, "~> 0.33", only: :dev},
      {:mix_test_watch, "~> 1.2", only: [:dev, :test], runtime: false},
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
        "lib/zenohex/nif",
        "lib/zenohex/*.ex",
        "native/zenohex_nif/.cargo",
        "native/zenohex_nif/src",
        "native/zenohex_nif/Cargo*",
        "native/zenohex_nif/rust-toolchain.toml",
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
      nest_modules_by_prefix: [
        Zenohex.Examples,
        Examples.Publisher,
        Examples.Subscriber,
        Examples.Queryable,
        Examples.LivelinessSubscriber,
        Examples.Scout,
        Zenohex.Examples.Plugins,
        Plugins.StorageBackendFs
      ],
      groups_for_modules: [
        Examples: [
          Zenohex.Examples.Publisher,
          Zenohex.Examples.Subscriber,
          Zenohex.Examples.Queryable,
          Zenohex.Examples.LivelinessSubscriber,
          Zenohex.Examples.Scout,
          Zenohex.Examples.Plugins.StorageBackendFs
        ]
      ]
    ]
  end

  defp test_coverage() do
    [
      ignore_modules: [
        Zenohex.Nif,
        ~r/Zenohex.Nif.Logger.*/,
        Zenohex.Examples.Plugins.StorageBackendFs
      ]
    ]
  end

  defp dialyzer() do
    [
      plt_file: {:no_warn, "priv/plts/project.plt"},
      plt_core_path: "priv/plts/core.plt"
    ]
  end
end
