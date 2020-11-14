defmodule CommonsPub.Workers.ObanLogger do
  require Logger

  def handle_event([:oban, :job, :exception], _timing, meta, nil) do

    Logger.error(
      "[#{meta.queue}: #{meta.id}] #{meta.worker} job failed with #{inspect(meta.kind)}: #{
        Exception.format_banner(meta.kind, meta.error, meta.stacktrace)
      }"
    )

    for line <- meta.stacktrace do
      Logger.warn("[#{meta.queue}: #{meta.id}] #{inspect(line, pretty: true)}")
    end

    Sentry.Event.create_event(
      message: """
      #{meta.worker} Job failed.
      #{inspect(meta.error, pretty: true)}
      """,
      stacktrace: meta.stacktrace,
      event_source: meta.worker,
      extra: %{job: meta.id, args: meta.args, kind: meta.kind},
      level: :error
    )
    |> Sentry.send_event()
  end
end
