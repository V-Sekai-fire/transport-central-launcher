defmodule CentralLauncher.MixProject do
  use Mix.Project

  @version "0.1.0"

  # Burrito fetches a prebuilt ERTS for the local OTP, and there is none for
  # 29.1. A Homebrew install is not relocatable, so name the 29.0 prebuilt
  # rather than bundling the desk's.
  @otp "29.1"
  @erts_base "https://beam-machine-universal.b-cdn.net/OTP-#{@otp}"
  @erts_ours "https://github.com/V-Sekai-fire/transport-central-launcher/releases/download/erts-29.1"
  @erts_macos "#{@erts_ours}/otp_29.1_macos_arm64.tar.gz"
  @erts_linux "#{@erts_base}/linux/x86_64/any/otp_#{@otp}_linux_any_x86_64.tar.gz"
  # OTP 29.1 has no prebuilt ERTS on beam-machine-universal — both the macOS
  # universal and the linux aarch64 URLs 404 — so these two are built from
  # source and published on this repository instead.
  @erts_linux_arm "#{@erts_ours}/otp_29.1_linux_any_aarch64.tar.gz"
  @erts_windows "https://github.com/erlang/otp/releases/download/OTP-#{@otp}/otp_win64_#{@otp}.exe"

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
    [
      {:burrito,
       github: "V-Sekai-fire/service-burrito",
       branch: "head/musl-for-custom-erts",
       only: [:prod, :dev],
       runtime: false}
    ]
  end

  # Native per target. libgodot is glibc-entangled through use_sowrap, so the
  # zig musl cross-build used elsewhere here does not transfer, and Burrito
  # cannot lay out a Windows ERTS from a non-Windows host.
  defp releases do
    [
      central_launcher: [
        rel_templates_path: "rel",
        steps: [:assemble, &stage_payload/1, &Burrito.wrap/1],
        burrito: [
          targets: [
            macos_arm64: [os: :darwin, cpu: :aarch64, custom_erts: @erts_macos],
            linux_x86_64: [os: :linux, cpu: :x86_64, custom_erts: @erts_linux],
            linux_arm64: [os: :linux, cpu: :aarch64, custom_erts: @erts_linux_arm],
            windows_amd64: [os: :windows, cpu: :x86_64, custom_erts: @erts_windows]
          ],
          skip_nifs: true
        ]
      ]
    ]
  end

  # A missing payload fails the build: fetch_env! and cp! are the failure, since
  # a release that ships without its children still starts and then cannot do
  # the one thing it exists for.
  defp stage_payload(%Mix.Release{} = release) do
    priv = Path.join(release.path, "lib/central_launcher-#{release.version}/priv")
    File.mkdir_p!(priv)

    for %{name: name} <- payload() do
      File.cp!(Path.join(payload_dir(), name), Path.join(priv, name))
    end

    release
  end

  # Declared in payload.exs, not in the environment: a variable is invisible to
  # the editor and gone the next time somebody builds.
  defp payload do
    "payload.exs" |> Code.eval_file() |> elem(0) |> Map.fetch!(target()) 
  end

  defp payload_dir, do: Path.join("payload", target())

  defp target, do: System.get_env("BURRITO_TARGET") || "macos_arm64"
end
