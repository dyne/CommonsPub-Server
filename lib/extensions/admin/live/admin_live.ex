defmodule CommonsPub.Web.AdminLive do
  use CommonsPub.Web, :live_view

  import CommonsPub.Utils.Web.CommonHelper

  alias CommonsPub.Web.AdminLive.{
    AdminNavigationLive,
    AdminInstanceLive,
    AdminAccessLive,
    AdminFlagsLive
    # AdminInvitesLive
  }

  def mount(params, session, socket) do
    # IO.inspect(session)
    socket = init_assigns(params, session, socket)

    {:ok,
     socket
     |> assign(
       page_title: "Settings",
       selected_tab: "access",
       selected_sub: "all",
       trigger_submit: false
       #  current_user: user,
       #  session: session_token
     )}
  end

  def handle_params(%{"sub" => sub, "tab" => _tab} = _params, _url, socket) do
    IO.inspect(sub, label: "sub")

    {:noreply,
     assign(socket,
       selected_sub: sub,
       current_user: socket.assigns.current_user
     )}
  end

  def handle_params(%{"tab" => tab} = params, _url, socket) do
    IO.inspect(params, label: "params")

    {:noreply,
     assign(socket,
       selected_tab: tab,
       current_user: socket.assigns.current_user
     )}
  end

  def handle_params(%{} = _params, _url, socket) do
    {:noreply,
     assign(socket,
       current_user: socket.assigns.current_user
     )}
  end

  # def handle_params(%{} = params, url, socket) do
  #   user = ProfilesHelper.user_load(socket, params, %{image: true, icon: true, character: true})

  #   {:noreply,
  #    assign(socket,
  #      user: user
  #    )}
  # end
end
