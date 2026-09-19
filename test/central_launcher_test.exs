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
