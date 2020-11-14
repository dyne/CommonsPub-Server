# SPDX-License-Identifier: AGPL-3.0-only

defmodule CommonsPub.Web.Endpoint do
  @moduledoc """
  CommonsPub Phoenix Endpoint
  """
  use Phoenix.Endpoint, otp_app: :commons_pub

  @session_options [
    store: :cookie,
    key: "_session_key",
    signing_salt: CommonsPub.Config.get(:signing_salt)
  ]

  if is_binary(System.get_env("SENTRY_DSN")) and is_binary(System.get_env("SENTRY_ENV")) do
    use Sentry.Phoenix.Endpoint
  end

  # Liveview support
  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug(Plug.RequestId)
  plug(Plug.Logger)

  plug Plug.Session, @session_options

  plug(CommonsPub.Web.Plugs.Static)

  # Serve at "/" the static files from "priv/static" directory.
  # Liveview customization
  plug Plug.Static,
    at: "/",
    from: :commons_pub,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)

  {max_file_size, _} =
    :commons_pub
    |> Application.fetch_env!(CommonsPub.Uploads)
    |> Keyword.fetch!(:max_file_size)
    |> Integer.parse()

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason,
    body_reader: {CommonsPub.Web.Plugs.DigestPlug, :read_body, []},
    length: max_file_size

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(CORSPlug)
  plug(CommonsPub.Web.Router)

  @doc """
  Dynamically loads configuration from the system environment on startup.

  It receives the endpoint configuration from the config files and must return the updated configuration.
  """
  def load_from_system_env(config) do
    port = System.get_env("PORT") || raise "expected the PORT environment variable to be set"
    {:ok, Keyword.put(config, :http, [:inet6, port: port])}
  end
end
