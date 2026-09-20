defmodule CentralLauncher.Burrito.MacOSApp do
  @moduledoc "Burrito build step: wrap the macOS binary in an app bundle and a disk image."

  @behaviour Burrito.Builder.Step

  @bundle_id "com.v-sekai.central-launcher"

  @impl true
  def execute(%{target: %{os: :darwin}} = context) do
    out = Path.join(File.cwd!(), "burrito_out")
    bin = Path.join(out, "#{context.mix_release.name}_#{context.target.alias}")
    version = context.mix_release.version

    if File.exists?(bin) do
      app = Path.join(out, "Central Launcher.app")
      build(app, bin, version)
      image(app, out, context.target.alias)
      IO.puts("🍎 wrapped as #{app}")
    end

    context
  end

  def execute(context), do: context

  defp build(app, bin, version) do
    File.rm_rf!(app)
    File.mkdir_p!(Path.join(app, "Contents/MacOS"))
    File.mkdir_p!(Path.join(app, "Contents/Resources"))

    exe = Path.join(app, "Contents/MacOS/central-launcher-bin")
    File.cp!(bin, exe)
    File.chmod!(exe, 0o755)

    shim = Path.join(app, "Contents/MacOS/central-launcher")
    File.write!(shim, shim_script())
    File.chmod!(shim, 0o755)
    File.write!(Path.join(app, "Contents/Info.plist"), plist(version))

    # Ad-hoc signed for a valid seal; Gatekeeper still treats it as unsigned.
    System.cmd("codesign", ["--force", "--deep", "--sign", "-", app], stderr_to_stdout: true)
  end

  defp shim_script do
    """
    #!/bin/sh
    LOG="$HOME/.central-launcher/log"
    mkdir -p "$LOG"
    exec "$(dirname "$0")/central-launcher-bin" "$@" >>"$LOG/app.out.log" 2>>"$LOG/app.err.log"
    """
  end

  # LaunchServices rejects a prerelease suffix in CFBundleShortVersionString.
  defp plist(version) do
    short = version |> String.split("-") |> hd()

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleName</key><string>Central Launcher</string>
      <key>CFBundleDisplayName</key><string>Central Launcher</string>
      <key>CFBundleIdentifier</key><string>#{@bundle_id}</string>
      <key>CFBundleExecutable</key><string>central-launcher</string>
      <key>CFBundlePackageType</key><string>APPL</string>
      <key>CFBundleShortVersionString</key><string>#{short}</string>
      <key>CFBundleVersion</key><string>#{version}</string>
      <key>LSMinimumSystemVersion</key><string>13.0</string>
      <key>NSHighResolutionCapable</key><true/>
    </dict>
    </plist>
    """
  end

  # LZFSE rather than the default zlib: the workspace ships neither zip nor gzip.
  defp image(app, out, alias_name) do
    dmg = Path.join(out, "central-launcher-#{alias_name}.dmg")

    System.cmd(
      "hdiutil",
      [
        "create",
        "-quiet",
        "-volname",
        "Central Launcher",
        "-srcfolder",
        app,
        "-ov",
        "-format",
        "ULFO",
        dmg
      ],
      stderr_to_stdout: true
    )
  end
end
