defmodule CommonsPub.Web.Page.Category do
  use CommonsPub.Web, :live_view

  import CommonsPub.Utils.Web.CommonHelper

  alias CommonsPub.Web.Page.Category.SubcategoriesLive
  alias CommonsPub.Web.CommunityLive.CommunityCollectionsLive
  alias CommonsPub.Web.CollectionLive.CollectionResourcesLive

  def mount(params, session, socket) do
    socket = init_assigns(params, session, socket)

    {:ok,
     socket
     |> assign(current_user: socket.assigns.current_user)
     |> assign(category: %{})
     |> assign(object_type: nil)}
  end

  def handle_params(%{} = params, _url, socket) do
    # obj = CommonsPub.Contexts.context_fetch(params["id"])

    top_level_category = System.get_env("TOP_LEVEL_CATEGORY", "")

    id =
      if !is_nil(params["id"]) and params["id"] != "" do
        params["id"]
      else
        top_level_category
      end

    {:ok, category} =
      if !is_nil(id) and id != "" do
        CommonsPub.Tag.Categories.get(id)
      else
        {:ok, %{}}
      end

    {:noreply,
     socket
     |> assign(current_user: socket.assigns.current_user)
     |> assign(category: category)
     |> assign(object_type: CommonsPub.Contexts.context_type(category))
     |> assign(current_context: category)}
  end
end
