defmodule MoodleNet do
  import ActivityPub.Guards
  alias ActivityPub.SQL.Query

  alias MoodleNet.Policy
  require ActivityPub.Guards, as: APG

  # User connections

  defp joined_communities_query(actor) do
    Query.new()
    |> Query.with_type("MoodleNet:Community")
    |> Query.belongs_to(:following, actor)
  end

  def joined_communities_list(actor, opts \\ %{}) do
    joined_communities_query(actor)
    |> Query.paginate_collection(opts)
    |> Query.all()
  end

  def joined_communities_count(actor) do
    joined_communities_query(actor)
    |> Query.count()
  end

  defp following_collection_query(actor) do
    Query.new()
    |> Query.with_type("MoodleNet:Collection")
    |> Query.belongs_to(:following, actor)
  end

  def following_collection_list(actor, opts \\ %{}) do
    following_collection_query(actor)
    |> Query.paginate_collection(opts)
    |> Query.all()
  end

  def following_collection_count(actor) do
    following_collection_query(actor)
    |> Query.count()
  end

  defp community_thread_query(community) do
    Query.new()
    |> Query.with_type("Note")
    |> Query.has(:context, community)
    |> has_no_replies()
  end

  def community_thread_list(community, opts \\ %{}) do
    community_thread_query(community)
    |> Query.paginate(opts)
    |> Query.all()
  end

  def community_thread_count(community) do
    community_thread_query(community)
    |> Query.count()
  end

  # Community connections

  def list_communities(opts \\ %{}) do
    Query.new()
    |> Query.with_type("MoodleNet:Community")
    |> Query.paginate(opts)
    |> Query.all()
  end

  defp community_collection_query(community) do
    Query.new()
    |> Query.with_type("MoodleNet:Collection")
    |> Query.has(:attributed_to, community)
  end

  def community_collection_list(community, opts \\ %{}) do
    community_collection_query(community)
    |> Query.paginate(opts)
    |> Query.all()
  end

  def community_collection_count(community) do
    community_collection_query(community)
    |> Query.count()
  end

  # Collection connections

  defp collection_follower_query(collection) do
    Query.new()
    |> Query.with_type("Person")
    |> Query.belongs_to(:followers, collection)
  end

  def collection_follower_list(collection, opts \\ %{}) do
    collection_follower_query(collection)
    |> Query.paginate_collection(opts)
    |> Query.all()
  end

  def collection_follower_count(collection) do
    collection_follower_query(collection)
    |> Query.count()
  end

  defp collection_resource_query(collection) do
    Query.new()
    |> Query.with_type("MoodleNet:EducationalResource")
    |> Query.has(:attributed_to, collection)
  end

  def collection_resource_list(collection, opts \\ %{}) do
    collection_resource_query(collection)
    |> Query.paginate_collection(opts)
    |> Query.all()
  end

  def collection_resource_count(collection) do
    collection_resource_query(collection)
    |> Query.count()
  end

  defp collection_thread_query(collection) do
    Query.new()
    |> Query.with_type("Note")
    |> Query.has(:context, collection)
    |> has_no_replies()
  end

  def collection_thread_list(collection, opts \\ %{}) do
    collection_thread_query(collection)
    |> Query.paginate(opts)
    |> Query.all()
  end

  def collection_thread_count(collection) do
    collection_thread_query(collection)
    |> Query.count()
  end

  defp collection_liker_query(collection) do
    Query.new()
    |> Query.with_type("Person")
    |> Query.belongs_to(:likers, collection)
  end

  def collection_liker_list(collection, opts \\ %{}) do
    collection_liker_query(collection)
    |> Query.paginate_collection(opts)
    |> Query.all()
  end

  def collection_liker_count(collection) do
    collection_liker_query(collection)
    |> Query.count()
  end

  # Resource connections

  defp resource_liker_query(resource) do
    Query.new()
    |> Query.with_type("Person")
    |> Query.belongs_to(:likers, resource)
  end

  def resource_liker_list(resource, opts \\ %{}) do
    resource_liker_query(resource)
    |> Query.paginate_collection(opts)
    |> Query.all()
  end

  def resource_liker_count(resource) do
    resource_liker_query(resource)
    |> Query.count()
  end

  # Comment connections

  defp comment_liker_query(comment) do
    Query.new()
    |> Query.with_type("Person")
    |> Query.belongs_to(:likers, comment)
  end

  def comment_liker_list(comment, opts \\ %{}) do
    comment_liker_query(comment)
    |> Query.paginate_collection(opts)
    |> Query.all()
  end

  def comment_liker_count(comment) do
    comment_liker_query(comment)
    |> Query.count()
  end

  defp comment_reply_query(comment) do
    Query.new()
    |> Query.with_type("Note")
    |> Query.has(:in_reply_to, comment)
  end

  def comment_reply_list(comment, opts \\ %{}) do
    comment_reply_query(comment)
    |> Query.paginate_collection(opts)
    |> Query.all()
  end

  def comment_reply_count(comment) do
    comment_reply_query(comment)
    |> Query.count()
  end
  def list_resources(entity_id, opts \\ %{})

  def list_resources(entity_id, opts) when is_integer(entity_id) do
    Query.new()
    |> Query.with_type("MoodleNet:EducationalResource")
    |> Query.has(:attributed_to, entity_id)
    |> Query.paginate(opts)
    |> Query.all()
  end

  def page_info(results, opts) do
    ActivityPub.SQL.Paginate.meta(results, opts)
  end

  defp has_no_replies(query) do
    import Ecto.Query, only: [from: 2]

    from([entity: entity] in query,
      left_join: rel in fragment("activity_pub_object_in_reply_tos"),
      on: entity.local_id == rel.subject_id,
      where: is_nil(rel.target_id)
    )
  end

  defp user_comment_query(actor) do
    Query.new()
    |> Query.with_type("Note")
    |> Query.has(:attributed_to, actor)
  end

  def user_comment_list(actor, opts \\ %{}) do
    user_comment_query(actor)
    |> Query.paginate(opts)
    |> Query.all()
  end

  def user_comment_count(actor) do
    user_comment_query(actor)
    |> Query.count()
  end

  defp community_member_query(community) do
    Query.new()
    |> Query.with_type("Person")
    |> Query.has(:following, community)
  end

  def community_member_list(community, opts \\ %{})
      when APG.has_type(community, "MoodleNet:Community") do
    community_member_query(community)
    |> Query.paginate_collection(opts)
    |> Query.all()
  end

  def community_member_count(community)
      when APG.has_type(community, "MoodleNet:Community") do
    community_member_query(community)
    |> Query.count()
  end

  def create_community(actor, attrs) do
    attrs = Map.put(attrs, "type", "MoodleNet:Community")

    with {:ok, entity} <- ActivityPub.new(attrs),
         {:ok, entity} <- ActivityPub.insert(entity),
         {:ok, true} <- MoodleNet.join_community(actor, entity) do
      {:ok, entity}
    end
  end

  def update_community(community, changes) do
    {icon_url, changes} = Map.pop(changes, :icon)
    icon = Query.new() |> Query.belongs_to(:icon, community) |> Query.one()

    # FIXME this should be a transaction
    with {:ok, _icon} <- ActivityPub.update(icon, url: icon_url) do
      ActivityPub.update(community, changes)
    end
  end

  def delete_community(_actor, community) do
    # FIXME this should be a transaction
    Query.new()
    |> Query.with_type("Note")
    |> Query.has(:context, community)
    |> Query.delete_all()

    community_local_id = ActivityPub.Entity.local_id(community)

    import Ecto.Query, only: [from: 2]

    from(entity in ActivityPub.SQLEntity,
      where: fragment("? @> array['MoodleNet:EducationalResource']", entity.type),
      join: collection_attributed_to in "activity_pub_object_attributed_tos",
      on: collection_attributed_to.subject_id == entity.local_id,
      join: community_attributed_to in "activity_pub_object_attributed_tos",
      on:
        collection_attributed_to.target_id == community_attributed_to.subject_id and
          community_attributed_to.target_id == ^community_local_id
    )
    |> MoodleNet.Repo.delete_all()

    from(entity in ActivityPub.SQLEntity,
      where: fragment("? @> array['Note']", entity.type),
      join: collection_context in "activity_pub_object_contexts",
      on: collection_context.subject_id == entity.local_id,
      join: community_attributed_to in "activity_pub_object_attributed_tos",
      on:
        collection_context.target_id == community_attributed_to.subject_id and
          community_attributed_to.target_id == ^community_local_id
    )
    |> MoodleNet.Repo.delete_all()

    Query.new()
    |> Query.with_type("MoodleNet:Collection")
    |> Query.has(:attributed_to, community)
    |> Query.delete_all()

    ActivityPub.delete(community, [:icon])
    :ok
  end

  def create_collection(actor, community, attrs)
      when has_type(community, "MoodleNet:Community") do
    attrs =
      attrs
      |> Map.put(:type, "MoodleNet:Collection")
      |> Map.put(:attributed_to, [community])

    with :ok <- Policy.create_collection?(actor, community, attrs),
         {:ok, entity} <- ActivityPub.new(attrs),
         {:ok, entity} <- ActivityPub.insert(entity),
         {:ok, true} <- follow_collection(actor, entity) do
      {:ok, entity}
    end
  end

  def update_collection(collection, changes) do
    {icon_url, changes} = Map.pop(changes, :icon)
    icon = Query.new() |> Query.belongs_to(:icon, collection) |> Query.one()

    # FIXME this should be a transaction
    with {:ok, _icon} <- ActivityPub.update(icon, url: icon_url) do
      ActivityPub.update(collection, changes)
    end
  end

  def delete_collection(_actor, collection) do
    # FIXME this should be a transaction
    Query.new()
    |> Query.with_type("Note")
    |> Query.has(:context, collection)
    |> Query.delete_all()

    Query.new()
    |> Query.with_type("MoodleNet:EducationalResource")
    |> Query.has(:attributed_to, collection)
    |> Query.delete_all()

    ActivityPub.delete(collection, [:icon])
    :ok
  end

  def create_resource(actor, collection, attrs)
      when has_type(collection, "MoodleNet:Collection") do
    attrs =
      attrs
      |> Map.put(:type, "MoodleNet:EducationalResource")
      |> Map.put(:attributed_to, [collection])

    collection = Query.preload_assoc(collection, :attributed_to)

    with :ok <- Policy.create_resource?(actor, collection, attrs),
         {:ok, entity} <- ActivityPub.new(attrs) do
      ActivityPub.insert(entity)
    end
  end

  def update_resource(resource, changes) do
    {icon_url, changes} = Map.pop(changes, :icon)
    icon = Query.new() |> Query.belongs_to(:icon, resource) |> Query.one()

    # FIXME this should be a transaction
    with {:ok, _icon} <- ActivityPub.update(icon, url: icon_url) do
      ActivityPub.update(resource, changes)
    end
  end

  def delete_resource(_actor, resource) do
    ActivityPub.delete(resource, [:icon])
    :ok
  end

  def copy_resource(actor, resource, collection) do
    resource =
      resource
      |> Query.preload_aspect(:resource)
      |> Query.preload_assoc([:icon])

    attrs =
      Map.take(resource, [
        :name,
        :summary,
        :content,
        :url,
        :primary_language,
        :icon,
        :published,
        :updated,
        :same_as,
        :in_language,
        :public_access,
        :is_accesible_for_free,
        :license,
        :learning_resource_type,
        :educational_use,
        :time_required,
        :typical_age_range
      ])

    url = get_in(resource, [:icon, Access.at(0), :url])
    attrs = Map.put(attrs, :icon, %{type: "Image", url: url})
    create_resource(actor, collection, attrs)
  end

  def create_thread(author, context, attrs)
      when has_type(author, "Person") and has_type(context, "MoodleNet:Community")
      when has_type(author, "Person") and has_type(context, "MoodleNet:Collection") do
    context = preload_community(context)

    attrs
    |> Map.put(:context, [context])
    |> Map.put(:attributed_to, [author])
    |> create_comment()
  end

  def create_reply(author, in_reply_to, attrs)
      when has_type(author, "Person") and has_type(in_reply_to, "Note") do
    context =
      Query.new()
      |> Query.belongs_to(:context, in_reply_to)
      |> Query.one()
      |> preload_community()

    attrs
    |> Map.put(:context, [context])
    |> Map.put(:in_reply_to, [in_reply_to])
    |> Map.put(:attributed_to, [author])
    |> create_comment()
  end

  defp create_comment(attrs) do
    attrs = attrs |> Map.put("type", "Note")
    [context] = attrs[:context]
    [actor] = attrs[:attributed_to]

    with :ok <- Policy.create_comment?(actor, context, attrs),
         {:ok, entity} <- ActivityPub.new(attrs) do
      ActivityPub.insert(entity)
    end
  end

  def delete_comment(actor, comment) do
    if Query.has?(comment, :attributed_to, actor) do
      ActivityPub.delete(comment)
    else
      {:error, :forbidden}
    end
  end

  def join_community(actor, community)
      when has_type(actor, "Person") and has_type(community, "MoodleNet:Community") do
    params = %{type: "Follow", actor: actor, object: community}

    with {:ok, activity} = ActivityPub.new(params),
         {:ok, _activity} <- ActivityPub.apply(activity) do
      {:ok, true}
    end
  end

  def follow_collection(actor, collection)
      when has_type(actor, "Person") and has_type(collection, "MoodleNet:Collection") do
    params = %{type: "Follow", actor: actor, object: collection}

    with {:ok, activity} = ActivityPub.new(params),
         {:ok, _activity} <- ActivityPub.apply(activity) do
      {:ok, true}
    end
  end

  def like_comment(actor, comment)
      when has_type(actor, "Person") and has_type(comment, "Note") do
    comment = preload_community(comment)
    attrs = %{type: "Like", actor: actor, object: comment}

    with :ok <- Policy.like_comment?(actor, comment, attrs),
         {:ok, activity} = ActivityPub.new(attrs),
         {:ok, _activity} <- ActivityPub.apply(activity) do
      {:ok, true}
    end
  end

  def like_collection(actor, collection)
      when has_type(actor, "Person") and has_type(collection, "MoodleNet:Collection") do
    collection = preload_community(collection)
    attrs = %{type: "Like", actor: actor, object: collection}

    with :ok <- Policy.like_collection?(actor, collection, attrs),
         {:ok, activity} = ActivityPub.new(attrs),
         {:ok, _activity} <- ActivityPub.apply(activity) do
      {:ok, true}
    end
  end

  def like_resource(actor, resource)
      when has_type(actor, "Person") and has_type(resource, "MoodleNet:EducationalResource") do
    resource = preload_community(resource)
    attrs = %{type: "Like", actor: actor, object: resource}

    with :ok <- Policy.like_resource?(actor, resource, attrs),
         {:ok, activity} = ActivityPub.new(attrs),
         {:ok, _activity} <- ActivityPub.apply(activity) do
      {:ok, true}
    end
  end

  def like(liker, liked) do
    params = %{type: "Like", actor: liker, object: liked}

    with {:ok, activity} = ActivityPub.new(params),
         {:ok, _activity} <- ActivityPub.apply(activity) do
      {:ok, true}
    end
  end

  def undo_follow(follower, following) do
    with :ok <- find_current_relation(follower, :following, following),
         {:ok, follow} <- find_activity("Follow", follower, following),
         params = %{type: "Undo", actor: follower, object: follow},
         {:ok, activity} = ActivityPub.new(params),
         {:ok, _activity} <- ActivityPub.apply(activity) do
      {:ok, true}
    end
  end

  def undo_like(liker, liked) do
    with :ok <- find_current_relation(liker, :liked, liked),
         {:ok, like} <- find_activity("Like", liker, liked),
         params = %{type: "Undo", actor: liker, object: like},
         {:ok, activity} = ActivityPub.new(params),
         {:ok, _activity} <- ActivityPub.apply(activity) do
      {:ok, true}
    end
  end

  defp find_current_relation(subject, relation, object) do
    if Query.has?(subject, relation, object) do
      :ok
    else
      subject_id = ActivityPub.Entity.local_id(subject)
      object_id = ActivityPub.Entity.local_id(object)
      {:error, {:not_found, [subject_id, object_id], "Activity"}}
    end
  end

  defp find_activity(type, actor, object) do
    Query.new()
    |> Query.with_type(type)
    |> Query.has(:actor, actor)
    |> Query.has(:object, object)
    |> Query.last()
    |> case do
      nil ->
        actor_id = ActivityPub.Entity.local_id(actor)
        object_id = ActivityPub.Entity.local_id(object)
        {:error, {:not_found, [actor_id, object_id], "Activity"}}

      activity ->
        activity = Query.preload_assoc(activity, actor: {[:actor], []}, object: {[:actor], []})
        {:ok, activity}
    end
  end

  defp preload_community(community) when has_type(community, "MoodleNet:Community"),
    do: community

  defp preload_community(collection) when has_type(collection, "MoodleNet:Collection"),
    do: Query.preload_assoc(collection, :attributed_to)

  defp preload_community(resource) when has_type(resource, "MoodleNet:EducationalResource") do
    Query.preload_assoc(resource, attributed_to: :attributed_to)
  end

  defp preload_community(comment) when has_type(comment, "Note") do
    comment = Query.preload_assoc(comment, :context)
    [context] = comment.context
    context = preload_community(context)
    %{comment | context: [context]}
  end
end
