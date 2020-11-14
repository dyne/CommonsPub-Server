defmodule CommonsPub.Web.GraphQL.DevTools do
  use ActivityPubWeb, :controller

  def schema(conn, _params) do
    sdl = Absinthe.Schema.to_sdl(CommonsPub.Web.GraphQL.Schema)
    # "schema {
    #   query {...}
    # }"

    html(conn, sdl)
  end
end
