defmodule CommonsPub.Web.Component.ResourcePreviewLive do
  use Phoenix.LiveComponent
  import CommonsPub.Utils.Web.CommonHelper
  # import CommonsPub.Profiles.Web.ProfilesHelper

  # def mount(_, _session, socket) do
  #   {:ok, assign(socket, current_user: socket.assigns.current_user)}
  # end

  def update(assigns, socket) do
    # IO.inspect(resource_pre_prep: assigns.resource)

    # resource = CommonsPub.Profiles.Web.ProfilesHelper.prepare(assigns.resource, %{icon: true, character: true})

    resource = prepare_common(assigns.resource)

    resource = CommonsPub.Repo.maybe_preload(resource, tags: [:profile])

    IO.inspect(resource_post_prep: resource)

    {:ok,
     socket
     |> assign(
       resource: resource
       #  current_user: assigns.current_user
     )}
  end

  def render(assigns) do
    ~L"""
      <div class="resource__preview">
      <a href="<%= e(@resource, :link, "#") %>" target="_blank">
        <svg class="icon svg-icon svg-icon-note-empty" viewBox="0 0 32 32"><g fill-rule="evenodd"><rect fill="#DBDFE2" x="4" y="2" width="24" height="30" rx="1.5"></rect><rect fill="#F7F9FA" x="4" y="1" width="24" height="30" rx="1.5"></rect></g></svg>
      </a>

        <div class="preview__info">

        <a href="<%= e(@resource, :link, "#") %>" target="_blank">
          <h4><%= e(@resource, :name, "Resource") %></h4>
        </a>

        <%= if e(@resource, :author, nil) do  %>
        <p> Author: <%= e(@resource, :author, "") %>

      <% end %>

          <p><%= e(@resource, :summary, "") %>

          <%= if e(@resource, :accessibility_feature, nil) do  %>
            | Accessible

          <% end %>

          <%= if e(@resource, :free_access, nil)==false do  %>
          | Warning: Paywall
          <% end %>

          <%= if e(@resource, :public_access, nil)==false do  %>
          | FYI: Signup required
          <% end %>

          <%= if e(@resource, :license, nil) do  %>
          | License: <%= e(@resource, :license, "") %>
          <% end %>

          <%= if !is_nil(e(@resource, :tags, nil)) and length(@resource.tags)>0 do  %>
            <p> Tags:
            <%= for tag <- @resource.tags do %>
              <%= live_redirect to: object_url(tag) do %>
                  <%= e(tag, :profile, :name, "") %>
              <% end %>
              |
            <% end %>
          <% end %>
        </div>
        </a>
        </div>
    """
  end
end
