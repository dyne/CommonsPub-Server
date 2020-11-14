# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.ConnCase do
  @moduledoc """
  This case template is for graphql tests. It is a slimmed down
  version of ConnCase.
  """

  use ExUnit.CaseTemplate
  require Phoenix.ConnTest

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import CommonsPub.Web.ConnCase
      import CommonsPub.Web.Test.ConnHelpers
      import CommonsPub.Web.Router.Helpers

      # The default endpoint for testing
      @endpoint CommonsPub.Web.Endpoint
    end
  end

  setup tags do
    Cachex.clear(:ap_actor_cache)
    Cachex.clear(:ap_object_cache)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CommonsPub.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(CommonsPub.Repo, {:shared, self()})
    end

    {:ok, %{}}
  end
end
