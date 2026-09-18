defmodule CentralLauncher.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link(children(), strategy: :one_for_one, name: CentralLauncher.Supervisor)
  end

  # The launcher starts no children on its own. `launch` adds them, so opening
  # the binary to run `install` or `update` does not start an engine.
  defp children, do: []
end
