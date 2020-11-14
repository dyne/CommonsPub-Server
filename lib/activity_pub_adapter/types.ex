defmodule CommonsPub.ActivityPub.Types do
  def character_to_actor(character) do
    type =
      case character do
        %CommonsPub.Users.User{} -> "Person"
        %CommonsPub.Communities.Community{} -> "Group"
        %CommonsPub.Collections.Collection{} -> "MN:Collection"
        # %CommonsPub.Characters.Character{} -> "CommonsPub:" <> Map.get(character, :facet, "Character")
        _ -> "CommonsPub:Character"
      end

    character = CommonsPub.Repo.maybe_preload(character, [:character])
    character = CommonsPub.Repo.maybe_preload(character, [:profile])

    context = CommonsPub.ActivityPub.Utils.get_context_ap_id(character)

    character =
      character
      |> Map.merge(Map.get(character, :character, %{}))
      |> Map.merge(Map.get(character, :profile, %{}))

    icon_url = CommonsPub.Uploads.remote_url_from_id(Map.get(character, :icon_id))

    image_url = CommonsPub.Uploads.remote_url_from_id(Map.get(character, :image_id))

    id = CommonsPub.ActivityPub.Utils.generate_actor_url(character)

    username = CommonsPub.ActivityPub.Utils.get_actor_username(character)

    # IO.inspect(character)

    data =
      %{
        "type" => type,
        "id" => id,
        "inbox" => "#{id}/inbox",
        "outbox" => "#{id}/outbox",
        "followers" => "#{id}/followers",
        "following" => "#{id}/following",
        "preferredUsername" => username,
        "name" => Map.get(character, :name),
        "summary" => Map.get(character, :summary)
      }
      |> CommonsPub.Common.maybe_put(
        "icon",
        CommonsPub.ActivityPub.Utils.maybe_create_image_object(icon_url)
      )
      |> CommonsPub.Common.maybe_put(
        "image",
        CommonsPub.ActivityPub.Utils.maybe_create_image_object(image_url)
      )
      |> CommonsPub.Common.maybe_put(
        "attributedTo",
        CommonsPub.ActivityPub.Utils.get_different_creator_ap_id(character)
      )
      |> CommonsPub.Common.maybe_put("context", context)
      |> CommonsPub.Common.maybe_put("collections", get_and_format_collections_for_actor(character))
      |> CommonsPub.Common.maybe_put("resources", get_and_format_resources_for_actor(character))

    %ActivityPub.Actor{
      id: character.id,
      data: data,
      keys: Map.get(Map.get(character, :character, character), :signing_key),
      local: CommonsPub.ActivityPub.Utils.check_local(character),
      ap_id: id,
      pointer_id: character.id,
      username: username,
      deactivated: false
    }
  end


  # TODO
  def get_and_format_collections_for_actor(_actor) do
    []
  end

  # TODO
  def get_and_format_resources_for_actor(_actor) do
    []
  end
end
