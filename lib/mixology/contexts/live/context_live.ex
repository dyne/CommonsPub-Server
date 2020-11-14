defmodule CommonsPub.Web.Component.ContextLive do
  use CommonsPub.Web, :live_component

  import CommonsPub.Utils.Web.CommonHelper

  def update(assigns, socket) do
    object = CommonsPub.Repo.maybe_preload(assigns.object, :context)

    {:ok,
     assign(socket,
       object: object
     )}
  end
end
