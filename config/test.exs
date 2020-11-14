# SPDX-License-Identifier: AGPL-3.0-only
import Config
# We don't necessarily run a server during test. If one is required,
# you can enable the server option below.
config :commons_pub, CommonsPub.Web.Endpoint,
  http: [port: 4001],
  server: true,
  check_origin: false

# Logging

config :logger, level: :notice
config :commons_pub, CommonsPub.Repo, log: :debug
config :commons_pub, :logging, tests_output_graphql: false # see queries and responses in GraphQL test output
config :commons_pub, :logging, tests_output_ap: false # see queries and responses in GraphQL test output

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Configure your database
config :commons_pub, CommonsPub.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  database: "commonspub_test",
  hostname: System.get_env("DATABASE_HOST", "localhost"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 25

# Reduce cost of hashing for testing
config :argon2_elixir,
  t_cost: 1,
  m_cost: 8

config :phoenix_integration,
  endpoint: CommonsPub.Web.Endpoint

config :commons_pub, CommonsPub.Mail.MailService, adapter: Bamboo.TestAdapter

config :commons_pub,
  base_url: "http://localhost:4001",
  ap_base_path: "/pub",
  frontend_base_url: "http://localhost:4001"

config :tesla, adapter: Tesla.Mock

config :commons_pub, CommonsPub.Mail.Checker, mx: false

config :commons_pub, CommonsPub.OAuth,
  client_name: "CommonsPub",
  client_id: "CommonsPUB",
  redirect_uri: "https://commonspub.dev.local/",
  website: "https://commonspub.dev.local/",
  scopes: "read,write,follow"

# Do not federate activities during tests
config :commons_pub, :instance, federating: false

# , prune: :disabled
config :commons_pub, Oban, queues: false

config :commons_pub, CommonsPub.Uploads,
  directory: File.cwd!() <> "/test_uploads",
  path: "/uploads",
  base_url: "http://localhost:4001/uploads/"
