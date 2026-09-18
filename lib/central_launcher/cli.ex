defmodule CentralLauncher.CLI do
  @moduledoc "install, launch and update — the three verbs the launcher exists for."

  def main(argv \\ []) do
    argv |> run() |> report()
  end

  defp run(["install" | _]), do: install()
  defp run(["launch" | _]), do: launch()
  defp run(["update", index, dest, seed, store]),
    do: CentralLauncher.Update.fetch(index, dest, seed, store)
  defp run(["version" | _]), do: {:ok, Application.spec(:central_launcher, :vsn)}
  defp run(_argv), do: {:ok, usage()}

  # Burrito self-extracts before this runs, so install is a check that every
  # staged child is present rather than an unpacking step of its own.
  defp install do
    mode = CentralLauncher.Mode.current()

    missing =
      for name <- CentralLauncher.Mode.children(mode),
          match?({:error, _}, CentralLauncher.PrivBinary.path(:central_launcher, name)),
          do: name

    case missing do
      [] -> {:ok, "installed (#{mode})"}
      names -> {:error, {:missing, names}}
    end
  end

  defp launch do
    mode = CentralLauncher.Mode.current()

    started =
      Enum.reduce_while(CentralLauncher.Mode.children(mode), [], fn name, acc ->
        spec = child_spec(name)

        case Supervisor.start_child(CentralLauncher.Supervisor, spec) do
          {:ok, pid} -> {:cont, [{name, pid} | acc]}
          {:error, reason} -> {:halt, {:error, {name, reason}}}
        end
      end)

    case started do
      {:error, reason} -> {:error, reason}
      started -> confirm(Enum.reverse(started), mode)
    end
  end

  # `start_child` returns `{:ok, pid}` the moment the port opens, which a child
  # that exits immediately also satisfies. Comparing the pid rather than mere
  # liveness is what separates a running child from one crash-looping under a
  # supervisor that keeps handing back a fresh pid.
  @settle_ms 500
  @settle_polls 24

  defp confirm(started, mode) do
    bad = watch(started, @settle_polls, [])

    case bad do
      [] -> {:supervise, "launched #{mode}: #{names(started)}"}
      bad -> {:error, {:children_not_running, Enum.uniq(bad)}}
    end
  end

  # A single settle-then-look is a proxy: a crash-looping child is alive
  # between restarts and reads as running. Require the same pid across the
  # whole window instead, so a restart anywhere in it is a failure.
  defp watch(_started, 0, bad), do: bad

  defp watch(started, polls, bad) do
    Process.sleep(@settle_ms)
    now = for {name, pid} <- started, not holding?(name, pid), do: name
    watch(started, polls - 1, bad ++ now)
  end

  defp names(started), do: started |> Enum.map(&elem(&1, 0)) |> Enum.join(", ")

  defp holding?(name, pid) do
    Process.whereis(:"child_#{name}") == pid and Process.alive?(pid)
  end

  defp child_spec(name) do
    Supervisor.child_spec(
      {CentralLauncher.PrivBinary,
       app: :central_launcher,
       binary: name,
       name: :"child_#{name}",
       args: CentralLauncher.Runtime.args(name),
       env: CentralLauncher.Runtime.env(name)},
      id: name
    )
  end

  defp usage do
    "central-launcher install | launch | update <index> <dest> <seed> <store> | version"
  end

  # Halting is load-bearing: Burrito boots with `-s elixir start_cli`, which
  # reads the first plain argument as a script to run. Exiting first is what
  # stops `install` being looked up as a filename.
  defp report({:ok, message}) do
    IO.puts(to_string(message))
    System.halt(0)
  end

  # launch does not halt: the children are supervised by this VM, so exiting
  # would take them with it.
  defp report({:supervise, message}) do
    IO.puts(to_string(message))
    CentralLauncher.Signal.install()
    Process.sleep(:infinity)
  end

  # Children already started before the failure are torn down first: halting
  # straight away leaves them running with no launcher to supervise them.
  defp report({:error, reason}) do
    IO.puts(:stderr, "central-launcher: #{inspect(reason)}")

    case Process.whereis(CentralLauncher.Supervisor) do
      pid when is_pid(pid) -> Supervisor.stop(CentralLauncher.Supervisor, :shutdown)
      _ -> :ok
    end

    System.halt(1)
  end
end
