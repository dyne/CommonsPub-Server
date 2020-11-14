# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.Middleware.CollapseErrors do
  @behaviour Absinthe.Middleware

  alias AbsintheErrorPayload.ChangesetParser

  def call(resolution, _) do
    %{resolution | errors: collapse(resolution.errors)}
  end

  def collapse(list) when is_list(list), do: List.flatten(Enum.map(list, &collapse/1))

  def collapse(%Ecto.Changeset{} = changeset),
    do: extract_messages(changeset)

  def collapse(%{__struct__: _} = struct), do: Map.from_struct(struct)
  def collapse(other), do: other

  defp extract_messages(changeset) do
    messages = ChangesetParser.extract_messages(changeset)

    for message <- messages do
      message
      |> Map.take([:code, :message, :field])
      |> Map.put_new(:status, 200)
    end
  end
end
