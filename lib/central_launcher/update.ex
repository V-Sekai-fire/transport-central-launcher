defmodule CentralLauncher.Update do
  @moduledoc """
  Moves between payload versions with desync: the payload is published as an
  index over a chunk store, and a client already holding version N fetches only
  the chunks N+1 adds. Nothing server-side computes a delta.
  """

  @doc """
  Fetch `index` into `dest`, reusing whatever `seed` already holds. Returns
  `{:ok, dest}` or `{:error, reason}`.
  """
  def fetch(index, dest, seed) do
    with {:ok, desync} <- CentralLauncher.PrivBinary.path(:central_launcher, "desync") do
      run(desync, ["extract", "--seed", seed, index, dest])
    end
  end

  defp run(exe, args) do
    case System.cmd(exe, args, stderr_to_stdout: true) do
      {_output, 0} -> {:ok, List.last(args)}
      {output, status} -> {:error, {:desync_failed, status, String.trim(output)}}
    end
  end
end
