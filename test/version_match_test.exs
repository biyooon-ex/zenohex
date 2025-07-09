defmodule Zenohex.VersionMatchTest do
  use ExUnit.Case

  describe "CI" do
    test "version match" do
      tool_versions_map =
        File.read!(".tool-versions")
        |> String.split("\n")
        |> Enum.reduce(%{}, fn line, acc ->
          cond do
            String.contains?(line, "erlang") ->
              [_, version] = String.split(line, " ")
              Map.put(acc, :erlang, version)

            String.contains?(line, "elixir") ->
              [_, version] = String.split(line, " ")
              [version, "otp", _] = String.split(version, "-")
              Map.put(acc, :elixir, version)

            true ->
              acc
          end
        end)

      ciyaml_versions_map =
        File.read!(".github/workflows/ci.yml")
        |> String.split("\n")
        |> Enum.reduce(%{}, fn line, acc ->
          cond do
            String.contains?(line, "OTP_VERSION: ") ->
              [_, version] = String.split(line, ": ")
              Map.put(acc, :erlang, version)

            String.contains?(line, "ELIXIR_VERSION: ") ->
              [_, version] = String.split(line, ": ")
              Map.put(acc, :elixir, version)

            true ->
              acc
          end
        end)

      assert tool_versions_map.erlang == ciyaml_versions_map.erlang
      assert tool_versions_map.elixir == ciyaml_versions_map.elixir
    end
  end

  describe "Elixir/Rust" do
    test "package version match" do
      version_on_mix_exs =
        Mix.Project.config()
        |> Keyword.fetch!(:version)

      version_on_cargo_toml =
        Toml.decode_file!("native/zenohex_nif/Cargo.toml")["package"]["version"]

      version_on_cargo_lock =
        Toml.decode_file!("native/zenohex_nif/Cargo.lock")["package"]
        |> Enum.filter(fn map -> map["name"] == "zenohex_nif" end)
        |> List.first()
        |> Map.get("version")

      assert version_on_mix_exs == version_on_cargo_toml
      assert version_on_mix_exs == version_on_cargo_lock
    end

    test "rust version match" do
      ["uses", "dtolnay/rust-toolchain", rust_version_on_yaml] =
        File.read!(".github/workflows/nif_precompile.yml")
        |> String.split("\n")
        |> Enum.filter(fn line -> String.contains?(line, "dtolnay/rust-toolchain@") end)
        |> List.first()
        |> String.split([":", "@"])
        |> Enum.map(&String.trim/1)

      rust_version_on_toml =
        Toml.decode_file!("native/zenohex_nif/rust-toolchain.toml")["toolchain"]["channel"]

      assert rust_version_on_yaml == rust_version_on_toml
    end
  end
end
