# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.ActivityPub.Adapter do
  @moduledoc """
  Adapter functions delegated from the `ActivityPub` Library
  """
  alias CommonsPub.ActivityPub.Utils
  alias CommonsPub.Workers.APReceiverWorker
  require Logger

  @behaviour ActivityPub.Adapter

  def base_url() do
    CommonsPub.Web.base_url()
  end

  @doc """
  Queue-up incoming activities to be processed by `CommonsPub.Workers.APReceiverWorker`
  """
  def handle_activity(activity) do
    APReceiverWorker.enqueue("handle_activity", %{
      "activity_id" => activity.id,
      "activity" => activity.data
    })
  end

  def get_follower_local_ids(actor) do
    {:ok, actor} = CommonsPub.ActivityPub.Utils.get_raw_character_by_id(actor.pointer_id)
    {:ok, follows} = CommonsPub.Follows.many(context: actor.id)

    follows |> Enum.map(fn follow -> follow.creator_id end)
  end

  def get_following_local_ids(actor) do
    {:ok, actor} = CommonsPub.ActivityPub.Utils.get_raw_character_by_id(actor.pointer_id)
    {:ok, follows} = CommonsPub.Follows.many(creator: actor.id)

    follows |> Enum.map(fn follow -> follow.context_id end)
  end

  def get_actor_by_id(id) do
    case CommonsPub.ActivityPub.Utils.get_raw_character_by_id(id) do
      {:ok, character} ->
        # IO.inspect(get_raw_character_by_id: actor)
        {:ok, CommonsPub.ActivityPub.Types.character_to_actor(character)}

      _ ->
        {:error, "not found"}
    end
  end

  def get_actor_by_username(username) do
    case CommonsPub.ActivityPub.Utils.get_raw_character_by_username(username) do
      {:ok, character} ->
        {:ok, CommonsPub.ActivityPub.Types.character_to_actor(character)}

      _ ->
        {:error, "not found"}
    end
  end

  def get_actor_by_ap_id(ap_id) do
    case CommonsPub.ActivityPub.Utils.get_raw_character_by_ap_id(ap_id) do
      {:ok, character} ->
        {:ok, CommonsPub.ActivityPub.Types.character_to_actor(character)}

      _ ->
        {:error, "not found"}
    end
  end

  # def redirect_to_object(id) do
  #   if System.get_env("LIVEVIEW_ENABLED", "true") == "true" do
  #     url = CommonsPub.Utils.Web.CommonHelper.object_url(id)
  #     if !String.contains?(url, "/404"), do: url
  #   end
  # end

  def redirect_to_actor(username) do
    if System.get_env("LIVEVIEW_ENABLED", "true") == "true" do
      case CommonsPub.ActivityPub.Utils.get_raw_character_by_username(username) do
        {:ok, character} ->
          url = CommonsPub.Utils.Web.CommonHelper.object_url(character)
          if !String.contains?(url, "/404"), do: url

        _ ->
          nil
      end
    end
  end

  def update_local_actor(actor, params) do
    keys = Map.get(params, :keys)
    params = Map.put(params, :signing_key, keys)
    # FIXME - does it work for characters other than user?
    with {:ok, local_actor} <-
           CommonsPub.Characters.one(username: actor.data["preferredUsername"]),
         {:ok, local_actor} <-
           CommonsPub.Characters.update(%CommonsPub.Users.User{}, local_actor, params),
         {:ok, local_actor} <- get_actor_by_username(local_actor.preferred_username) do
      {:ok, local_actor}
    else
      {:error, e} -> {:error, e}
    end
  end

  def update_remote_actor(actor_object) do
    data = actor_object.data

    with {:ok, character} <-
           CommonsPub.ActivityPub.Utils.get_raw_character_by_id(actor_object.pointer_id),
         creator <- CommonsPub.Repo.maybe_preload(character, :creator) |> Map.get(:creator, nil) do
      # FIXME - support other types
      params = %{
        name: data["name"],
        summary: data["summary"],
        icon_id:
          CommonsPub.ActivityPub.Utils.maybe_create_icon_object(
            CommonsPub.ActivityPub.Utils.maybe_fix_image_object(data["icon"]),
            creator
          ),
        image_id:
          CommonsPub.ActivityPub.Utils.maybe_create_image_object(
            CommonsPub.ActivityPub.Utils.maybe_fix_image_object(data["image"]),
            creator
          )
      }

      # FIXME
      case character do
        %CommonsPub.Users.User{} ->
          CommonsPub.Users.ap_receive_update(character, params, creator)

        %CommonsPub.Communities.Community{} ->
          CommonsPub.Communities.ap_receive_update(character, params, creator)

        %CommonsPub.Collections.Collection{} ->
          CommonsPub.Collections.ap_receive_update(character, params, creator)

        true ->
          CommonsPub.Characters.ap_receive_update(character, params, creator)
      end
    end
  end

  def maybe_create_remote_actor(actor) do
    host = URI.parse(actor.data["id"]).host
    username = actor.data["preferredUsername"] <> "@" <> host

    case CommonsPub.Characters.one(username: username) do
      {:error, _} ->
        with {:ok, _actor} <-
               CommonsPub.ActivityPub.Receiver.create_remote_character(actor.data, username) do
          :ok
        else
          _e -> {:error, "Could not create remote actor"}
        end

      _ ->
        :ok
    end
  end
end
