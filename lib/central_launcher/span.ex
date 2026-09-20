defmodule CentralLauncher.Span do
  @moduledoc "OpenTelemetry spans, exported to a file as OTLP/JSON."

  require OpenTelemetry.Tracer, as: Tracer

  def install(path \\ nil) do
    if path, do: CentralLauncher.OTLPFile.put_path(path)

    {:ok, _} = Application.ensure_all_started(:opentelemetry)
    :ok
  end

  def span(name, attributes \\ %{}, fun) do
    Tracer.with_span name, %{attributes: attributes} do
      result = fun.()

      case result do
        {:error, reason} -> Tracer.set_status(:error, inspect(reason))
        _ -> Tracer.set_status(:ok, "")
      end

      result
    end
  end

  def event(name, attributes \\ %{}), do: Tracer.add_event(name, attributes)

  def flush do
    :otel_simple_processor.force_flush(%{
      reg_name: :otel_simple_processor_global
    })
  end
end
