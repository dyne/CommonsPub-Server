# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Claim.Claims do
  import CommonsPub.Common, only: [maybe_put: 3, attr_get_id: 2]

  alias CommonsPub.Repo
  alias CommonsPub.Users.User

  alias ValueFlows.Claim
  alias ValueFlows.Claim.Queries

  alias CommonsPub.Meta.Pointers

  def one(filters), do: Repo.single(Queries.query(Claim, filters))

  def many(filters \\ []), do: {:ok, Repo.all(Queries.query(Claim, filters))}

  def preload_all(%Claim{} = claim) do
    # shouldn't fail
    {:ok, claim} = one(id: claim.id, preload: :all)
    claim
  end

  def create(%User{} = creator, %{id: _} = provider, %{id: _} = receiver, %{} = attrs) do
    Repo.transact_with(fn ->
      attrs = prepare_attrs(attrs)

      with {:ok, provider_ptr} <- Pointers.one(id: provider.id),
           {:ok, receiver_ptr} <- Pointers.one(id: receiver.id) do
        Claim.create_changeset(creator, provider_ptr, receiver_ptr, attrs)
        |> Claim.validate_required()
        |> Repo.insert()
        |> CommonsPub.Common.maybe_ok_error(&preload_all/1)
      end
    end)
  end

  def update(%Claim{} = claim, %{} = attrs) do
    Repo.transact_with(fn ->
      attrs = prepare_attrs(attrs)

      claim
      |> Claim.update_changeset(attrs)
      |> Repo.update()
      |> CommonsPub.Common.maybe_ok_error(&preload_all/1)
    end)
  end

  def soft_delete(%Claim{} = claim) do
    CommonsPub.Common.Deletion.soft_delete(claim)
  end

  defp prepare_attrs(attrs) do
    attrs
    |> maybe_put(:action_id, attr_get_id(attrs, :action))
    |> maybe_put(:context_id,
      attrs |> Map.get(:in_scope_of) |> CommonsPub.Common.maybe(&List.first/1)
    )
    |> maybe_put(:resource_conforms_to_id, attr_get_id(attrs, :resource_conforms_to))
    |> maybe_put(:triggered_by_id, attr_get_id(attrs, :triggered_by))
  end
end
