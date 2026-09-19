defmodule CentralLauncher.PrivBinary do
  @moduledoc """
  Supervises one executable that ships inside the release's `priv/`.

  Generalised from `versitygw_local`, which already resolves `:code.priv_dir/1`,
  spawns through `Port.open/2` and tears down per platform. One mechanism for
  every staged child, so startup order and health live in one place.
  """
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @doc "Absolute path of a staged executable, or `{:error, :not_staged}`."
  def path(app, name) do
    case :code.priv_dir(app) do
      {:error, _} -> {:error, :no_priv_dir}
      dir -> exists(Path.join(dir, executable(name)))
    end
  end

  defp exists(path) do
    if File.exists?(path), do: {:ok, path}, else: {:error, :not_staged}
  end

  defp executable(name) do
    case :os.type() do
      {:win32, _} -> name <> ".exe"
      _ -> name
    end
  end

  @impl true
  def init(opts) do
    app = Keyword.fetch!(opts, :app)
    name = Keyword.fetch!(opts, :binary)

    # Without trapping, `terminate/2` never runs and every staged child
    # outlives the launcher as an orphan.
    Process.flag(:trap_exit, true)

    case path(app, name) do
      {:ok, exe} -> {:ok, open(exe, Keyword.get(opts, :args, []), Keyword.get(opts, :env, []))}
      {:error, reason} -> {:stop, {:missing_binary, name, reason}}
    end
  end

  defp open(exe, args, env) do
    port = Port.open({:spawn_executable, exe}, [:binary, :exit_status, args: args, env: env])
    %{port: port, exe: exe, os_pid: os_pid(port)}
  end

  defp os_pid(port) do
    case Port.info(port, :os_pid) do
      {:os_pid, pid} -> pid
      _ -> :unknown
    end
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.warning("#{Path.basename(state.exe)} exited with #{status}")
    {:stop, {:child_exited, status}, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, %{os_pid: os_pid}) when is_integer(os_pid) do
    case :os.type() do
      {:win32, _} -> System.cmd("taskkill", ["/PID", to_string(os_pid), "/T", "/F"])
      _ -> terminate_unix(to_string(os_pid))
    end

    :ok
  end

  def terminate(_reason, _state), do: :ok

  # libgodot_host ignores SIGTERM while in the command loop, so a plain kill
  # leaves the engine running after the launcher exits.
  defp terminate_unix(pid) do
    System.cmd("kill", [pid])
    Process.sleep(2_000)

    case System.cmd("kill", ["-0", pid], stderr_to_stdout: true) do
      {_out, 0} -> System.cmd("kill", ["-9", pid])
      _ -> {"", 0}
    end
  end
end
