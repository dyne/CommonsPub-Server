# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Flags do
  alias CommonsPub.{Activities, Common, Repo}
  alias CommonsPub.Flags.{AlreadyFlaggedError, Flag, NotFlaggableError, Queries}
  alias CommonsPub.Users.User
  alias CommonsPub.Workers.APPublishWorker

  def one(filters), do: Repo.single(Queries.query(Flag, filters))

  def many(filters \\ []), do: {:ok, Repo.all(Queries.query(Flag, filters))}

  defp valid_contexts() do
    CommonsPub.Config.get!(__MODULE__)
    |> Keyword.fetch!(:valid_contexts)
  end

  def create(
        %User{} = flagger,
        flagged,
        community \\ nil,
        %{is_local: is_local} = fields
      )
      when is_boolean(is_local) do
    flagged = CommonsPub.Meta.Pointers.maybe_forge!(flagged)
    %Pointers.Table{schema: table} = CommonsPub.Meta.Pointers.table!(flagged)

    if table in valid_contexts() do
      Repo.transact_with(fn ->
        case one(deleted: false, creator: flagger.id, context: flagged.id) do
          {:ok, _} -> {:error, AlreadyFlaggedError.new(flagged.id)}
          _ -> really_create(flagger, flagged, community, fields)
        end
      end)
    else
      {:error, NotFlaggableError.new(flagged.id)}
    end
  end

  defp really_create(flagger, flagged, community, fields) do
    with {:ok, flag} <- insert_flag(flagger, flagged, community, fields),
         {:ok, _activity} <- insert_activity(flagger, flag, "created"),
         :ok <- publish(flagger, flagged, flag, community),
         :ok <- ap_publish("create", flag) do
      {:ok, flag}
    end
  end

  def update_by(%User{}, filters, updates) do
    Repo.update_all(Queries.query(Flag, filters), set: updates)
  end

  def soft_delete(%User{} = user, %Flag{} = flag) do
    Repo.transact_with(fn ->
      with {:ok, flag} <- Common.Deletion.soft_delete(flag),
           :ok <- chase_delete(user, flag.id),
           :ok <- ap_publish("delete", flag) do
        {:ok, flag}
      end
    end)
  end

  def soft_delete_by(%User{} = user, filters) do
    with {:ok, _} <-
           Repo.transact_with(fn ->
             {_, ids} =
               update_by(user, [{:select, :id}, {:deleted, false} | filters],
                 deleted_at: DateTime.utc_now()
               )

             with :ok <- chase_delete(user, ids) do
               ap_publish("delete", ids)
             end
           end),
         do: :ok
  end

  defp chase_delete(user, ids) do
    Activities.soft_delete_by(user, context: ids)
  end

  # TODO ?
  defp publish(_flagger, _flagged, _flag, _community), do: :ok

  defp ap_publish(verb, flags) when is_list(flags) do
    APPublishWorker.batch_enqueue(verb, flags)
    :ok
  end

  defp ap_publish(verb, %Flag{is_local: true} = flag) do
    APPublishWorker.enqueue(verb, %{"context_id" => flag.id})
    :ok
  end

  defp ap_publish(_, _), do: :ok

  def ap_publish_activity("create", %Flag{} = flag) do
    flag = CommonsPub.Repo.preload(flag, creator: :character, context: [])

    with {:ok, flagger} <-
           ActivityPub.Actor.get_cached_by_username(flag.creator.character.preferred_username) do
      flagged = CommonsPub.Meta.Pointers.follow!(flag.context)

      # FIXME: this is kinda stupid, need to figure out a better way to handle meta-participating objects
      params =
        case flagged do
          %{character: %{preferred_username: preferred_username} = _character}
          when not is_nil(preferred_username) ->
            {:ok, account} = ActivityPub.Actor.get_or_fetch_by_username(preferred_username)

            %{
              statuses: nil,
              account: account
            }

          %{character_id: id} when not is_nil(id) ->
            flagged = CommonsPub.Repo.preload(flagged, :character)

            {:ok, account} =
              ActivityPub.Actor.get_or_fetch_by_username(flagged.character.preferred_username)

            %{
              statuses: nil,
              account: account
            }

          %{creator_id: id} when not is_nil(id) ->
            flagged = CommonsPub.Repo.preload(flagged, creator: :character)

            {:ok, account} =
              ActivityPub.Actor.get_or_fetch_by_username(
                flagged.creator.character.preferred_username
              )

            %{
              statuses: [ActivityPub.Object.get_cached_by_pointer_id(flagged.id)],
              account: account
            }
        end

      ActivityPub.flag(
        %{
          actor: flagger,
          context: ActivityPub.Utils.generate_context_id(),
          statuses: params.statuses,
          account: params.account,
          content: flag.message,
          forward: true
        },
        flag.id
      )
    else
      e -> {:error, e}
    end
  end

  # def ap_receive_activity(activity, objects) do
  #   IO.inspect(activity)
  #   IO.inspect(objects)
  # end

  # Activity: Flag (many objects)
  def ap_receive_activity(%{data: %{"type" => "Flag"}} = activity, objects)
      when is_list(objects) and length(objects) > 1 do
    with {:ok, actor} <-
           CommonsPub.ActivityPub.Utils.get_raw_character_by_ap_id(activity.data["actor"]) do
      objects
      |> Enum.map(fn ap_id -> CommonsPub.ActivityPub.Utils.get_pointer_id_by_ap_id(ap_id) end)
      # Filter nils
      |> Enum.filter(fn pointer_id -> pointer_id end)
      |> Enum.map(fn pointer_id ->
        CommonsPub.Meta.Pointers.one!(id: pointer_id)
        |> CommonsPub.Meta.Pointers.follow!()
      end)
      |> Enum.each(fn thing ->
        CommonsPub.Flags.create(actor, thing, %{
          message: activity.data["content"],
          is_local: false
        })
      end)

      :ok
    end
  end

  # Activity: Flag (one object)
  def ap_receive_activity(activity, [object]) do
    ap_receive_activity(activity, object)
  end

  def ap_receive_activity(%{data: %{"type" => "Flag"}} = activity, object) do
    with {:ok, actor} <-
           CommonsPub.ActivityPub.Utils.get_raw_character_by_ap_id(activity.data["actor"]),
         pointer_id <- CommonsPub.ActivityPub.Utils.get_pointer_id_by_ap_id(object),
         thing =
           CommonsPub.Meta.Pointers.one!(id: pointer_id)
           |> CommonsPub.Meta.Pointers.follow!() do
      CommonsPub.Flags.create(actor, thing, %{
        message: activity.data["content"],
        is_local: false
      })

      :ok
    end
  end

  defp insert_activity(flagger, flag, verb) do
    Activities.create(flagger, flag, %{verb: verb, is_local: flag.is_local})
  end

  defp insert_flag(flagger, flagged, community, fields) do
    Repo.insert(Flag.create_changeset(flagger, community, flagged, fields))
  end
end
