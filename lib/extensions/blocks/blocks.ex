# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Blocks do
  alias Ecto.Changeset
  alias CommonsPub.{Common, Repo}
  alias CommonsPub.Blocks.{Block, Queries}
  alias CommonsPub.Users.User

  def one(filters), do: Repo.single(Queries.query(Block, filters))

  def many(filters), do: {:ok, Repo.all(Queries.query(Block, filters))}

  @spec find(User.t(), %{id: binary}) :: {:ok, Block.t()} | {:error, NotFoundError.t()}
  def find(%User{} = blocker, blocked) do
    one(deleted: false, creator: blocker.id, context: blocked.id)
  end

  @spec create(User.t(), any, map) :: {:ok, Block.t()} | {:error, Changeset.t()}
  def create(%User{} = blocker, blocked, fields) do
    Repo.insert(Block.create_changeset(blocker, blocked, fields))
  end

  @spec update(User.t(), Block.t(), map) :: {:ok, Block.t()} | {:error, Changeset.t()}
  def update(%User{}, %Block{} = block, fields) do
    Repo.update(Block.update_changeset(block, fields))
  end

  def update_by(%User{} = _user, filters, updates) do
    Repo.update_all(Queries.query(Block, filters), set: updates)
  end


  def ap_publish_activity("create", %Block{} = block) do
    block = CommonsPub.Repo.preload(block, creator: :character, context: [])

    with {:ok, blocker} <-
           ActivityPub.Actor.get_cached_by_username(block.creator.character.preferred_username),
         blocked = CommonsPub.Meta.Pointers.follow!(block.context),
         {:ok, blocked} <-
           ActivityPub.Actor.get_or_fetch_by_username(blocked.character.preferred_username) do
      # FIXME: insert pointer in AP database, insert cannonical URL in MN database
      ActivityPub.block(blocker, blocked)
    else
      e -> {:error, e}
    end
  end

  def ap_publish_activity("delete", %Block{} = block) do
    block = CommonsPub.Repo.preload(block, creator: :character, context: [])

    with {:ok, blocker} <-
           ActivityPub.Actor.get_cached_by_username(block.creator.character.preferred_username),
         blocked = CommonsPub.Meta.Pointers.follow!(block.context),
         {:ok, blocked} <-
           ActivityPub.Actor.get_or_fetch_by_username(blocked.character.preferred_username) do
      ActivityPub.unblock(blocker, blocked)
    else
      e -> {:error, e}
    end
  end

  # Activity: Block
  def ap_receive_activity(%{data: %{"type" => "Block"}} = activity, object) do
    with {:ok, blocker} <-
           CommonsPub.ActivityPub.Utils.get_raw_character_by_ap_id(activity.data["actor"]),
         {:ok, blocked} <-
           CommonsPub.ActivityPub.Utils.get_raw_character_by_ap_id(object),
         {:ok, _} <-
           CommonsPub.Blocks.create(blocker, blocked, %{
             is_public: true,
             is_muted: false,
             is_blocked: true,
             is_local: false,
             canonical_url: activity.data["id"]
           }) do
      :ok
    else
      {:error, e} -> {:error, e}
    end
  end

  # Unblock (Activity: Undo, Object: Block)
  def ap_receive_activity(
        %{data: %{"type" => "Undo"}} = activity,
        %{data:  %{"type" => "Block"}} = object
      ) do
    with {:ok, blocker} <-
           CommonsPub.ActivityPub.Utils.get_raw_character_by_ap_id(object.data["actor"]),
         {:ok, blocked} <-
           CommonsPub.ActivityPub.Utils.get_raw_character_by_ap_id(object.data["object"]),
         {:ok, block} <- CommonsPub.Blocks.find(blocker, blocked),
         {:ok, _} <- CommonsPub.Blocks.soft_delete(blocker, block) do
      :ok
    else
      {:error, e} -> {:error, e}
    end
  end

  @spec soft_delete(User.t(), Block.t()) :: {:ok, Block.t()} | {:error, Changeset.t()}
  def soft_delete(%User{}, %Block{} = block) do
    Common.Deletion.soft_delete(block)
  end

  def soft_delete_by(%User{} = user, filters) do
    with {:ok, _} <-
           Repo.transact_with(fn ->
             {_, _ids} =
               update_by(user, [{:deleted, false}, {:select, :id} | filters],
                 deleted_at: DateTime.utc_now()
               )

             :ok
           end),
         do: :ok
  end
end
