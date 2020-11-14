# SPDX-License-Identifier: AGPL-3.0-only

defmodule CommonsPub.Web do
  @moduledoc """
  Entrypoint for defining the CommonsPub web interfaces, such as controllers, views, channels and so on.

  The definitions below will be executed for every view, controller, etc, so keep them short and clean, focused on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions below. Instead, define any helper function in modules and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: CommonsPub.Web
      import Plug.Conn
      import CommonsPub.Web.Gettext

      # Liveview support
      import Phoenix.LiveView.Controller

      import CommonsPub.Web.Router.Helpers
      alias CommonsPub.Web.Router.Helpers, as: Routes
      alias ActivityPubWeb.Router.Helpers, as: APRoutes

      alias CommonsPub.Web.Plugs.ScrubParams

      action_fallback(CommonsPub.Web.FallbackController)
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/mixology/web/templates",
        # path: Phoenix.Template.module_to_template_root(__MODULE__, CommonsPub.Web, "View") <> "/templates/",
        # pattern: "*",
        namespace: CommonsPub.Web

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      # import CommonsPub.Web.ErrorHelpers
      # import CommonsPub.Web.Gettext
      # import Phoenix.LiveView.Helpers #Liveview support

      # use Phoenix.HTML

      alias CommonsPub.Web.Router.Helpers, as: Routes
      alias ActivityPubWeb.Router.Helpers, as: APRoutes

      # alias CommonsPub.Accounts.User
      # Include shared imports and aliases for views
      unquote(view_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {CommonsPub.Web.LayoutView, "live.html"}

      unquote(view_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      # Import LiveView helpers (live_render, live_component, live_patch, etc)
      import Phoenix.LiveView.Helpers

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import CommonsPub.Web.ErrorHelpers
      import CommonsPub.Web.Gettext
      alias CommonsPub.Web.Router.Helpers, as: Routes
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
      # liveview support
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import CommonsPub.Web.Gettext
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  def base_url do
    CommonsPub.Config.get(:base_url) || CommonsPub.Web.Endpoint.url()
  end
end
