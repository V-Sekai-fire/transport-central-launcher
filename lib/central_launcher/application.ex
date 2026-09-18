defmodule CentralLauncher.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    result = Supervisor.start_link([], strategy: :one_for_one, name: CentralLauncher.Supervisor)

    # Synchronously, not as a child: Burrito boots with `-s elixir start_cli`,
    # which exits before an async task would run, and reads the first plain
    # argument as a script to run if it gets there first.
    if burrito?(), do: CentralLauncher.CLI.main(argv())

    result
  end

  # The zig wrapper exports __BURRITO=1. Read it directly rather than through
  # Burrito.Util, whose module may not be loaded this early in boot.
  defp burrito?, do: System.get_env("__BURRITO") != nil

  defp argv, do: :init.get_plain_arguments() |> Enum.map(&to_string/1)
end
