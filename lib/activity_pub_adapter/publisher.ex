# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.ActivityPub.Publisher do
  require Logger

  # TODO: move specialised publish funcs to context modules (or make them extensible for extra types)

  # defines default types that can be federated as AP Actors (overriden by config)
  @types_characters CommonsPub.Config.get([CommonsPub.Instance, :types_characters], [
                      CommonsPub.Users.User,
                      CommonsPub.Communities.Community,
                      CommonsPub.Collections.Collection,
                      CommonsPub.Characters.Character
                    ])

  # defines default types that can be federated as AP Objects (overriden by config)
  @types_inventory CommonsPub.Config.get([CommonsPub.Instance, :types_inventory], [
                     CommonsPub.Threads.Comment,
                     CommonsPub.Resources.Resource
                   ])

  def publish("update", %{__struct__: type, id: id})
      when type in @types_characters do
    # Works for Users, Collections, Communities (not MN.ActivityPub.Actor)
    with {:ok, actor} <- ActivityPub.Actor.get_by_local_id(id),
         actor_object <- ActivityPubWeb.ActorView.render("actor.json", %{actor: actor}),
         params <- %{
           to: [CommonsPub.ActivityPub.Utils.public_uri()],
           cc: [actor.data["followers"]],
           object: actor_object,
           actor: actor.ap_id,
           local: true
         } do
      ActivityPub.Actor.set_cache(actor)
      ActivityPub.update(params)
    else
      e -> {:error, e}
    end
  end

  def publish("delete", %CommonsPub.Users.User{} = user) do
    # is this broken?
    with actor <- CommonsPub.ActivityPub.Types.character_to_actor(user) do
      ActivityPub.Actor.set_cache(actor)
      ActivityPub.delete(actor)
    end
  end

  def publish("delete", %{__struct__: type} = character) when type in @types_characters do
    # Works for Collections, Communities (not User or MN.ActivityPub.Actor)

    with {:ok, creator} <- ActivityPub.Actor.get_by_local_id(character.creator_id),
         actor <- CommonsPub.ActivityPub.Types.character_to_actor(character) do
      ActivityPub.Actor.invalidate_cache(actor)
      ActivityPub.delete(actor, true, creator.ap_id)
    end
  end

  def publish("delete", %{__struct__: type} = thing) when type in @types_inventory do
    with %ActivityPub.Object{} = object <- ActivityPub.Object.get_cached_by_pointer_id(thing.id) do
      ActivityPub.delete(object)
    else
      e -> {:error, e}
    end
  end

  def publish(verb, %{__struct__: object_type} = local_object) do
    CommonsPub.Contexts.run_context_function(object_type, :ap_publish_activity, [verb, local_object], &error/2)
  end


  def publish(verb, object) do
    error("Unrecognised object for AP publisher", [verb, object])

    IO.inspect(object: object)

    :ignored
  end

  def error(error, [verb, %{__struct__: object_type, id: id} = object]) do
    Logger.error(
      "ActivityPub - Unable to federate - #{error}... object ID: #{id} ; verb: #{verb} ; object type: #{
        object_type
      }"
    )
    IO.inspect(object: object)

    :ignored
  end

  def error(error, [verb, object]) do
    Logger.error("ActivityPub - Unable to federate - #{error}... verb: #{verb}}")

    IO.inspect(object: object)

    :ignored
  end
end
