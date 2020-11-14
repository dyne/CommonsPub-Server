# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Resources do
  alias Ecto.Changeset
  alias CommonsPub.{Activities, Common, Feeds, Flags, Likes, Repo, Threads}
  # alias CommonsPub.Collections.Collection
  # alias CommonsPub.FeedPublisher
  alias CommonsPub.Feeds.FeedActivities
  alias CommonsPub.Resources.{Resource, Queries}
  alias CommonsPub.Threads
  alias CommonsPub.Users.User
  alias CommonsPub.Workers.APPublishWorker

  alias CommonsPub.Utils.Web.CommonHelper

  @doc """
  Retrieves a single resource by arbitrary filters.
  Used by:
  * GraphQL Item queries
  * ActivityPub integration
  * Various parts of the codebase that need to query for resources (inc. tests)
  """
  def one(filters), do: Repo.single(Queries.query(Resource, filters))

  @doc """
  Retrieves a list of resources by arbitrary filters.
  Used by:
  * Various parts of the codebase that need to query for resources (inc. tests)
  """
  def many(filters \\ []), do: {:ok, Repo.all(Queries.query(Resource, filters))}

  ## and now the writes...

  @spec create(User.t(), any(), attrs :: map) ::
          {:ok, Resource.t()} | {:error, Changeset.t()}
  def create(%User{} = creator, %{} = collection_or_context, attrs) when is_map(attrs) do
    Repo.transact_with(fn ->
      collection_or_context = CommonsPub.Repo.maybe_preload(collection_or_context, :character)

      with {:ok, resource} <- insert_resource(creator, collection_or_context, attrs),
           {:ok, resource} <- ValueFlows.Util.try_tag_thing(creator, resource, attrs),
           act_attrs = %{
             verb: "created",
             is_local:
               is_nil(
                 CommonsPub.Utils.Web.CommonHelper.e(
                   collection_or_context,
                   :character,
                   :peer_id,
                   nil
                 )
               )
           },
           {:ok, activity} <- insert_activity(creator, resource, act_attrs),
           :ok <- publish(creator, collection_or_context, resource, activity),
           :ok <- ap_publish("create", resource) do
        CommonsPub.Search.Indexer.maybe_index_object(resource)
        {:ok, %Resource{resource | creator: creator}}
      end
    end)
  end

  def create(%User{} = creator, _, attrs) when is_map(attrs) do
    create(creator, attrs)
  end

  def create(%User{} = creator, attrs) when is_map(attrs) do
    Repo.transact_with(fn ->
      with {:ok, resource} <- insert_resource(creator, attrs),
           {:ok, resource} <- ValueFlows.Util.try_tag_thing(creator, resource, attrs),
           act_attrs = %{
             verb: "created",
             is_local: is_nil(Map.get(creator.character, :peer_id, nil))
           },
           {:ok, activity} <- insert_activity(creator, resource, act_attrs),
           :ok <- publish(creator, resource, activity),
           :ok <- ap_publish("create", resource) do
        CommonsPub.Search.Indexer.maybe_index_object(resource)

        {:ok, %Resource{resource | creator: creator}}
      end
    end)
  end

  def clean_and_prepare_tags(%{summary: content} = attrs) when is_binary(content) do
    {content, mentions, hashtags} = CommonsPub.HTML.parse_input_and_tags(content, "text/markdown")

    # IO.inspect(tagging: {content, mentions, hashtags})

    attrs
    |> Map.put(:summary, content)
    |> Map.put(:mentions, mentions)
    |> Map.put(:hashtags, hashtags)
  end

  def clean_and_prepare_tags(attrs), do: attrs

  def save_attached_tags(creator, obj, attrs) do
    with {:ok, _taggable} <-
           CommonsPub.Tag.TagThings.thing_attach_tags(creator, obj, attrs.mentions) do
      # {:ok, CommonsPub.Repo.preload(comment, :tags)}
      {:ok, nil}
    end
  end

  defp insert_activity(creator, resource, attrs) do
    Activities.create(creator, resource, attrs)
  end

  defp insert_resource(creator, collection_or_context, attrs) do
    Repo.insert(Resource.create_changeset(creator, collection_or_context, attrs))
  end

  defp insert_resource(creator, attrs) do
    Repo.insert(Resource.create_changeset(creator, attrs))
  end

  @spec update(User.t(), Resource.t(), attrs :: map) ::
          {:ok, Resource.t()} | {:error, Changeset.t()}
  def update(%User{}, %Resource{} = resource, attrs) when is_map(attrs) do
    with {:ok, updated} <- Repo.update(Resource.update_changeset(resource, attrs)),
         :ok <- ap_publish("update", resource) do
      {:ok, updated}
    end
  end

  def update_by(%User{}, filters, updates) do
    Repo.update_all(Queries.query(Resource, filters), set: updates)
  end

  @spec soft_delete(User.t(), Resource.t()) :: {:ok, Resource.t()} | {:error, Changeset.t()}
  def soft_delete(%User{} = user, %Resource{} = resource) do
    Repo.transact_with(fn ->
      resource = Repo.preload(resource, context: [:character])

      with {:ok, deleted} <- Common.Deletion.soft_delete(resource),
           :ok <- chase_delete(user, deleted.id),
           :ok <- ap_publish("delete", resource) do
        {:ok, deleted}
      end
    end)
  end

  def soft_delete_by(%User{} = user, filters) do
    with {:ok, _} <-
           Repo.transact_with(fn ->
             {_, ids} =
               update_by(user, [{:select, :id} | filters], deleted_at: DateTime.utc_now())

             with :ok <- chase_delete(user, ids) do
               ap_publish("delete", ids)
             end
           end),
         do: :ok
  end

  defp chase_delete(user, ids) do
    with :ok <- Activities.soft_delete_by(user, context: ids),
         :ok <- Flags.soft_delete_by(user, context: ids),
         :ok <- Likes.soft_delete_by(user, context: ids),
         :ok <- Threads.soft_delete_by(user, context: ids) do
      :ok
    end
  end

  defp publish(creator, context, resource, activity) do
    feeds = [
      CommonsPub.Feeds.outbox_id(context),
      CommonsPub.Feeds.outbox_id(creator),
      CommonsPub.Feeds.outbox_id(resource),
      Feeds.instance_outbox_id()
    ]

    FeedActivities.publish(activity, feeds)
  end

  defp publish(creator, resource, activity) do
    feeds = [
      CommonsPub.Feeds.outbox_id(creator),
      CommonsPub.Feeds.outbox_id(resource),
      Feeds.instance_outbox_id()
    ]

    FeedActivities.publish(activity, feeds)
  end

  defp ap_publish(verb, resources) when is_list(resources) do
    APPublishWorker.batch_enqueue(verb, resources)
    :ok
  end

  # todo: detect if local
  defp ap_publish(verb, %Resource{} = resource) do
    APPublishWorker.enqueue(verb, %{"context_id" => resource.id})
    :ok
  end

  defp ap_publish(_, _), do: :ok

  def ap_publish_activity("create", %Resource{} = resource) do
    # FIXME: optional
    with {:ok, context} <- ActivityPub.Actor.get_cached_by_local_id(resource.context_id),
         {:ok, actor} <- ActivityPub.Actor.get_cached_by_local_id(resource.creator_id),
         content_url <- CommonsPub.Uploads.remote_url_from_id(resource.content_id),
         icon_url <- CommonsPub.Uploads.remote_url_from_id(resource.icon_id),
         ap_id <- CommonsPub.ActivityPub.Utils.generate_object_ap_id(resource),
         object <- %{
           "id" => ap_id,
           "name" => resource.name,
           "url" => content_url,
           "icon" => icon_url,
           "actor" => actor.ap_id,
           "attributedTo" => actor.ap_id,
           "context" => context.ap_id,
           "summary" => Map.get(resource, :summary),
           "type" => "Document",
           "tag" => resource.license,
           "author" => CommonsPub.ActivityPub.Utils.create_author_object(resource),
           #  "mediaType" => resource.content.media_type
           "subject" => Map.get(resource, :subject),
           "level" => Map.get(resource, :level),
           "language" => Map.get(resource, :language)
         },
         params = %{
           actor: actor,
           to: [CommonsPub.ActivityPub.Utils.public_uri(), context.ap_id],
           object: object,
           context: context.ap_id,
           additional: %{
             "cc" => [actor.data["followers"]]
           }
         },
         {:ok, activity} <- ActivityPub.create(params, resource.id) do
      Ecto.Changeset.change(resource, %{canonical_url: activity.object.data["id"]})
      |> CommonsPub.Repo.update()

      {:ok, activity}
    else
      e -> {:error, e}
    end
  end

  # Activity: Create / Object : Document
  def ap_receive_activity(
        %{data: %{"type" => "Create", "context" => context}} = _activity,
        %{data: %{"type" => "Document", "actor" => actor}} = object
      ) do
    with {:ok, collection} <- CommonsPub.ActivityPub.Utils.get_raw_character_by_ap_id(context),
         {:ok, actor} <- CommonsPub.ActivityPub.Utils.get_raw_character_by_ap_id(actor),
         {:ok, content} <-
           CommonsPub.Uploads.upload(
             CommonsPub.Uploads.ResourceUploader,
             actor,
             %{url: object.data["url"]},
             %{is_public: true}
           ),
         icon_url <- CommonsPub.ActivityPub.Utils.maybe_fix_image_object(object.data["icon"]),
         icon_id <- CommonsPub.ActivityPub.Utils.maybe_create_icon_object(icon_url, actor),
         attrs <- %{
           is_public: true,
           is_local: false,
           is_disabled: false,
           name: object.data["name"],
           canonical_url: object.data["id"],
           summary: object.data["summary"],
           content_id: content.id,
           license: object.data["tag"],
           icon_id: icon_id,
           author: CommonsPub.ActivityPub.Utils.get_author(object.data["author"]),
           subject: object.data["subject"],
           level: object.data["level"],
           language: object.data["language"]
         },
         {:ok, resource} <-
           CommonsPub.Resources.create(actor, collection, attrs) do
      ActivityPub.Object.update(object, %{pointer_id: resource.id})
      # Indexer.maybe_index_object(resource) # now being called in CommonsPub.Resources.create
      :ok
    else
      {:error, e} -> {:error, e}
    end
  end

  def indexing_object_format(%CommonsPub.Resources.Resource{} = resource) do
    resource = CommonsPub.Repo.maybe_preload(resource, :creator)
    resource = CommonsPub.Repo.maybe_preload(resource, :context)
    context = CommonsPub.Repo.maybe_preload(Map.get(resource, :context), :character)

    resource = CommonsPub.Repo.maybe_preload(resource, :content)

    likes_count =
      case CommonsPub.Likes.LikerCounts.one(context: resource.id) do
        {:ok, struct} -> struct.count
        {:error, _} -> nil
      end

    icon = CommonsPub.Uploads.remote_url_from_id(resource.icon_id)
    resource_url = CommonsPub.Uploads.remote_url_from_id(resource.content_id)

    canonical_url = CommonsPub.ActivityPub.Utils.get_object_canonical_url(resource)

    %{
      "id" => resource.id,
      "name" => resource.name,
      "canonical_url" => canonical_url,
      "created_at" => resource.published_at,
      "icon" => icon,
      "licence" => Map.get(resource, :license),
      "likes" => %{
        "total_count" => likes_count
      },
      "summary" => Map.get(resource, :summary),
      "updated_at" => resource.updated_at,
      "index_type" => "Resource",
      "index_instance" => CommonsPub.Search.Indexer.host(canonical_url),
      "url" => resource_url,
      "author" => Map.get(resource, :author),
      "media_type" => resource.content.media_type,
      "subject" => Map.get(resource, :subject),
      "level" => Map.get(resource, :level),
      "language" => Map.get(resource, :language),
      "public_access" => Map.get(resource, :public_access),
      "free_access" => Map.get(resource, :free_access),
      "accessibility_feature" => Map.get(resource, :accessibility_feature),
      "context" => CommonsPub.Search.Indexer.maybe_indexable_object(context),
      "creator" => CommonsPub.Search.Indexer.format_creator(resource)
    }
  end
end
