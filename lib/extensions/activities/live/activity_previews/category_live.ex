defmodule CommonsPub.Web.Component.CategoryPreviewLive do
  use Phoenix.LiveComponent

  import CommonsPub.Utils.Web.CommonHelper

  def category_link(category) do
    id = e(category, :character, :preferred_username, nil) || e(category, :id, "#no-parent")

    "/++" <> id
  end

  def update(assigns, socket) do
    # object = prepare_common(assigns.object)

    object =
      CommonsPub.Repo.maybe_preload(assigns.object, [
        :profile,
        :character,
        parent_category: [:profile, :character, parent_category: [:profile, :character]]
      ])

    object =
      if !Map.get(object, :parent_category) and Map.get(object, :context),
        do: Map.put(object, :parent_category, Map.get(object, :context)),
        else: object

    # IO.inspect(category_preview: object)

    {:ok,
     assign(socket,
       object: object,
       top_level_category: System.get_env("TOP_LEVEL_CATEGORY", "")
     )}
  end

  def render(assigns) do
    ~L"""
    <div class="story__preview">
      <div class="preview__info">
      <%= if !is_nil(e(@object, :parent_category, :parent_category, :id, nil)) and @object.parent_category.parent_category.id != @top_level_category do %>
        <%= live_redirect to:  category_link(e(@object, :parent_category, :parent_category, nil)) do %>
        <%= e(@object, :parent_category, :parent_category, :profile, :name, "") %>
      <% end %>
        »
      <% end %>
      <%= if !is_nil(e(@object, :parent_category, :id, nil)) and @object.parent_category.id != @top_level_category do %>
        <%= live_redirect to:  category_link(e(@object, :parent_category, nil)) do %>
        <%= e(@object, :parent_category, :profile, :name, "") %>
        <% end %>
        »
        <% end %>
      <%= live_redirect to:  category_link(@object) do %>
        <%= e(@object, :name, "") %>
        <% end %>

        <p><%= e(@object, :summary, "") %></p>

      </div>
    </div>
    """
  end
end
