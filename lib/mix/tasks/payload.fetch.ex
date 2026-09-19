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

  @impl Mix.Task
  def run(argv) do
    target = List.first(argv) || System.get_env("BURRITO_TARGET") || "macos_arm64"
    dir = Path.join("payload", target)
    File.mkdir_p!(dir)

    entries = "payload.exs" |> Code.eval_file() |> elem(0) |> Map.fetch!(target)
    {ours, upstream} = Enum.split_with(entries, &built_here?/1)

    Enum.each(upstream, &fetch(&1, dir))

    Mix.shell().info("built here, not fetched: #{names(ours)}")
    Mix.shell().info("fetched into #{dir}: #{names(upstream)}")
  end

  defp names(entries), do: entries |> Enum.map(& &1.name) |> Enum.join(", ")

  # A row naming a repository is built from that source; a row naming a file in
  # it is downloaded. Reading the owner instead said our own FoundationDB
  # release was built here, and the release failed on a file nobody fetched.
  defp built_here?(%{url: url}) do
    url |> URI.parse() |> Map.get(:path, "") |> to_string() |> Path.split() |> length() <= 3
  end

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
    executable!(dest)
  end

  # A wrong URL answers with a web page rather than an error, and a staged HTML
  # file reads exactly like a staged binary until something tries to run it.
  # One entry pointed at a repository rather than a release and produced a
  # 532 KB page that got as far as the release.
  defp executable!(path) do
    head = File.open!(path, [:read, :binary], &IO.binread(&1, 4))

    if known?(head) do
      :ok
    else
      File.rm_rf!(path)

      Mix.raise("""
      #{path} is not an executable or library: it starts with #{inspect(head)}.
      The url in payload.exs most likely answers with a web page rather than the
      file. The staged copy has been removed.
      """)
    end
  end

  defp known?(<<0x7F, ?E, ?L, ?F>>), do: true
  defp known?(<<0xCF, 0xFA, 0xED, 0xFE>>), do: true
  defp known?(<<0xCE, 0xFA, 0xED, 0xFE>>), do: true
  defp known?(<<0xCA, 0xFE, 0xBA, 0xBE>>), do: true
  defp known?(<<0xBE, 0xBA, 0xFE, 0xCA>>), do: true
  defp known?(<<?M, ?Z, _, _>>), do: true
  defp known?(_head), do: false

  # A `.exe`, a bare binary and a `.so` arrive as themselves; everything else
  # is an archive whose `extract` path names the file inside it.
  defp unpack(archive, dir) do
    cond do
      String.ends_with?(archive, [".tar.gz", ".tgz"]) ->
        {_, 0} = System.cmd("tar", ["xzf", archive, "-C", dir])

      String.ends_with?(archive, ".zip") ->
        {_, 0} = System.cmd("unzip", ["-q", "-o", archive, "-d", dir])

      # FoundationDB ships macOS as an installer package, so the binaries sit
      # under each component's Payload rather than at the top of an archive.
      String.ends_with?(archive, ".pkg") ->
        out = Path.join(dir, "pkg")
        {_, 0} = System.cmd("pkgutil", ["--expand-full", archive, out])
        File.cp_r!(out, dir)

      true ->
        :ok
    end
  end
end
