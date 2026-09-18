defmodule CentralLauncher.Update do
  @moduledoc """
  Moves between payload versions with desync: the payload is published as an
  index over a chunk store, and a client already holding version N reuses the
  chunks it has and fetches only the ones N+1 adds. Nothing server-side
  computes a delta, so one published copy serves every client whatever version
  it is coming from.
  """

  @doc """
  Fetch `index` into `dest`, taking what it can from `seed` and the rest from
  `store`. Returns `{:ok, dest}` or `{:error, reason}`.
  """
  def fetch(index, dest, seed, store) do
    with {:ok, desync} <- CentralLauncher.PrivBinary.path(:central_launcher, "desync") do
      run(desync, ["extract", "--store", store] ++ seed(seed) ++ [index, dest], dest)
    end
  end

  @doc "Fetch with no seed held — the first install, where every chunk is new."
  def fetch(index, dest, store), do: fetch(index, dest, nil, store)

  # desync takes the seed's index, not the payload; a client holding nothing
  # passes none rather than a path that has to exist.
  defp seed(nil), do: []
  defp seed(""), do: []
  defp seed(path), do: ["--seed", path]

  defp run(exe, args, dest) do
    case System.cmd(exe, args, stderr_to_stdout: true) do
      {_output, 0} -> {:ok, dest}
      {output, status} -> {:error, {:desync_failed, status, String.trim(output)}}
    end
  end
end
