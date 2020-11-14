defmodule CommonsPub.Web.Page.Unknown do
  use CommonsPub.Web, :live_view

  import CommonsPub.Utils.Web.CommonHelper

  def mount(params, session, socket) do
    socket = init_assigns(params, session, socket)

    {:ok,
     socket
     |> assign(current_user: socket.assigns.current_user)
     |> assign(object: %{})
     |> assign(object_type: nil)}
  end

  def handle_params(%{} = params, _url, socket) do
    obj = CommonsPub.Contexts.context_fetch(params["id"])

    {:noreply,
     socket
     |> assign(current_user: socket.assigns.current_user)
     |> assign(object: obj)
     |> assign(object_type: CommonsPub.Contexts.context_type(obj))
     |> assign(current_context: obj)}
  end
end
