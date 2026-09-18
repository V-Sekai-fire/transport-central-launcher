defmodule CentralLauncher.CLI do
  @moduledoc "install, launch and update — the three verbs the launcher exists for."

  def main(argv \\ []) do
    argv |> run() |> report()
  end

  defp run(["install" | _]), do: install()
  defp run(["launch" | _]), do: launch()
  defp run(["update", index, dest, seed]), do: CentralLauncher.Update.fetch(index, dest, seed)
  defp run(["version" | _]), do: {:ok, Application.spec(:central_launcher, :vsn)}
  defp run(_argv), do: {:ok, usage()}

  # Burrito self-extracts before this runs, so install is a check that every
  # staged child is present rather than an unpacking step of its own.
  defp install do
    missing =
      for name <- ~w(libgodot_host libgodot),
          match?({:error, _}, CentralLauncher.PrivBinary.path(:central_launcher, name)),
          do: name

    case missing do
      [] -> {:ok, "installed"}
      names -> {:error, {:missing, names}}
    end
  end

  defp launch do
    spec = {CentralLauncher.PrivBinary, app: :central_launcher, binary: "libgodot_host"}

    case Supervisor.start_child(CentralLauncher.Supervisor, spec) do
      {:ok, _pid} -> {:ok, "launched"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp usage do
    "central-launcher install | launch | update <index> <dest> <seed> | version"
  end

  defp report({:ok, message}), do: IO.puts(to_string(message))

  defp report({:error, reason}) do
    IO.puts(:stderr, "central-launcher: #{inspect(reason)}")
    System.halt(1)
  end
end
