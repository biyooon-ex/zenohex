defmodule Zenohex.VersionMatchTest do
  use ExUnit.Case

  defp tool_versions_map do
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
  end

  defp beam_versions_list do
    File.read!(".github/workflows/test.yml")
    |> String.split("\n")
    |> Enum.reduce({[], nil}, fn line, {pairs, current_otp} ->
      cond do
        String.contains?(line, "otp_version:") ->
          [_, version] = String.split(line, ":")
          {pairs, String.trim(version)}

        String.contains?(line, "elixir_version:") and current_otp != nil ->
          [_, version] = String.split(line, ":")
          pair = %{erlang: current_otp, elixir: String.trim(version)}
          {[pair | pairs], nil}

        true ->
          {pairs, current_otp}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  describe "Elixir/Erlang" do
    for filename <- [
          "code-analysis.yml",
          "release-automation.yml"
        ] do
      test "#{filename} version match" do
        ciyaml_versions_map =
          File.read!(".github/workflows/#{unquote(filename)}")
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

        assert tool_versions_map().erlang == ciyaml_versions_map.erlang
        assert tool_versions_map().elixir == ciyaml_versions_map.elixir
      end
    end

    test "test.yml includes current tool versions in beam matrix" do
      assert tool_versions_map() in beam_versions_list()
    end

    test "README version match" do
      readme_versions_map =
        File.read!("README.md")
        |> String.split("\n")
        |> Enum.reduce(%{}, fn line, acc ->
          cond do
            String.starts_with?(line, "- Elixir ") ->
              [_, version] = String.split(line, "- Elixir ")
              [elixir_version, "otp", _] = String.split(version, "-")
              Map.put(acc, :elixir, elixir_version)

            String.starts_with?(line, "- Erlang/OTP ") ->
              [_, version] = String.split(line, "- Erlang/OTP ")
              Map.put(acc, :erlang, version)

            true ->
              acc
          end
        end)

      assert tool_versions_map().erlang == readme_versions_map.erlang
      assert tool_versions_map().elixir == readme_versions_map.elixir
    end
  end

  describe "Rust" do
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

      rust_version_on_readme =
        File.read!("README.md")
        |> String.split("\n")
        |> Enum.find_value(fn line ->
          if String.starts_with?(line, "- Rust ") do
            [_, version] = String.split(line, "- Rust ")
            version
          end
        end)

      assert rust_version_on_yaml == rust_version_on_toml
      assert rust_version_on_readme == rust_version_on_toml
    end
  end
end
