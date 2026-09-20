import Config

# The span exporter is chosen here rather than at first use: :opentelemetry
# reads its processors when it boots, and by then the CLI has not run.
config :opentelemetry,
  span_processor: :simple,
  traces_exporter: {CentralLauncher.OTLPFile, []}

config :opentelemetry, :resource,
  service: [name: "central-launcher", version: Mix.Project.config()[:version]]
