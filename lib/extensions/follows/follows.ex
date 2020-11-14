# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Follows do
  alias CommonsPub.{Activities, Common, Repo}
  alias CommonsPub.Feeds.{FeedActivities, FeedSubscriptions}

  alias CommonsPub.Follows.{
    AlreadyFollowingError,
    Follow,
    Queries
  }

  alias CommonsPub.Users.{LocalUser, User}
  alias CommonsPub.Workers.APPublishWorker
  alias Ecto.Changeset

  def one(filters), do: Repo.single(Queries.query(Follow, filters))

  def many(filters \\ []), do: {:ok, Repo.all(Queries.query(Follow, filters))}

  @type create_opt :: {:publish, bool} | {:federate, bool}
  @type create_opts :: [create_opt]

  @spec create(User.t(), any, map) :: {:ok, Follow.t()} | {:error, Changeset.t()}
  @spec create(User.t(), any, map, create_opts) :: {:ok, Follow.t()} | {:error, Changeset.t()}

  def create(follower, followed, fields, opts \\ [])

  def create(%User{} = follower, %Pointers.Pointer{} = followed, %{} = fields, opts) do
    create(follower, CommonsPub.Meta.Pointers.follow!(followed), fields, opts)
  end

  def create(%User{} = follower, %{character: %{outbox_id: _} = followed}, fields, opts) do
    create(follower, followed, fields, opts)
  end

  def create(%User{} = follower, %_struct{outbox_id: _} = followed, fields, _opts) do
    # if struct in valid_contexts() do
    Repo.transact_with(fn ->
      case one(deleted: false, creator: follower.id, context: followed.id) do
        {:ok, _} ->
          {:error, AlreadyFollowingError.new("user")}

        _ ->
          with {:ok, follow} <- insert(follower, followed, fields),
               :ok <- subscribe(follower, followed, follow),
               :ok <- publish(follower, followed, follow),
               :ok <- ap_publish("create", follow) do
            {:ok, %{follow | ctx: followed}}
          end
      end
    end)

    # else
    #   GraphQL.not_permitted()
    # end
  end

  def create(_, _, _, _) do
    # fail silently
    {:ok, nil}
  end

  defp insert(follower, followed, fields) do
    Repo.insert(Follow.create_changeset(follower, followed, fields))
  end

  defp publish(creator, followed, %Follow{} = follow) do
    attrs = %{verb: "created", is_local: follow.is_local}

    with {:ok, activity} <- Activities.create(creator, follow, attrs) do
      FeedActivities.publish(activity, [CommonsPub.Feeds.outbox_id(creator), followed.outbox_id])
    end
  end

  defp ap_publish(verb, follows) when is_list(follows) do
    APPublishWorker.batch_enqueue(verb, follows)
    :ok
  end

  defp ap_publish(verb, %Follow{is_local: true} = follow) do
    APPublishWorker.enqueue(verb, %{"context_id" => follow.id})
    :ok
  end

  defp ap_publish(_, _), do: :ok

  def ap_publish_activity("create", %Follow{} = follow) do
    ## FIXME: this is currently implemented in a spec non-conforming way, AP follows are supposed to be handshakes
    ## that are only reflected in the host database upon receiving an Accept activity in response. in this case
    ## the follow activity is created based on a Follow object that's already in MN database, which is wrong.
    ## For now we just delete the folow and return an error if the followed account is private.
    follow = CommonsPub.Repo.preload(follow, creator: :character, context: [:table])

    with {:ok, follower} <-
           ActivityPub.Actor.get_cached_by_username(follow.creator.character.preferred_username),
         followed = CommonsPub.Meta.Pointers.follow!(follow.context),
         followed = CommonsPub.Repo.preload(followed, :character),
         {:ok, followed} <-
           ActivityPub.Actor.get_or_fetch_by_username(followed.character.preferred_username) do
      if followed.data["manuallyApprovesFollowers"] do
        CommonsPub.Follows.soft_delete(follow.creator, follow)
        {:error, "account is private"}
      else
        # FIXME: insert pointer in AP database, insert cannonical URL in MN database
        ActivityPub.follow(follower, followed)
      end
    else
      e -> {:error, e}
    end
  end

  def ap_publish_activity("delete", %Follow{} = follow) do
    follow = CommonsPub.Repo.preload(follow, creator: :character, context: [])

    with {:ok, follower} <-
           ActivityPub.Actor.get_cached_by_username(follow.creator.character.preferred_username),
         followed = CommonsPub.Meta.Pointers.follow!(follow.context),
         {:ok, followed} <-
           ActivityPub.Actor.get_or_fetch_by_username(followed.character.preferred_username) do
      ActivityPub.unfollow(follower, followed)
    else
      e -> {:error, e}
    end
  end

  # Activity: Follow
  def ap_receive_activity(%{data: %{"type" => "Follow"}} = activity, object) do
    with {:ok, follower} <-
           CommonsPub.ActivityPub.Utils.get_raw_character_by_ap_id(activity.data["actor"]),
         {:ok, followed} <-
           CommonsPub.ActivityPub.Utils.get_raw_character_by_ap_id(object),
         {:ok, _} <-
           CommonsPub.Follows.create(follower, followed, %{
             is_public: true,
             is_muted: false,
             is_local: false,
             canonical_url: activity.data["id"]
           }) do
      :ok
    else
      {:error, e} -> {:error, e}
    end
  end

  # Unfollow (Activity: Undo, Object: Follow)
  def ap_receive_activity(
        %{data: %{"type" => "Undo"}} = activity,
        %{data:  %{"type" => "Follow"}} = object
      ) do
    with {:ok, follower} <-
           CommonsPub.ActivityPub.Utils.get_raw_character_by_ap_id(object.data["actor"]),
         {:ok, followed} <-
           CommonsPub.ActivityPub.Utils.get_raw_character_by_ap_id(object.data["object"]),
         {:ok, follow} <-
           CommonsPub.Follows.one(deleted: false, creator: follower.id, context: followed.id),
         {:ok, _} <- CommonsPub.Follows.soft_delete(follower, follow) do
      :ok
    else
      {:error, e} -> {:error, e}
    end
  end

  @spec update(User.t(), Follow.t(), map) :: {:ok, Follow.t()} | {:error, Changeset.t()}
  def update(%User{}, %Follow{} = follow, fields) do
    Repo.transact_with(fn ->
      with {:ok, follow} <- Repo.update(Follow.update_changeset(follow, fields)),
           :ok <- ap_publish("update", follow) do
        {:ok, follow}
      end
    end)
  end

  def update_by(%User{}, filters, updates) do
    Repo.update_all(Queries.query(Follow, filters), set: updates)
  end

  @spec soft_delete(User.t(), Follow.t()) :: {:ok, Follow.t()} | {:error, Changeset.t()}
  def soft_delete(%User{} = user, %Follow{} = follow) do
    Repo.transact_with(fn ->
      with {:ok, follow} <- Common.Deletion.soft_delete(follow),
           :ok <- chase_delete(user, [follow.id], [follow.context_id]),
           :ok <- ap_publish("delete", follow) do
        {:ok, follow}
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

             with :ok <- chase_delete(user, ids, []) do
               ap_publish("delete", ids)
             end
           end),
         do: :ok
  end

  defp chase_delete(user, follows, contexts) do
    with {:ok, pointers} <- CommonsPub.Meta.Pointers.many(id: contexts),
         contexts = CommonsPub.Meta.Pointers.follow!(pointers),
         feeds = get_outbox_ids(contexts, []),
         :ok <- Activities.soft_delete_by(user, context: follows),
         :ok <- FeedSubscriptions.soft_delete_by(user, feed: feeds) do
      :ok
    end
  end

  defp get_outbox_ids([], acc), do: acc
  defp get_outbox_ids([%{outbox_id: id} | rest], acc), do: get_outbox_ids(rest, [id | acc])
  defp get_outbox_ids([_ | rest], acc), do: get_outbox_ids(rest, acc)

  # we only maintain subscriptions for local users
  defp subscribe(%User{local_user: %LocalUser{}} = follower, %{outbox_id: outbox_id}, %Follow{
         muted_at: nil
       })
       when is_binary(outbox_id) do
    case FeedSubscriptions.one(deleted: false, subscriber: follower.id, feed: outbox_id) do
      {:ok, _} ->
        :ok

      _ ->
        with {:ok, _} <- FeedSubscriptions.create(follower, outbox_id, %{is_active: true}),
             do: :ok
    end
  end

  defp subscribe(_, _, _), do: :ok

  # defp unsubscribe(%{creator_id: creator_id, is_local: true, muted_at: nil}=follow) do
  #   context = CommonsPub.Meta.Pointers.follow!(Repo.preload(follow, :context).context)
  #   case FeedSubscriptions.one(deleted: false, subscriber: creator_id, feed: context.outbox_id) do
  #     {:ok, sub} -> Common.Deletion.soft_delete(sub)
  #     _ -> {:ok, []} # shouldn't be here
  #   end
  # end

  # defp unsubscribe(_), do: {:ok, []}

  def valid_contexts() do
    CommonsPub.Config.get!(__MODULE__)
    |> Keyword.fetch!(:valid_contexts)
  end
end
