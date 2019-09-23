# MoodleNet: Connecting and empowering educators worldwide
# Copyright © 2018-2019 Moodle Pty Ltd <https://moodle.com/moodlenet/>
# Contains code from Pleroma <https://pleroma.social/> and CommonsPub <https://commonspub.org/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule MoodleNet.Collections do
  alias MoodleNet.Common
  alias MoodleNet.Collections.Collection
  alias MoodleNet.Repo

  @spec create(attrs :: map) :: {:ok, %Collection{}} | {:error, Changeset.t()}
  def create(attrs) when is_map(attrs) do
    Repo.transact_with(fn ->
      Meta.point_to!(Collection)
      |> Collection.create_changeset(attrs)
      |> Repo.insert()
    end)
  end

  @spec update(%Collection{}, attrs :: map) :: {:ok, %Collection{}} | {:error, Changeset.t()}
  def update(%Collection{} = collection, attrs) do
    Repo.transact_with(fn ->
      collection
      |> Collection.update_changeset(attrs)
      |> Repo.update()
    end)
  end

  # @doc """
  # Likes a collection with a given reason
  # {:ok, CollectionLike} | {:error, reason}
  # """
  # def like(actor, collection),
  #   do: Common.like(CollectionLike, :like_collection?, :like_collection, actor, collection)

  # @doc """
  # Undoes a previous like
  # {:ok, CollectionLike} | {:error, term()}
  # """
  # def undo_like(actor, collection),
  #   do: Common.undo_like(CollectionLike, :unlike_collection, actor, collection)

  # @doc """
  # Lists all CollectionLike matching the provided optional filters.
  # Filters:
  #   :open :: boolean
  # """
  # def all_likes(actor, filters \\ %{}),
  #   do: Common.likes(CollectionLike, :list_collection_likes?, :flag_collection, actor, filters)

  # @doc """
  # Flags a collection with a given reason
  # {:ok, CollectionFlag} | {:error, reason}
  # """
  # def flag(actor, collection, attrs=%{reason: _}),
  #   do: Common.flag(CollectionFlag, :flag_collection?, :flag_collection, actor, collection, attrs)

  # @doc """
  # Undoes a previous flag
  # {:ok, CollectionFlag} | {:error, term()}
  # """
  # def undo_flag(actor, collection), do: Common.undo_flag(CollectionFlag, :undo_flag_collection, actor, collection)

  # @doc """
  # Lists all CollectionFlag matching the provided optional filters.
  # Filters:
  #   :open :: boolean
  # """
  # def all_flags(actor, filters \\ %{}),
  #   do: Common.flags(CollectionFlag, :list_collection_flags?, actor, filters)


end
