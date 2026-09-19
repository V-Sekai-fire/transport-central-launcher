defmodule Mix.Tasks.Payload.Fetch do
  @moduledoc """
  Download the upstream half of a target's payload into `payload/<target>/`.

  Reads `payload.exs`, so the manifest that says where a child comes from is
  the same one the release stages from. Entries whose `url` points at one of
  our own repositories are built rather than downloaded and are skipped here;
  the build produces them and `stage_payload/1` fails if they are absent.
  """
  use Mix.Task

  @shortdoc "Fetch the upstream binaries for BURRITO_TARGET"
  @ours "github.com/V-Sekai-fire"

  @impl Mix.Task
  def run(argv) do
    target = List.first(argv) || System.get_env("BURRITO_TARGET") || "macos_arm64"
    dir = Path.join("payload", target)
    File.mkdir_p!(dir)

    entries = "payload.exs" |> Code.eval_file() |> elem(0) |> Map.fetch!(target)
    {ours, upstream} = Enum.split_with(entries, &String.contains?(&1.url, @ours))

    Enum.each(upstream, &fetch(&1, dir))

    Mix.shell().info("built here, not fetched: #{names(ours)}")
    Mix.shell().info("fetched into #{dir}: #{names(upstream)}")
  end

  defp names(entries), do: entries |> Enum.map(& &1.name) |> Enum.join(", ")

  defp fetch(%{name: name, url: url, extract: extract}, dir) do
    dest = Path.join(dir, name)
    Mix.shell().info("--> #{name} <- #{url}")
    tmp = Path.join(System.tmp_dir!(), "payload-#{name}")
    File.rm_rf!(tmp)
    File.mkdir_p!(tmp)

    archive = Path.join(tmp, Path.basename(URI.parse(url).path))
    {_, 0} = System.cmd("curl", ["-sSL", "-o", archive, url])

    unpack(archive, tmp)
    File.cp!(Path.join(tmp, extract), dest)
    File.chmod!(dest, 0o755)
    File.rm_rf!(tmp)
  end

  # A `.exe`, a bare binary and a `.so` arrive as themselves; everything else
  # is an archive whose `extract` path names the file inside it.
  defp unpack(archive, dir) do
    cond do
      String.ends_with?(archive, [".tar.gz", ".tgz"]) ->
        {_, 0} = System.cmd("tar", ["xzf", archive, "-C", dir])

      String.ends_with?(archive, ".zip") ->
        {_, 0} = System.cmd("unzip", ["-q", "-o", archive, "-d", dir])

      true ->
        :ok
    end
  end
end
