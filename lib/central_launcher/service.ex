defmodule CentralLauncher.Service do
  @moduledoc """
  Start the launcher with the user's session: a launchd agent on macOS, a
  systemd user unit on Linux, a logon scheduled task on Windows.

  Per-user only. A system service wants administrator on all three hosts, and
  these three mechanisms write inside the user's own home or task namespace,
  so `service install` never prompts for a password. Windows takes a task
  rather than an `sc.exe` service for that reason and because a console
  program that does not answer the control manager is killed at its timeout.
  """

  @label "com.v-sekai.central-launcher"
  @unit "central-launcher"

  @doc "Write the unit for this host and hand it to the session's service manager."
  def install(os \\ :os.type()) do
    with {:ok, bin} <- self_path() do
      do_install(os, bin)
    end
  end

  def uninstall(os \\ :os.type()), do: do_uninstall(os)

  def status(os \\ :os.type()), do: do_status(os)

  defp do_install({:unix, :darwin}, bin), do: darwin_install(bin)
  defp do_install({:win32, _}, bin), do: schtasks_install(bin)
  defp do_install(_os, bin), do: systemd_install(bin)

  defp do_uninstall({:unix, :darwin}), do: darwin_uninstall()
  defp do_uninstall({:win32, _}), do: schtasks_uninstall()
  defp do_uninstall(_os), do: systemd_uninstall()

  defp do_status({:unix, :darwin}), do: darwin_status()
  defp do_status({:win32, _}), do: schtasks_status()
  defp do_status(_os), do: systemd_status()

  # The zig wrapper exports the path of the binary the user actually ran. A
  # unit pointing at the extracted release instead would break on the next
  # update, which replaces the extract but not the binary.
  defp self_path do
    case System.get_env("__BURRITO_BIN_PATH") do
      nil -> {:error, :not_a_packaged_binary}
      path -> {:ok, path}
    end
  end

  defp log_dir do
    dir = Path.join(CentralLauncher.Runtime.root(), "log")
    File.mkdir_p(dir)
    dir
  end

  defp darwin_install(bin) do
    path = plist_path()

    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, plist(bin)),
         {_, 0} <- cmd("launchctl", ["bootstrap", domain(), path]) do
      {:ok, "service installed: #{path}"}
    else
      {out, code} when is_integer(code) -> {:error, {:launchctl, code, String.trim(out)}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp darwin_uninstall do
    cmd("launchctl", ["bootout", domain() <> "/" <> @label])

    case File.rm(plist_path()) do
      :ok -> {:ok, "service removed"}
      {:error, :enoent} -> {:ok, "service not installed"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp darwin_status do
    {out, code} = cmd("launchctl", ["print", domain() <> "/" <> @label])
    {:ok, "launchctl exit #{code}\n" <> out}
  end

  defp domain, do: "gui/#{uid()}"

  defp uid, do: System.cmd("id", ["-u"]) |> elem(0) |> String.trim()

  defp plist_path,
    do: Path.join([System.user_home() || ".", "Library/LaunchAgents", @label <> ".plist"])

  defp plist(bin) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key><string>#{@label}</string>
      <key>ProgramArguments</key>
      <array><string>#{bin}</string><string>launch</string></array>
      <key>RunAtLoad</key><true/>
      <key>KeepAlive</key><true/>
      <key>StandardOutPath</key><string>#{Path.join(log_dir(), "out.log")}</string>
      <key>StandardErrorPath</key><string>#{Path.join(log_dir(), "err.log")}</string>
    </dict>
    </plist>
    """
  end

  defp systemd_install(bin) do
    path = unit_path()

    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, unit(bin)),
         {_, 0} <- systemctl(["daemon-reload"]),
         {_, 0} <- systemctl(["enable", "--now", @unit]) do
      {:ok, "service installed: #{path}"}
    else
      {out, code} when is_integer(code) -> {:error, {:systemctl, code, String.trim(out)}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp systemd_uninstall do
    systemctl(["disable", "--now", @unit])

    case File.rm(unit_path()) do
      :ok ->
        systemctl(["daemon-reload"])
        {:ok, "service removed"}

      {:error, :enoent} ->
        {:ok, "service not installed"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp systemd_status do
    {out, code} = systemctl(["status", @unit, "--no-pager"])
    {:ok, "systemctl exit #{code}\n" <> out}
  end

  defp systemctl(args), do: cmd("systemctl", ["--user" | args])

  defp unit_path,
    do: Path.join([System.user_home() || ".", ".config/systemd/user", @unit <> ".service"])

  # Running without a login session additionally wants `loginctl enable-linger`,
  # which is the user's call rather than ours.
  defp unit(bin) do
    """
    [Unit]
    Description=V-Sekai central launcher
    After=network.target

    [Service]
    ExecStart=#{bin} launch
    Restart=always
    RestartSec=5

    [Install]
    WantedBy=default.target
    """
  end

  defp schtasks_install(bin) do
    args = ["/create", "/f", "/tn", @unit, "/tr", "\"#{bin}\" launch", "/sc", "onlogon"]

    case cmd("schtasks", args) do
      {_, 0} -> {:ok, "service installed: scheduled task #{@unit}"}
      {out, code} -> {:error, {:schtasks, code, String.trim(out)}}
    end
  end

  defp schtasks_uninstall do
    case cmd("schtasks", ["/delete", "/f", "/tn", @unit]) do
      {_, 0} -> {:ok, "service removed"}
      {out, code} -> {:error, {:schtasks, code, String.trim(out)}}
    end
  end

  defp schtasks_status do
    {out, code} = cmd("schtasks", ["/query", "/tn", @unit, "/v", "/fo", "list"])
    {:ok, "schtasks exit #{code}\n" <> out}
  end

  defp cmd(exe, args) do
    System.cmd(exe, args, stderr_to_stdout: true)
  rescue
    ErlangError -> {"#{exe} not found on PATH", 127}
  end
end
