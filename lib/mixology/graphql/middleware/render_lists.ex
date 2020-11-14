# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.Middleware.RenderLists do
  @behaviour Absinthe.Middleware

  def call(resolution, _) do
    %{resolution | errors: collapse(resolution.errors)}
  end

  def collapse(list) when is_list(list), do: Enum.map(list, &collapse/1)
  def collapse(%{__struct__: _} = struct), do: Map.from_struct(struct)
  def collapse(other), do: other
end
