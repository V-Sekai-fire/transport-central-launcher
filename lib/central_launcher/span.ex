defmodule CentralLauncher.Span do
  @moduledoc """
  Structured logging as spans: one JSON object per line.

  Opened from Finder the launcher has no stdout, so a failed launch has to say
  in a file which child it was starting. No nulls: a root span's parent is -1.
  """

  @behaviour :logger_handler

  @root -1

  def install(path \\ default_path()) do
    File.mkdir_p(Path.dirname(path))
    :persistent_term.put({__MODULE__, :path}, path)
    :logger.add_handler(:central_launcher_spans, __MODULE__, %{})
    :ok
  end

  @doc "Run `fun` inside a span, recording its duration and outcome."
  def span(name, fields \\ %{}, fun) do
    id = System.unique_integer([:positive, :monotonic])
    parent = current()
    started = System.monotonic_time(:microsecond)
    Process.put(__MODULE__, [id | stack()])
    emit(Map.merge(fields, %{"span" => id, "parent" => parent, "name" => name, "at" => "open"}))

    result = fun.()

    Process.put(__MODULE__, stack() |> tl())

    emit(%{
      "span" => id,
      "parent" => parent,
      "name" => name,
      "at" => "close",
      "us" => System.monotonic_time(:microsecond) - started,
      "outcome" => outcome(result)
    })

    result
  end

  def event(name, fields \\ %{}) do
    emit(Map.merge(fields, %{"span" => current(), "name" => name, "at" => "event"}))
  end

  defp outcome({:error, _}), do: "error"
  defp outcome(_), do: "ok"

  defp stack, do: Process.get(__MODULE__, [])

  defp current do
    case stack() do
      [id | _] -> id
      [] -> @root
    end
  end

  @impl true
  def log(%{level: level, msg: message, meta: meta}, _config) do
    emit(%{
      "span" => current(),
      "name" => "log",
      "at" => "event",
      "level" => to_string(level),
      "message" => text(message),
      "mfa" => inspect(Map.get(meta, :mfa, :none))
    })
  end

  defp text({:string, chars}), do: IO.chardata_to_string(chars)

  defp text({format, args}) when is_list(format),
    do: format |> :io_lib.format(args) |> to_string()

  defp text({:report, report}), do: inspect(report)
  defp text(other), do: inspect(other)

  defp emit(record) do
    line = [:json.encode(Map.put(record, "t", System.system_time(:microsecond))), ?\n]
    File.write(path(), line, [:append])
  end

  defp path, do: :persistent_term.get({__MODULE__, :path}, default_path())

  defp default_path do
    Path.join([System.user_home() || ".", ".central-launcher", "log", "spans.jsonl"])
  end
end
