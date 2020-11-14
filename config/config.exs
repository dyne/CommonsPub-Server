# SPDX-License-Identifier: AGPL-3.0-only
import Config

alias CommonsPub.{
  Blocks,
  Collections,
  Communities,
  Features,
  Feeds,
  Flags,
  Follows,
  Instance,
  Likes,
  Resources,
  Threads,
  Users,
  Uploads
}

alias CommonsPub.Blocks.Block
alias CommonsPub.Collections.Collection
alias CommonsPub.Communities.Community
alias CommonsPub.Flags.Flag
alias CommonsPub.Likes.Like
alias CommonsPub.Resources.Resource
alias CommonsPub.Threads.{Comment, Thread}
alias CommonsPub.Users.User

alias CommonsPub.Feeds.{FeedActivities, FeedSubscriptions}

alias Measurement.Unit.Units
alias CommonsPub.Tag.Taggable

alias CommonsPub.Workers.GarbageCollector

fallback_env = fn a, b, c -> System.get_env(a) || System.get_env(b) || c end

desc = System.get_env("INSTANCE_DESCRIPTION", "An instance of CommonsPub, a federated app ecosystem for open and cooperative networks")
hostname = System.get_env("HOSTNAME", "localhost")
base_url = System.get_env("BASE_URL", "http://localhost:4000")
signing_salt = System.get_env("SIGNING_SALT", "CqAoopA2")



# stuff you might need to change to be viable

config :commons_pub, :app_name, System.get_env("APP_NAME", "CommonsPub")

config :commons_pub,
       :frontend_base_url,
       System.get_env("FRONTEND_BASE_URL", base_url)

config :commons_pub, CommonsPub.Web.Gettext, default_locale: "en", locales: ~w(en es)

# stuff you might want to change for your use case

# LiveView support: https://hexdocs.pm/phoenix_live_view/installation.html
config :commons_pub, :signing_salt, signing_salt
config :commons_pub, CommonsPub.Web.Endpoint,
  live_view: [
    signing_salt: signing_salt
  ]

types_agents = [
  User,
  Organisation
]

types_characters =
  types_agents ++
    [
      Community,
      Collection,
      Geolocation,
      CommonsPub.Tag.Category
    ]

types_inventory = [
  CommonsPub.Threads.Thread,
  CommonsPub.Threads.Comment,
  CommonsPub.Resources.Resource,
  Measurement.Unit,
  CommonsPub.Tag.Category,
  ValueFlows.Planning.Intent,
  ValueFlows.Proposal,
  ValueFlows.Observation.EconomicEvent,
  ValueFlows.Observation.EconomicResource,
  ValueFlows.Observation.Process,
  ValueFlows.Knowledge.ProcessSpecification,
  ValueFlows.Knowledge.ResourceSpecification
]

types_actions = [
  CommonsPub.Likes.Like,
  CommonsPub.Blocks.Block,
  CommonsPub.Flags.Flag,
  CommonsPub.Follows.Follow,
  Features.Feature
]

types_others = [
  Instance,
  Uploads.Upload,
  Measurement.Measure,
  CommonsPub.Tag.Taggable,
  CommonsPub.Activities.Activity,
  CommonsPub.Feeds.Feed,
  CommonsPub.Peers.Peer,
  CommonsPub.Access.RegisterEmailDomainAccess,
  CommonsPub.Access.RegisterEmailAccess
]

types_all_contexts = types_characters ++ types_inventory
types_all = types_all_contexts ++ types_actions ++ types_others

# configure which modules will receive which ActivityPub activities/objects

actor_modules = %{
  "Person" => CommonsPub.Users,
  "Group" => CommonsPub.Communities,
  "MN:Collection" => CommonsPub.Collections,
  "Organization" => CommonsPub.Organisations,
  "Application" => CommonsPub.Characters,
  "Service" => CommonsPub.Characters,
  fallback: CommonsPub.Characters
}

activity_modules = %{
  "Follow" => CommonsPub.Follows,
  "Like" => CommonsPub.Likes,
  "Flag" => CommonsPub.Flags,
  "Block" => CommonsPub.Blocks,
  "Delete" => CommonsPub.Common.Deletion,
  fallback: CommonsPub.Activities
}

inventory_modules = %{
  "Note" => CommonsPub.Threads.Comments,
  "Article" => CommonsPub.Threads.Comments,
  "Question" => CommonsPub.Threads.Comments,
  "Answer" => CommonsPub.Threads.Comments,
  "Document" => CommonsPub.Resources,
  "Page" => CommonsPub.Resources,
  "Video" => CommonsPub.Resources,
  fallback: CommonsPub.Threads.Comments
}

object_modules =
  Map.merge(inventory_modules, %{
    "Follow" => CommonsPub.Follows,
    "Like" => CommonsPub.Likes,
    "Flag" => CommonsPub.Flags,
    "Block" => CommonsPub.Blocks
  })

actor_types = Map.keys(actor_modules)
activity_types = Map.keys(activity_modules) ++ ["Create", "Update", "Accept", "Announce", "Undo"]
inventory_types = Map.keys(inventory_modules)
object_types = Map.keys(object_modules)
all_types = actor_types ++ activity_types ++ inventory_types ++ object_types

config :commons_pub, CommonsPub.ActivityPub.Adapter,
  actor_modules: actor_modules,
  actor_types: actor_types,
  activity_modules: activity_modules,
  activity_types: activity_types,
  object_modules: object_modules,
  inventory_types: inventory_types,
  object_types: object_types,
  all_types: all_types

config :commons_pub, Instance,
  hostname: hostname,
  description: desc,
  # what to show or exclude in Instance Timeline
  default_outbox_query_contexts: List.delete(types_all_contexts, Like),
  types_characters: types_characters,
  types_inventory: types_inventory,
  types_actions: types_actions,
  types_all: types_all

# config :commons_pub, User, # extend schema with Flexto
#    has_many: [
#     intents: {ValueFlows.Planning.Intent, foreign_key: :provider_id}   # has_many :bar, Bar, foreign_key: :the_bar_id
#   ]

config :commons_pub, Users,
  public_registration: false,
  default_outbox_query_contexts: types_all_contexts,
  default_inbox_query_contexts: types_all_contexts

config :commons_pub, Communities,
  valid_contexts: types_characters,
  default_outbox_query_contexts: types_all_contexts,
  default_inbox_query_contexts: types_all_contexts

config :commons_pub, Collections,
  valid_contexts: types_characters,
  default_outbox_query_contexts: types_all_contexts,
  default_inbox_query_contexts: types_all_contexts

config :commons_pub, Organisation, valid_contexts: types_characters

config :commons_pub, CommonsPub.Characters,
  valid_contexts: types_characters,
  default_outbox_query_contexts: types_all_contexts

config :commons_pub, Feeds,
  valid_contexts: types_characters,
  default_query_contexts: types_all_contexts

config :commons_pub, Blocks, valid_contexts: types_characters

config :commons_pub, Follows, valid_contexts: types_characters

config :commons_pub, Features, valid_contexts: types_all_contexts

config :commons_pub, Flags, valid_contexts: types_all_contexts

config :commons_pub, Likes, valid_contexts: types_all_contexts

config :commons_pub, Threads, valid_contexts: types_all_contexts

config :commons_pub, Resources, valid_contexts: types_all_contexts

config :commons_pub, Units, valid_contexts: types_all_contexts

config :commons_pub, ValueFlows.Proposal.Proposals, valid_agent_contexts: types_agents

image_media_types = ~w(image/png image/jpeg image/svg+xml image/gif)

config :commons_pub, Uploads.ResourceUploader,
  # App formats
  # Docs
  # Images
  # Audio
  # Video
  allowed_media_types:
    ~w(text/plain text/html text/markdown text/rtf text/csv) ++
      ~w(application/rtf application/pdf application/zip application/gzip) ++
      ~w(application/x-bittorrent application/x-tex) ++
      ~w(application/epub+zip application/vnd.amazon.mobi8-ebook) ++
      ~w(application/postscript application/msword) ++
      ~w(application/powerpoint application/mspowerpoint application/vnd.ms-powerpoint application/x-mspowerpoint) ++
      ~w(application/excel application/x-excel application/vnd.ms-excel) ++
      ~w(application/vnd.oasis.opendocument.chart application/vnd.oasis.opendocument.formula) ++
      ~w(application/vnd.oasis.opendocument.graphics application/vnd.oasis.opendocument.image) ++
      ~w(application/vnd.oasis.opendocument.presentation application/vnd.oasis.opendocument.spreadsheet) ++
      ~w(application/vnd.oasis.opendocument.text) ++
      image_media_types ++
      ~w(audio/mp3 audio/m4a audio/wav audio/flac audio/ogg) ++
      ~w(video/avi video/webm video/mp4)

config :commons_pub, Uploads.IconUploader, allowed_media_types: image_media_types

config :commons_pub, Uploads.ImageUploader, allowed_media_types: image_media_types

{:ok, cwd} = File.cwd()
uploads_dir = "/uploads"

config :commons_pub, Uploads,
  # default to 20mb
  max_file_size: "20000000",
  # the following should be overriden depending on env
  directory: cwd <> uploads_dir,
  path: uploads_dir,
  base_url: base_url <> uploads_dir <> "/"

config :commons_pub, GarbageCollector,
  # Contexts which require a mark phase, in execution order
  mark: [Uploads],
  # Contexts which need to perform maintainance, in execution order
  sweep: [
    Uploads,
    FeedActivities,
    FeedSubscriptions,
    Feeds,
    Features,
    Resources,
    Collections,
    Communities,
    Users,
    CommonsPub.Characters
  ],
  # We will not sweep content newer than this
  # one week
  grace: 302_400

# before compilation, replace this with the email deliver service adapter you want to use: https://github.com/thoughtbot/bamboo#available-adapters
# api_key: System.get_env("MAIL_KEY"), # use API key from runtime environment variable (make sure to set it on the server or CI config), and fallback to build-time env variable
# domain: System.get_env("MAIL_DOMAIN"), # use sending domain from runtime env, and fallback to build-time env variable
# config :commons_pub, CommonsPub.Mail.MailService,
#   adapter: Bamboo.MailgunAdapter

config :activity_pub, :mrf_simple,
  media_removal: [],
  media_nsfw: [],
  report_removal: [],
  accept: [],
  avatar_removal: [],
  banner_removal: []

config :commons_pub, Oban,
  repo: CommonsPub.Repo,
  # prune: {:maxlen, 100_000},
  poll_interval: 5_000,
  queues: [
    federator_incoming: 50,
    federator_outgoing: 50,
    ap_incoming: 10,
    mn_ap_publish: 30
  ]

config :commons_pub, :workers,
  retries: [
    federator_incoming: 5,
    federator_outgoing: 5
  ]

config :commons_pub, CommonsPub.MediaProxy,
  impl: CommonsPub.DirectHTTPMediaProxy,
  path: "/media/"

fallback_secret_key_base = "aK4Abxf29xU9TTDKre9coZPUgevcVCFQJe/5xP/7Lt4BEif6idBIbjupVbOrbKxl"

### Standin data for values you'll have to provide in the ENV in prod
config :commons_pub, CommonsPub.Web.Endpoint,
  url: [host: "localhost"],
  protocol: "https",
  secret_key_base:  System.get_env("SECRET_KEY_BASE", fallback_secret_key_base),
  render_errors: [view: CommonsPub.Web.ErrorView, accepts: ["json", "activity+json"]],
  pubsub_server: CommonsPub.PubSub,
  secure_cookie_flag: true

# config :activity_pub, ActivityPubWeb.Endpoint,
#     secret_key_base:  System.get_env("SECRET_KEY_BASE", fallback_secret_key_base)

version =
  with {version, 0} <- System.cmd("git", ["rev-parse", "HEAD"]) do
    "CommonsPub #{Mix.Project.config()[:version]} #{String.trim(version)}"
  else
    _ -> "CommonsPub #{Mix.Project.config()[:version]} dev"
  end


### Stuff you probably won't want to change

config :commons_pub, ecto_repos: [CommonsPub.Repo]

config :commons_pub, CommonsPub.Repo,
  types: Forkable.PostgresTypes,
  migration_primary_key: [name: :id, type: :binary_id],
  # the following are usually overidden depending on env
  username: fallback_env.("POSTGRES_USER", "DATABASE_USER", "postgres"),
  password: fallback_env.("POSTGRES_PASSWORD", "DATABASE_PASS", "postgres"),
  database: fallback_env.("POSTGRES_DB", "DATABASE_NAME", "commonspub"),
  hostname: fallback_env.("DATABASE_HOST", "POSTGRES_HOST", "localhost"),
  pool_size: 15

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

if Mix.env() == :dev do
  config :mix_test_watch,
    clear: true,
    tasks: [
      "test"
    ]
end

config :mime, :types, %{
  "application/activity+json" => ["json"],
  "application/ld+json" => ["json"],
  "application/jrd+json" => ["json"]
}

# transactional emails

mail_blackhole = fn var ->
  IO.puts(
    "WARNING: The environment variable #{var} was not set or was set incorrectly, mail will NOT be sent."
  )

  config :commons_pub, CommonsPub.Mail.MailService, adapter: Bamboo.LocalAdapter
end

mail_mailgun = fn ->
  # depends on whether you're registered with Mailgun in EU, US, etc
  base_uri = System.get_env("MAIL_BASE_URI", "https://api.mailgun.net/v3")

  case System.get_env("MAIL_KEY") do
    nil ->
      mail_blackhole.("MAIL_KEY")

    key ->
      case System.get_env("MAIL_DOMAIN") do
        nil ->
          mail_blackhole.("MAIL_DOMAIN")

        domain ->
          case System.get_env("MAIL_FROM") do
            nil ->
              mail_blackhole.("MAIL_FROM")

            from ->
              IO.puts("NOTE: Transactional emails will be sent through Mailgun.")

              config :commons_pub, CommonsPub.Mail.MailService,
                adapter: Bamboo.MailgunAdapter,
                api_key: key,
                base_uri: base_uri,
                domain: domain,
                reply_to: from
          end
      end
  end
end

mail_smtp = fn ->
  case System.get_env("MAIL_SERVER") do
    nil ->
      mail_blackhole.("MAIL_SERVER")

    server ->
      case System.get_env("MAIL_DOMAIN") do
        nil ->
          mail_blackhole.("MAIL_DOMAIN")

        domain ->
          case System.get_env("MAIL_USER") do
            nil ->
              mail_blackhole.("MAIL_USER")

            user ->
              case System.get_env("MAIL_PASSWORD") do
                nil ->
                  mail_blackhole.("MAIL_PASSWORD")

                password ->
                  case System.get_env("MAIL_FROM") do
                    nil ->
                      mail_blackhole.("MAIL_FROM")

                    from ->
                      IO.puts("NOTE: Transactional emails will be sent through SMTP.")

                      config :commons_pub, CommonsPub.Mail.MailService,
                        adapter: Bamboo.SMTPAdapter,
                        server: server,
                        hostname: domain,
                        port: 587,
                        username: user,
                        password: password,
                        tls: :always,
                        allowed_tls_versions: [:"tlsv1.2"],
                        ssl: false,
                        retries: 1,
                        auth: :always,
                        reply_to: from
                  end
              end
          end
      end
  end
end

case System.get_env("MAIL_BACKEND") do
  "mailgun" -> mail_mailgun.()
  "smtp" -> mail_smtp.()
  # mail_blackhole.("MAIL_BACKEND")
  _ -> mail_mailgun.()
end

config :argon2_elixir,
  # argon2id, see https://hexdocs.pm/argon2_elixir/Argon2.Stats.html
  argon2_type: 2

config :activity_pub, :instance,
  hostname: hostname,
  version: version,
  name: "CommonsPub",
  email: System.get_env("MAIL_FROM", "root@localhost"),
  description: desc,
  federation_publisher_modules: [ActivityPubWeb.Publisher],
  federation_reachability_timeout_days: 7,
  federating: true,
  rewrite_policy: [],
  supported_activity_types: activity_types,
  supported_actor_types: actor_types,
  supported_object_types: inventory_types

config :activity_pub, :repo, CommonsPub.Repo
config :activity_pub, adapter: CommonsPub.ActivityPub.Adapter
config :activity_pub, :endpoint, CommonsPub.Web.Endpoint
config :nodeinfo, adapter: CommonsPub.NodeinfoAdapter

# Configures http settings, upstream proxy etc.
config :activity_pub, :http,
  proxy_url: nil,
  send_user_agent: true,
  adapter: [
    ssl_options: [
      # Workaround for remote server certificate chain issues
      partial_chain: &:hackney_connect.partial_chain/1,
      # We don't support TLS v1.3 yet
      versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"]
    ]
  ]

config :phoenix, :format_encoders, json: Jason
config :phoenix, :json_library, Jason

config :furlex, Furlex.Oembed, oembed_host: "https://oembed.com"

config :tesla, adapter: Tesla.Adapter.Hackney

config :http_signatures, adapter: ActivityPub.Signature

config :floki, :html_parser, Floki.HTMLParser.Html5ever

config :sentry,
  enable_source_code_context: true,
  root_source_code_path: File.cwd!()

config :cortex,
  clear_before_running_tests: true,
  disabled: {:system, "CI_RUN", false}

env = Mix.env()
config :commons_pub, :env, env
IO.puts("Compiling with env #{env}")

config :pointers, Pointers.Pointer,
  source: "pointers_pointer",
  belongs_to: [
    character: {
      CommonsPub.Characters.Character,
      foreign_key: :id, define_field: false
    }
  ],
  belongs_to: [
    profile: {
      CommonsPub.Profiles.Profile,
      foreign_key: :id, define_field: false
    }
  ],
  many_to_many: [
    tags: {
      # if(CommonsPub.Config.module_enabled?(Taggable), do: Taggable, else: :taggable),
      Taggable,
      join_through: "tags_things",
      unique: true,
      join_keys: [pointer_id: :id, tag_id: :id],
      on_replace: :delete
    }
  ]

config :pointers, Pointers.Table, source: "pointers_table"

config :commons_pub, :ux,
  # prosemirror or ck5 as content editor:
  # editor: "prosemirror"
  editor: "ck5"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
