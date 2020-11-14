# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.Router do
  @moduledoc """
  CommonsPub Router
  """
  import Phoenix.LiveView.Router

  use CommonsPub.Web, :router
  use Plug.ErrorHandler
  use Sentry.Plug
  use ActivityPubWeb.Router
  use NodeinfoWeb.Router

  if Mix.env() == :dev do
    forward "/sent_emails", Bamboo.SentEmailViewerPlug
  end

  pipeline :ensure_authenticated do
    plug(CommonsPub.Web.Plugs.EnsureAuthenticatedPlug)
  end

  pipeline :ensure_admin do
    plug(CommonsPub.Web.Plugs.EnsureAdminPlug)
  end

  @doc """
  General pipeline for webpage requests
  """
  pipeline :browser do
    plug :accepts, ["html", "json", "css", "js"]
    plug :put_root_layout, {CommonsPub.Web.LayoutView, :root}
    plug :put_secure_browser_headers
    plug :fetch_session
    plug CommonsPub.Web.Plugs.Auth
    plug CommonsPub.Web.Plugs.SetLocale
  end

  @doc """
  Used to serve the GraphiQL API browser
  """
  pipeline :graphiql do
    plug(:fetch_flash)
    # plug(:protect_from_forgery) # enabling interferes with graphql
  end

  @doc """
  Used to serve GraphQL API queries
  """
  pipeline :graphql do
    plug :accepts, ["json"]
    plug :fetch_session
    plug CommonsPub.Web.Plugs.Auth
    plug CommonsPub.Web.Plugs.SetLocale
    plug CommonsPub.Web.Plugs.GraphQLContext
  end

  scope "/api" do
    get "/", CommonsPub.Web.PageController, :api

    get "/schema", CommonsPub.Web.GraphQL.DevTools, :schema

    scope "/explore" do
      pipe_through :browser
      pipe_through :graphiql
      pipe_through :graphql

      get "/simple", Absinthe.Plug.GraphiQL,
        schema: CommonsPub.Web.GraphQL.Schema,
        interface: :simple,
        json_codec: Jason,
        pipeline: {CommonsPub.Web.GraphQL.Pipeline, :default_pipeline},
        default_url: "/api/graphql"

      get "/playground", Absinthe.Plug.GraphiQL,
        schema: CommonsPub.Web.GraphQL.Schema,
        interface: :playground,
        json_codec: Jason,
        pipeline: {CommonsPub.Web.GraphQL.Pipeline, :default_pipeline},
        default_url: "/api/graphql"

      forward "/", Absinthe.Plug.GraphiQL,
        schema: CommonsPub.Web.GraphQL.Schema,
        interface: :advanced,
        json_codec: Jason,
        pipeline: {CommonsPub.Web.GraphQL.Pipeline, :default_pipeline},
        default_url: "/api/graphql"
    end

    scope "/graphql" do
      pipe_through :graphql

      forward "/", Absinthe.Plug,
        schema: CommonsPub.Web.GraphQL.Schema,
        interface: :playground,
        json_codec: Jason,
        pipeline: {CommonsPub.Web.GraphQL.Pipeline, :default_pipeline}
    end
  end

  @doc """
  Serve a mock homepage
  """

  scope "/" do
    pipe_through :browser
    get "/", CommonsPub.Web.PageController, :index
    get "/confirm-email/:token", CommonsPub.Web.PageController, :confirm_email
    get "/logout", CommonsPub.Web.PageController, :logout
  end

  pipeline :liveview do
    plug :fetch_live_flash
    plug CommonsPub.Web.Live.Plug
  end

  pipeline :protect_forgery do
    plug :protect_from_forgery
  end

  scope "/", CommonsPub.Web do
    pipe_through :browser
    pipe_through :protect_forgery
    pipe_through :liveview

    # TODO redirect to instance or user depending on logged in
    live "/instance", InstanceLive

    live "/instance/search", SearchLive
    live "/instance/search/:tab", SearchLive
    live "/instance/search/:tab/:search", SearchLive

    live "/instance/map", Geolocation.MapLive
    live "/@@:id", Geolocation.MapLive

    live "/instance/categories", InstanceLive.InstanceCategoriesPageLive
    live "/instance/:tab", InstanceLive

    live "/@:username", MemberLive
    live "/@:username/:tab", MemberLive

    live "/&:username", CommunityLive
    live "/&:username/:tab", CommunityLive

    live "/+++:id", Page.Unknown
    live "/++:id", Page.Category

    live "/+:username", CollectionLive
    live "/+:username/:tab", CollectionLive

    live "/!:id/:do/:sub_id", DiscussionLive
    live "/!:id/:do", DiscussionLive
    live "/!:id", DiscussionLive

    live "/~/login", LoginLive
    live "/~/signup", SignupLive
    live "/~/terms", TermsLive
    live "/~/password/forgot", ResetPasswordLive
    live "/~/password/change", CreateNewPasswordLive
    live "/~/password/change/:token", CreateNewPasswordLive

    pipe_through :ensure_authenticated

    live "/~", MyLive
    live "/~/profile", MemberLive
    live "/~/write", My.WriteLive
    live "/~/settings", SettingsLive
    live "/~/settings/:tab", SettingsLive
    live "/~/:tab", MyLive

    live "/~/proto", My.ProtoProfileLive
  end

  scope "/" do
    pipe_through :browser
    pipe_through :ensure_authenticated

    # temporarily don't use CSRF for uploads until LV has a better approach

    post "/~/settings", CommonsPub.Web.My.SettingsUpload, :upload

    pipe_through :protect_forgery

    get "/api/tag/autocomplete/:prefix/:search", CommonsPub.Tag.Autocomplete, :get
    get "/api/tag/autocomplete/:consumer/:prefix/:search", CommonsPub.Tag.Autocomplete, :get
    get "/api/taxonomy/test", Taxonomy.Utils, :get
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  # if Mix.env() in [:dev, :test] do
  import Phoenix.LiveDashboard.Router

  scope "/admin/", CommonsPub.Web do
    pipe_through :browser
    pipe_through :liveview
    pipe_through :protect_forgery
    pipe_through :ensure_admin
    live "/settings/:tab", AdminLive
    live "/settings/:tab/:sub", AdminLive
    live_dashboard "/dashboard", metrics: CommonsPub.Utils.Metrics
  end

  # end

  if Mix.env() != :dev do
    def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack} = _info) do
      msg =
        if Map.has_key?(reason, :message) and !is_nil(reason.message) and
             String.length(reason.message) > 0 do
          reason.message
        else
          if is_map(reason) and Map.has_key?(reason, :term) and is_map(reason.term) and
               Map.has_key?(reason.term, :message) do
            reason.term.message
          else
            "An unhandled error has occured"
          end
        end

      send_resp(
        conn,
        conn.status,
        "Sorry! " <>
          msg <> "... Please try another way, or get in touch with the site admin."
      )
    end
  end
end
