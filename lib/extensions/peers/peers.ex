# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Peers do
  @moduledoc """
  Manages peers, servers with which we connect via synchronisation
  protocols, currently: ActivityPub

  A `CommonsPub.Peers.Peer` is created from a `Pointers.Pointer`
  as the `CommonsPub.Meta.Peer` participates in the Meta abstraction

  """
  alias CommonsPub.{Common, Repo}
  alias CommonsPub.Common.NotFoundError
  alias CommonsPub.Peers.{Peer, Queries}

  # Querying

  @spec fetch(binary()) :: {:ok, Peer.t()} | {:error, NotFoundError.t()}
  @doc "Looks up the Peer with the given id in the database"
  def fetch(id), do: Repo.fetch(Peer, id)

  def one(filters \\ []), do: Repo.single(Queries.query(Peer, filters))
  def many(filters \\ []), do: {:ok, Repo.all(Queries.query(Peer, filters))}

  # Insertion

  @spec create(map()) :: {:ok, Peer.t()} | {:error, Changeset.t()}
  @doc "Create a Peer from the provided attributes"
  def create(attrs) do
    Repo.transact_with(fn ->
      Repo.insert(Peer.create_changeset(attrs))
    end)
  end

  # Updating

  @spec update(Peer.t(), map()) :: {:ok, Peer.t()} | {:error, Changeset.t()}
  @doc "Update the provided Peer with the provided attributes"
  def update(%Peer{} = peer, fields),
    do: Repo.update(Peer.update_changeset(peer, fields))

  # Soft deletion

  @spec soft_delete(Peer.t()) :: {:ok, Peer.t()} | {:error, DeletionError.t()}
  @doc "Marks a Peer as deleted in the database"
  def soft_delete(%Peer{} = peer), do: Common.Deletion.soft_delete(peer)

  @spec soft_delete!(Peer.t()) :: Peer.t()
  @doc "Marks a Peer as deleted in the database or throws a DeletionError"
  def soft_delete!(%Peer{} = peer), do: Common.Deletion.soft_delete!(peer)

  def soft_delete_by(filters) do
    Queries.query(Peer)
    |> Queries.filter(filters)
    |> Repo.delete_all()
  end
end
