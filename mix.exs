defmodule Zenohex.MixProject do
  use Mix.Project

  def project do
    [
      app: :zenohex,
      version: "0.1.0",
      elixir: "~> 1.13",
      description: "Zenoh client library for elixir.",
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler, "~>0.26.0"},
      {:rustler_precompiled, "~> 0.6"},
      {:ex_doc, "~> 0.10", only: :dev}

      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp package() do
    [
      name: "zenohex",
      files: [
        "lib",
        "native/nifzenoh/.cargo",
        "native/nifzenoh/src",
        "native/nifzenoh/Cargo*",
        "checksum-*.exs",
        "mix.exs"
      ],
      maintainers: ["s-hosoai"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/b5g-ex/zenohex"}
    ]
  end
end
