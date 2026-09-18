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
          {:ok, _pid} -> {:cont, [name | acc]}
          {:error, reason} -> {:halt, {:error, {name, reason}}}
        end
      end)

    case started do
      {:error, reason} -> {:error, reason}
      names -> {:supervise, "launched #{mode}: #{Enum.join(Enum.reverse(names), ", ")}"}
    end
  end

  defp child_spec(name) do
    Supervisor.child_spec(
      {CentralLauncher.PrivBinary, app: :central_launcher, binary: name, name: :"child_#{name}"},
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
    Process.sleep(:infinity)
  end

  defp report({:error, reason}) do
    IO.puts(:stderr, "central-launcher: #{inspect(reason)}")
    System.halt(1)
  end
end
