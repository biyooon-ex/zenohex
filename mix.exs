defmodule Zenohex.MixProject do
  use Mix.Project
  @version "0.2.0-dev"

  def project do
    [
      app: :zenohex,
      version: @version,
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
      {:rustler_precompiled, "~> 0.7.1"},
      {:rustler, ">= 0.30.0", optional: true},
      {:ex_doc, "~> 0.31.0", only: :dev},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false}
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
