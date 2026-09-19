defmodule CentralLauncher.Runtime do
  @moduledoc """
  The per-child arguments and the on-disk state each one needs.

  A staged binary spawned bare is not a running service: `bao` prints usage and
  exits 127, and the host cannot find the engine. Arguments live here so the
  supervisor stays one mechanism.
  """

  # 4689 is FoundationDB's own default, so a desk with a system FDB install
  # already holds it. Standalone takes the next port rather than the default.
  @fdb_port 4700

  @doc "Root of the launcher's own state, created on demand."
  def root do
    dir = Path.join(System.user_home() || ".", ".central-launcher")
    File.mkdir_p!(dir)
    dir
  end

  defp sub(name) do
    dir = Path.join(root(), name)
    File.mkdir_p!(dir)
    dir
  end

  @doc "Arguments for one staged child, after writing whatever config it reads."
  def args("bao"), do: ["server", "-config=" <> bao_config()]

  def args("fdbserver") do
    ["-p", "127.0.0.1:#{@fdb_port}", "-d", sub("fdb/data"), "-L", sub("fdb/logs"), "-C", cluster_file()]
  end

  def args("versitygw"), do: ["--port", "127.0.0.1:7070", "posix", sub("s3")]

  def args("libgodot_host") do
    ["--libgodot", Path.join(priv(), libgodot()), "--headless"]
  end

  @doc "Environment a child needs, as charlist pairs for `Port.open/2`."
  def env("versitygw") do
    [{~c"ROOT_ACCESS_KEY", ~c"central"}, {~c"ROOT_SECRET_KEY", ~c"centrallauncher"}]
  end

  # The harness dlopens iceoryx2 by bare name, which finds nothing inside a
  # self-extracted release. Name the staged file outright.
  def env("libgodot_host") do
    [{~c"WEFT_ICEORYX2_PATH", to_charlist(Path.join(priv(), iceoryx2()))}]
  end

  def env(_name), do: []

  @doc "The engine library's filename on a given platform."
  def libgodot(os \\ :os.type())
  def libgodot({:win32, _}), do: "libgodot.dll"
  def libgodot(_os), do: "libgodot"

  @doc "The iceoryx2 library's filename on a given platform."
  def iceoryx2(os \\ :os.type())
  def iceoryx2({:unix, :darwin}), do: "libiceoryx2_ffi_c.dylib"
  def iceoryx2({:win32, _}), do: "iceoryx2_ffi_c.dll"
  def iceoryx2(_os), do: "libiceoryx2_ffi_c.so"

  defp priv, do: :code.priv_dir(:central_launcher) |> to_string()

  # A single-node file-backed seal. Standalone is a desk, CI and air-gapped
  # mode, so it stands up without a second machine to unseal against.
  defp bao_config do
    path = Path.join(root(), "bao.hcl")

    File.write!(path, """
    storage "file" { path = "#{sub("bao/data")}" }
    listener "tcp" {
      address     = "127.0.0.1:8200"
      tls_disable = true
    }
    disable_mlock = true
    api_addr      = "http://127.0.0.1:8200"
    """)

    path
  end

  defp cluster_file do
    path = Path.join(root(), "fdb.cluster")
    unless File.exists?(path), do: File.write!(path, "central:launcher@127.0.0.1:#{@fdb_port}\n")
    path
  end
end
