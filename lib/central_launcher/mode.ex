defmodule CentralLauncher.Mode do
  @moduledoc """
  One artifact, two modes. Standalone supervises its own store and secrets;
  attached uses the cluster and the real secrets service.

  Standalone is the default, so opening the binary on a desk works with no
  arguments. The server is the configured case, because a server has somewhere
  to put configuration and a desk does not.
  """

  @standalone ~w(fdbserver bao versitygw libgodot_host)
  @standalone_windows ~w(bao versitygw libgodot_host)
  @attached ~w(libgodot_host)

  @doc "`:standalone` unless a config file selects otherwise."
  def current(config_path \\ config_path()) do
    with true <- File.exists?(config_path),
         {:ok, body} <- File.read(config_path),
         %{"mode" => "attached"} <- decode(body) do
      :attached
    else
      _ -> :standalone
    end
  end

  @doc "The children this mode supervises, in start order."
  def children(:standalone), do: standalone()
  def children(:attached), do: @attached

  # FoundationDB publishes no Windows build of any kind, so standalone there
  # runs without a local cluster rather than staging a binary that cannot
  # exist. Attached mode is unaffected: it reaches a cluster over the network.
  defp standalone do
    case :os.type() do
      {:win32, _} -> @standalone_windows
      _ -> @standalone
    end
  end

  defp decode(body) do
    case :json.decode(body) do
      map when is_map(map) -> map
      _ -> %{}
    end
  end

  defp config_path do
    Path.join(System.user_home() || ".", ".central-launcher.json")
  end
end
