# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Communities do
  alias Ecto.Changeset

  alias CommonsPub.{
    Activities,
    # Blocks,
    # Collections,
    Common,
    # Features,
    Feeds,
    # Flags,
    # Follows,
    # Likes,
    Repo
    # Threads
  }

  alias CommonsPub.Characters

  alias CommonsPub.Communities.{Community, Queries}
  # alias CommonsPub.FeedPublisher
  alias CommonsPub.Feeds.FeedActivities
  alias CommonsPub.Users.User
  alias CommonsPub.Workers.APPublishWorker

  ### Cursor generators

  def cursor(:followers), do: &[&1.follower_count, &1.id]

  def test_cursor(:followers), do: &[&1["followerCount"], &1["id"]]

  ### Queries

  @doc "Retrieves a single community by arbitrary filters."
  def one(filters), do: Repo.single(Queries.query(Community, filters))

  def get(username) do
    with {:ok, c} <- one([:default, username: username]) do
      c
    end
  end

  @doc "Retrieves a list of communities by arbitrary filters."
  def many(filters \\ []), do: {:ok, Repo.all(Queries.query(Community, filters))}

  ### Mutations

  def create(%User{} = creator, %{id: _} = community_or_context, %{} = attrs) do
    Repo.transact_with(fn ->
      # TODO: address activity to context's outbox/followers
      community_or_context = CommonsPub.Repo.maybe_preload(community_or_context, :character)

      # with {:ok, comm_attrs} <- create_boxes(character, attrs),
      with {:ok, comm} <- insert_community(creator, community_or_context, attrs),
           {:ok, character} <- Characters.create(creator, attrs, comm),
           #  {:ok, _follow} <- Follows.create(creator, comm, %{is_local: true}),
           act_attrs = %{verb: "created", is_local: is_nil(character.peer_id)},
           {:ok, activity} <- Activities.create(creator, comm, act_attrs),
           :ok <- publish(creator, community_or_context, comm, activity),
           :ok <- ap_publish("create", comm) do
        CommonsPub.Search.Indexer.maybe_index_object(comm)
        {:ok, %{comm | character: character}}
      end
    end)
  end

  def create(%User{} = creator, _, %{} = attrs) do
    create(creator, attrs)
  end

  @spec create(User.t(), attrs :: map) :: {:ok, Community.t()} | {:error, Changeset.t()}
  def create(%User{} = creator, %{} = attrs) do
    Repo.transact_with(fn ->
      with {:ok, comm} <- insert_community(creator, attrs),
           {:ok, character} <- Characters.create(creator, attrs, comm),
           #  {:ok, _follow} <- Follows.create(creator, comm, %{is_local: true}),
           act_attrs = %{verb: "created", is_local: is_nil(character.peer_id)},
           {:ok, activity} <- Activities.create(creator, comm, act_attrs),
           :ok <- publish(creator, comm, activity),
           :ok <- ap_publish("create", comm) do
        CommonsPub.Search.Indexer.maybe_index_object(comm)
        {:ok, %{comm | character: character}}
      end
    end)
  end

  @spec create_remote(User.t(), attrs :: map) :: {:ok, Community.t()} | {:error, Changeset.t()}
  def create_remote(%User{} = creator, %{} = attrs) do
    Repo.transact_with(fn ->
      with {:ok, comm} <- insert_community(creator, attrs),
           {:ok, character} <- Characters.create(creator, attrs, comm),
           act_attrs = %{verb: "created", is_local: is_nil(character.peer_id)},
           {:ok, activity} <- Activities.create(creator, comm, act_attrs),
           :ok <- publish(creator, comm, activity) do
        CommonsPub.Search.Indexer.maybe_index_object(comm)
        {:ok, %{comm | character: character}}
      end
    end)
  end

  defp insert_community(creator, context, attrs) do
    with {:ok, community} <-
           Repo.insert(Community.create_changeset(creator, context, attrs)) do
      {:ok, %{community | context: context}}
    end
  end

  defp insert_community(creator, attrs) do
    with {:ok, community} <- Repo.insert(Community.create_changeset(creator, attrs)) do
      {:ok, community}
    end
  end

  @spec update(User.t(), %Community{}, attrs :: map) ::
          {:ok, Community.t()} | {:error, Changeset.t()}
  def update(%User{} = user, %Community{} = community, attrs) when is_map(attrs) do
    Repo.transact_with(fn ->
      community = Repo.preload(community, [:creator, context: [:character]])

      with {:ok, comm} <- Repo.update(Community.update_changeset(community, attrs)),
           {:ok, character} <- Characters.update(user, community.character, attrs),
           community <- %{comm | character: character},
           :ok <- ap_publish("update", community) do
        {:ok, community}
      end
    end)
  end

  def update_by(%User{}, filters, updates) do
    Repo.update_all(Queries.query(Community, filters), set: updates)
  end

  def soft_delete(%User{} = _user, %Community{} = community) do
    Repo.transact_with(fn ->
      community = Repo.preload(community, [:creator, :character])

      with {:ok, community} <- Common.Deletion.soft_delete(community),
           :ok <- CommonsPub.Characters.soft_delete(community),
           :ok <- ap_publish("delete", community) do
        {:ok, community}
      end
    end)
  end

  def soft_delete_by(%User{} = user, filters) do
    with {:ok, _} <-
           Repo.transact_with(fn ->
             {_, ids} =
               update_by(user, [{:deleted, false} | filters], deleted_at: DateTime.utc_now())

             CommonsPub.Characters.soft_delete(ids)

             ap_publish("delete", ids)
           end),
         do: :ok
  end

  # defp default_inbox_query_contexts() do
  #   CommonsPub.Config.get!(__MODULE__)
  #   |> Keyword.fetch!(:default_inbox_query_contexts)
  # end

  @doc false
  def default_outbox_query_contexts() do
    CommonsPub.Config.get!(__MODULE__)
    |> Keyword.fetch!(:default_outbox_query_contexts)
  end

  # Feeds

  defp publish(creator, context, community, activity) do
    feeds = [
      CommonsPub.Feeds.outbox_id(context),
      CommonsPub.Feeds.outbox_id(creator),
      CommonsPub.Feeds.outbox_id(community),
      Feeds.instance_outbox_id()
    ]

    FeedActivities.publish(activity, feeds)
  end

  defp publish(creator, community, activity) do
    feeds = [
      CommonsPub.Feeds.outbox_id(community),
      CommonsPub.Feeds.outbox_id(creator),
      Feeds.instance_outbox_id()
    ]

    FeedActivities.publish(activity, feeds)
  end

  defp ap_publish(verb, communities) when is_list(communities) do
    APPublishWorker.batch_enqueue(verb, communities)
    :ok
  end

  defp ap_publish(verb, %{character: %{peer_id: nil}} = community) do
    APPublishWorker.enqueue(verb, %{"context_id" => community.id})
    :ok
  end

  defp ap_publish(_, _), do: :ok

  def ap_publish_activity("create", %Community{} = community) do
    with {:ok, actor} <- ActivityPub.Actor.get_cached_by_local_id(community.creator_id),
         {:ok, ap_community} <- ActivityPub.Actor.get_cached_by_local_id(community.id),
         community_object <-
           ActivityPubWeb.ActorView.render("actor.json", %{actor: ap_community}),
         params <- %{
           actor: actor,
           to: [CommonsPub.ActivityPub.Utils.public_uri()],
           object: community_object,
           context: ActivityPub.Utils.generate_context_id(),
           additional: %{
             "cc" => [actor.data["followers"]]
           }
         },
         {:ok, activity} <- ActivityPub.create(params) do
      Ecto.Changeset.change(community.character, %{canonical_url: community_object["id"]})
      |> CommonsPub.Repo.update()

      {:ok, activity}
    else
      {:error, e} -> {:error, e}
    end
  end

  def ap_receive_update(actor, data, creator) do
    with {:ok, comm} <- CommonsPub.Communities.update(creator, actor, data) do
      {:ok, comm}
    else
      {:error, e} -> {:error, e}
    end
  end

  def indexing_object_format(%CommonsPub.Communities.Community{} = community) do
    community = Repo.preload(community, [:creator, context: [:character]])
    context = community.context

    follower_count =
      case CommonsPub.Follows.FollowerCounts.one(context: community.id) do
        {:ok, struct} -> struct.count
        {:error, _} -> nil
      end

    icon = CommonsPub.Uploads.remote_url_from_id(community.icon_id)
    image = CommonsPub.Uploads.remote_url_from_id(community.image_id)
    url = CommonsPub.ActivityPub.Utils.get_actor_canonical_url(community)

    %{
      "id" => community.id,
      "canonical_url" => url,
      "followers" => %{
        "total_count" => follower_count
      },
      "icon" => icon,
      "image" => image,
      "name" => community.name,
      "username" => CommonsPub.Characters.display_username(community),
      "summary" => Map.get(community, :summary),
      "index_type" => "Community",
      "index_instance" => CommonsPub.Search.Indexer.host(url),
      "published_at" => community.published_at,
      "context" => CommonsPub.Search.Indexer.maybe_indexable_object(context),
      "creator" => CommonsPub.Search.Indexer.format_creator(community)
    }
  end
end
