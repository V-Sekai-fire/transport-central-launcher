defmodule CentralLauncherTest do
  use ExUnit.Case, async: true

  alias CentralLauncher.{Mode, Runtime}

  describe "the child set" do
    test "standalone supervises the store, the secrets and the engine" do
      assert Mode.children(:standalone) == ~w(fdbserver bao versitygw libgodot_host)
    end

    test "attached supervises the engine alone, because the cluster is elsewhere" do
      assert Mode.children(:attached) == ~w(libgodot_host)
    end

    test "every standalone child is named in the payload for every target" do
      payload = "payload.exs" |> Code.eval_file() |> elem(0)

      for {target, entries} <- payload do
        staged = MapSet.new(entries, &Path.rootname(&1.name, ".exe"))

        for child <- Mode.children(:standalone) do
          assert child in staged,
                 "#{target} stages no #{child}, which install would report missing"
        end
      end
    end
  end

  describe "child arguments" do
    test "bao is given a config, having printed its usage and exited 127 without one" do
      assert ["server", "-config=" <> path] = Runtime.args("bao")
      assert String.ends_with?(path, "bao.hcl")
    end

    test "fdbserver listens off FoundationDB's own default port" do
      args = Runtime.args("fdbserver")
      assert "-p" in args
      refute Enum.any?(args, &String.ends_with?(&1, ":4689"))
    end

    test "the host is told where the engine is, by a path and not a bare name" do
      args = Runtime.args("libgodot_host")
      assert "--libgodot" in args
      assert "--headless" in args
      [_, engine | _] = Enum.drop_while(args, &(&1 != "--libgodot"))
      assert Path.type(engine) == :absolute
    end
  end

  describe "the environment a child is given" do
    test "the host is pointed at iceoryx2 by an absolute path" do
      [{~c"WEFT_ICEORYX2_PATH", path}] = Runtime.env("libgodot_host")
      assert Path.type(to_string(path)) == :absolute
    end

    test "every platform gets its own library name, not the desk's" do
      assert Runtime.iceoryx2({:unix, :darwin}) == "libiceoryx2_ffi_c.dylib"
      assert Runtime.iceoryx2({:win32, :nt}) == "iceoryx2_ffi_c.dll"
      assert Runtime.iceoryx2({:unix, :linux}) == "libiceoryx2_ffi_c.so"
    end

    test "every platform gets its own engine name" do
      assert Runtime.libgodot({:win32, :nt}) == "libgodot.dll"
      assert Runtime.libgodot({:unix, :linux}) == "libgodot"
      assert Runtime.libgodot({:unix, :darwin}) == "libgodot"
    end

    test "versitygw is given root credentials, and nothing else is" do
      assert Runtime.env("versitygw") != []
      assert Runtime.env("fdbserver") == []
      assert Runtime.env("bao") == []
    end
  end

  describe "a staged binary" do
    test "is reported missing rather than assumed present" do
      assert {:error, _} = CentralLauncher.PrivBinary.path(:central_launcher, "no_such_child")
    end
  end
end

defmodule CentralLauncher.ServiceTest do
  use ExUnit.Case, async: true

  alias CentralLauncher.Service

  test "install refuses when not running as a packaged binary" do
    saved = System.get_env("__BURRITO_BIN_PATH")
    System.delete_env("__BURRITO_BIN_PATH")
    assert {:error, :not_a_packaged_binary} = Service.install({:unix, :darwin})
    if saved, do: System.put_env("__BURRITO_BIN_PATH", saved)
  end

  test "status reaches a different manager on each host" do
    assert {:ok, "launchctl exit" <> _} = Service.status({:unix, :darwin})
    assert {:ok, "systemctl exit" <> _} = Service.status({:unix, :linux})
    assert {:ok, "schtasks exit" <> _} = Service.status({:win32, :nt})
  end

  test "a manager missing from PATH is an exit code, never a crash" do
    assert {:ok, body} = Service.status({:win32, :nt})
    assert body =~ "exit"
  end
end

defmodule CentralLauncher.BundleTest do
  use ExUnit.Case, async: true

  test "a path inside an app bundle is bundled, a bare binary is not" do
    assert CentralLauncher.CLI.bundled?("/Applications/X.app/Contents/MacOS/central-launcher")
    refute CentralLauncher.CLI.bundled?("/usr/local/bin/central-launcher")
    refute CentralLauncher.CLI.bundled?(nil)
  end
end

defmodule CentralLauncher.SpanTest do
  use ExUnit.Case, async: false

  alias CentralLauncher.Span

  setup do
    path = Path.join(System.tmp_dir!(), "spans-#{System.unique_integer([:positive])}.jsonl")
    Span.install(path)
    on_exit(fn -> File.rm(path) end)
    %{path: path}
  end

  defp lines(path), do: path |> File.read!() |> String.split("\n", trim: true) |> Enum.map(&:json.decode/1)

  test "a span opens and closes, carrying its duration", %{path: path} do
    assert :done = Span.span("work", fn -> :done end)
    [open, close] = lines(path)
    assert open["name"] == "work" and open["at"] == "open"
    assert close["at"] == "close" and close["outcome"] == "ok"
    assert is_integer(close["us"])
    assert open["span"] == close["span"]
  end

  test "a root span has parent -1, never a null", %{path: path} do
    Span.span("root", fn -> :ok end)
    [open | _] = lines(path)
    assert open["parent"] == -1
  end

  test "a nested span names its parent", %{path: path} do
    Span.span("outer", fn -> Span.span("inner", fn -> :ok end) end)
    outer = lines(path) |> Enum.find(&(&1["name"] == "outer"))
    inner = lines(path) |> Enum.find(&(&1["name"] == "inner"))
    assert inner["parent"] == outer["span"]
  end

  test "an error result is recorded as an error outcome", %{path: path} do
    Span.span("bad", fn -> {:error, :nope} end)
    close = lines(path) |> Enum.find(&(&1["at"] == "close"))
    assert close["outcome"] == "error"
  end

  test "the stack unwinds, so a sibling is not nested under its predecessor", %{path: path} do
    Span.span("first", fn -> :ok end)
    Span.span("second", fn -> :ok end)
    second = lines(path) |> Enum.find(&(&1["name"] == "second"))
    assert second["parent"] == -1
  end
end

defmodule CentralLauncher.PayloadTest do
  use ExUnit.Case, async: true

  alias CentralLauncher.Payload

  @macho <<0xCF, 0xFA, 0xED, 0xFE, 0, 0, 0, 0>>
  @elf <<0x7F, "ELF", 2, 1, 1, 0>>
  @pe <<"MZ", 0, 0, 0, 0, 0, 0>>

  test "each magic names its operating system" do
    assert Payload.os_of(@macho) == :darwin
    assert Payload.os_of(@elf) == :linux
    assert Payload.os_of(@pe) == :windows
    assert Payload.os_of(<<"just data">>) == :unknown
  end

  test "the right binary for the target passes" do
    assert Payload.check(@macho, "macos_arm64") == :ok
    assert Payload.check(@elf, "linux_arm64") == :ok
    assert Payload.check(@pe, "windows_amd64") == :ok
  end

  # The control: this is the staging that shipped a Linux host to macOS.
  test "a linux binary staged for macos is a mismatch" do
    assert Payload.check(@elf, "macos_arm64") == {:mismatch, :linux, :darwin}
    assert Payload.check(@macho, "linux_x86_64") == {:mismatch, :darwin, :linux}
  end

  test "a data file is not a mismatch" do
    assert Payload.check(<<"cluster:file">>, "macos_arm64") == :ok
  end
end
