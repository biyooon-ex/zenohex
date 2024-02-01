defmodule Zenohex.MixProject do
  use Mix.Project

  @version "0.2.0-rc.1"
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
      # Docs
      name: "ZenohEx",
      source_url: @source_url,
      docs: docs(),
      aliases: [
        {:test, [&disable_zenoh_delay/1, "test"]},
        {:"test.watch", [&disable_zenoh_delay/1, "test.watch"]}
      ]
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
        "lib",
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
    [extras: ["README.md", "LICENSE"], main: "readme"]
  end

  defp disable_zenoh_delay(_args) do
    :ok =
      """
      =================================================================
      HEY, ZENOHEX DEVELOPER. TO REDUCE TESTING TIME,
      WE COMPILE WITH API_OPEN_SESSION_DELAY=0 AND SET SCOUTING DELAY 0
      =================================================================
      """
      |> String.trim_trailing()
      |> Mix.shell().info()

    :ok = System.put_env("API_OPEN_SESSION_DELAY", "0")
    :ok = System.put_env("SCOUTING_DELAY", "0")

    Mix.Task.run("compile", ["--force"])
  end
end
