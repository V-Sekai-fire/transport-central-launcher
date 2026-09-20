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
    path = Path.join(System.tmp_dir!(), "otlp-#{System.unique_integer([:positive])}.jsonl")
    Span.install(path)
    on_exit(fn -> File.rm(path) end)
    %{path: path}
  end

  defp spans(path) do
    Span.flush()
    Process.sleep(200)

    path
    |> File.read!()
    |> String.split("
",
      trim: true
    )
    |> Enum.map(&:json.decode/1)
    |> Enum.flat_map(fn d -> Enum.flat_map(d["resourceSpans"], & &1["scopeSpans"]) end)
    |> Enum.flat_map(& &1["spans"])
  end

  test "a span is exported as OTLP with hex ids of the standard width", %{path: path} do
    assert :done = Span.span("work", fn -> :done end)
    [s] = spans(path)
    assert s["name"] == "work"
    assert String.length(s["traceId"]) == 32
    assert String.length(s["spanId"]) == 16
    assert s["traceId"] =~ ~r/^[0-9a-f]{32}$/
  end

  test "a root span carries an empty parent, and a child names its parent", %{path: path} do
    Span.span("outer", fn -> Span.span("inner", fn -> :ok end) end)
    found = spans(path)
    outer = Enum.find(found, &(&1["name"] == "outer"))
    inner = Enum.find(found, &(&1["name"] == "inner"))
    assert outer["parentSpanId"] == ""
    assert inner["parentSpanId"] == outer["spanId"]
    assert inner["traceId"] == outer["traceId"]
  end

  test "an error result sets the OTLP error status code", %{path: path} do
    Span.span("bad", fn -> {:error, :nope} end)
    [s] = spans(path)
    assert s["status"]["code"] == 2
    assert s["status"]["message"] =~ "nope"
  end

  test "an ok result sets the OTLP ok status code", %{path: path} do
    Span.span("good", fn -> :ok end)
    [s] = spans(path)
    assert s["status"]["code"] == 1
  end

  test "attributes survive the encoding", %{path: path} do
    Span.span("child", %{"child" => "fdbserver"}, fn -> :ok end)
    [s] = spans(path)
    assert %{"key" => "child", "value" => %{"stringValue" => "fdbserver"}} in s["attributes"]
  end

  test "timestamps are decimal strings, as the JSON mapping requires", %{path: path} do
    Span.span("timed", fn -> :ok end)
    [s] = spans(path)
    assert is_binary(s["startTimeUnixNano"])
    assert {start, ""} = Integer.parse(s["startTimeUnixNano"])
    assert {finish, ""} = Integer.parse(s["endTimeUnixNano"])
    assert finish >= start
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
