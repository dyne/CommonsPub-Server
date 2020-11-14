defmodule CommonsPub.Web.Component.LikePreviewLive do
  use Phoenix.LiveComponent
  import CommonsPub.Utils.Web.CommonHelper
  alias CommonsPub.Web.Component.ActivityLive

  def mount(_, _session, socket) do
    {:ok, assign(socket, current_user: socket.assigns.current_user)}
  end

  def update(assigns, socket) do
    # IO.inspect(like_pre_prep: assigns.like)
    like = CommonsPub.Contexts.prepare_context(assigns.like)

    # IO.inspect(like_post_prep: like)

    context =
      e(like, :context, %{})
      |> Map.merge(%{context_type: e(like, :context_type, nil)})
      |> Map.merge(%{display_verb: "created"})

    # IO.inspect(like_context: context)

    {:ok,
     socket
     |> assign(
       like: like,
       like_context: context,
       current_user: assigns.current_user
     )}
  end

  def render(assigns) do
    ~L"""
    <div class="like__preview">
      <%=live_component(
            @socket,
            ActivityLive,
            activity: @like_context,
            current_user: e(@current_user, %{})
          )
      %>
      </div>
    """
  end
end
