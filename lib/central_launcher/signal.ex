defmodule CentralLauncher.Signal do
  @moduledoc """
  Tears the staged children down on SIGTERM.

  `launch` blocks inside the application start callback, so the application
  controller never finishes starting and the default `init:stop()` handler
  cannot run. Handling the signal here stops the supervisor directly, which is
  what gets each child's `terminate/2` called instead of leaving it orphaned.
  """
  @behaviour :gen_event

  def install do
    :os.set_signal(:sigterm, :handle)
    :gen_event.add_handler(:erl_signal_server, __MODULE__, [])
  end

  @impl true
  def init(_args), do: {:ok, %{}}

  @impl true
  def handle_event(:sigterm, state) do
    Supervisor.stop(CentralLauncher.Supervisor, :shutdown)
    System.halt(0)
    {:ok, state}
  end

  def handle_event(_event, state), do: {:ok, state}

  @impl true
  def handle_call(_request, state), do: {:ok, :ok, state}

  @impl true
  def handle_info(_message, state), do: {:ok, state}

  @impl true
  def terminate(_reason, _state), do: :ok
end
