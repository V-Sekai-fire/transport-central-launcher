defmodule CentralLauncher.OTLPFile do
  @moduledoc "OpenTelemetry span exporter writing OTLP/JSON, one ResourceSpans per line."

  @behaviour :otel_exporter

  require Record

  Record.defrecordp(
    :span,
    Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl")
  )

  @impl true
  def init(opts) do
    if path = Keyword.get(opts, :path), do: put_path(path)
    {:ok, []}
  end

  @doc "Where spans are written. Read per export, so it can move after boot."
  def put_path(path) do
    File.mkdir_p(Path.dirname(path))
    :persistent_term.put({__MODULE__, :path}, path)
  end

  def path, do: :persistent_term.get({__MODULE__, :path}, default_path())

  # otel_exporter_traces calls export/3; the behaviour declares export/4.
  def export(table, resource, config), do: export(:traces, table, resource, config)

  @impl true
  def export(:traces, table, resource, _config) do
    spans = :ets.foldl(fn record, acc -> [encode(record) | acc] end, [], table)

    unless spans == [] do
      document = %{
        "resourceSpans" => [
          %{"resource" => resource(resource), "scopeSpans" => [%{"spans" => spans}]}
        ]
      }

      File.write(path(), [:json.encode(document), ?\n], [:append])
    end

    :ok
  end

  def export(_kind, _table, _resource, _config), do: :ok

  @impl true
  def shutdown(_config), do: :ok

  # OTLP/JSON carries ids as lowercase hex, and the spec's JSON mapping sends
  # 64-bit nanosecond timestamps as decimal strings so they survive a parser
  # that reads every number as a double.
  defp encode(record) do
    %{
      "traceId" => hex(span(record, :trace_id), 32),
      "spanId" => hex(span(record, :span_id), 16),
      "parentSpanId" => parent(span(record, :parent_span_id)),
      "name" => to_string(span(record, :name)),
      "kind" => kind(span(record, :kind)),
      "startTimeUnixNano" => nanos(span(record, :start_time)),
      "endTimeUnixNano" => nanos(span(record, :end_time)),
      "attributes" => attributes(span(record, :attributes)),
      "status" => status(span(record, :status))
    }
  end

  defp hex(id, width) when is_integer(id),
    do: id |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(width, "0")

  defp hex(_id, _width), do: ""

  defp parent(id) when is_integer(id), do: hex(id, 16)
  defp parent(_id), do: ""

  defp kind(:internal), do: 1
  defp kind(:server), do: 2
  defp kind(:client), do: 3
  defp kind(:producer), do: 4
  defp kind(:consumer), do: 5
  defp kind(_other), do: 0

  defp nanos(time) when is_integer(time),
    do: time |> :opentelemetry.convert_timestamp(:nanosecond) |> Integer.to_string()

  defp nanos(_time), do: "0"

  defp status({:status, code, message}),
    do: %{"code" => code(code), "message" => to_string(message)}

  defp status(_other), do: %{"code" => 0, "message" => ""}

  defp code(:ok), do: 1
  defp code(:error), do: 2
  defp code(_other), do: 0

  # otel_attributes is a record, so it arrives as a tuple rather than the map
  # its own accessor returns.
  defp attributes(attributes) when is_tuple(attributes) do
    attributes |> :otel_attributes.map() |> Enum.map(&attribute/1)
  end

  defp attributes(attributes) when is_map(attributes), do: Enum.map(attributes, &attribute/1)
  defp attributes(_other), do: []

  defp attribute({key, value}) do
    %{"key" => to_string(key), "value" => value(value)}
  end

  defp value(v) when is_boolean(v), do: %{"boolValue" => v}
  defp value(v) when is_integer(v), do: %{"intValue" => Integer.to_string(v)}
  defp value(v) when is_float(v), do: %{"doubleValue" => v}
  defp value(v), do: %{"stringValue" => to_string(v)}

  defp resource(resource) do
    %{"attributes" => resource |> :otel_resource.attributes() |> attributes()}
  end

  defp default_path do
    Path.join([System.user_home() || ".", ".central-launcher", "log", "traces.otlp.jsonl"])
  end
end
