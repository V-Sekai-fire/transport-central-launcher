defmodule CentralLauncher.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :central_launcher,
      version: @version,
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  def application do
    [extra_applications: [:logger, :inets, :ssl], mod: {CentralLauncher.Application, []}]
  end

  defp deps do
    [{:burrito, "~> 1.6", only: [:prod, :dev], runtime: false}]
  end

  # Native per target. libgodot is glibc-entangled through use_sowrap, so the
  # zig musl cross-build used elsewhere here does not transfer, and Burrito
  # cannot lay out a Windows ERTS from a non-Windows host.
  defp releases do
    [
      central_launcher: [
        steps: [:assemble, &stage_payload/1, &Burrito.wrap/1],
        burrito: [
          targets: [
            macos_arm64: [os: :darwin, cpu: :aarch64, custom_erts: erts()],
            linux_x86_64: [os: :linux, cpu: :x86_64, custom_erts: erts()],
            windows_amd64: [os: :windows, cpu: :x86_64]
          ],
          skip_nifs: true
        ]
      ]
    ]
  end

  defp erts, do: to_string(:code.root_dir())

  # A missing payload fails the build. fetch_env! and cp! are the failure: a
  # release that ships without its children still starts, and then cannot do
  # the one thing it exists for.
  defp stage_payload(%Mix.Release{} = release) do
    priv = Path.join(release.path, "lib/central_launcher-#{release.version}/priv")
    File.mkdir_p!(priv)

    for {var, name} <- payload() do
      File.cp!(System.fetch_env!(var), Path.join(priv, name))
    end

    release
  end

  # Every child the binary carries. fdbserver is standalone-only; the rest are
  # needed in both modes, so all of them must be staged for a release to build.
  defp payload do
    [
      {"LAUNCHER_LIBGODOT_HOST", "libgodot_host"},
      {"LAUNCHER_LIBGODOT", "libgodot"},
      {"LAUNCHER_ICEORYX2", "iceoryx2"},
      {"LAUNCHER_WEFT_SQL", "weft_sql"},
      {"LAUNCHER_LIBFDB_C", "libfdb_c"},
      {"LAUNCHER_FDBSERVER", "fdbserver"},
      {"LAUNCHER_BAO", "bao"},
      {"LAUNCHER_VERSITYGW", "versitygw"},
      {"LAUNCHER_DESYNC", "desync"}
    ]
  end
end
