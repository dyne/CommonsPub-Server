defmodule CommonsPub.Tag.Categories do
  # import Ecto.Query
  # alias Ecto.Changeset

  alias CommonsPub.{
    Common,
    # GraphQL,
    Repo,
    GraphQL.Page,
    Contexts,
    Activities,
    Feeds
  }

  # alias CommonsPub.Users.User
  alias CommonsPub.Feeds.FeedActivities
  alias CommonsPub.Workers.APPublishWorker

  alias CommonsPub.Tag.Category
  alias CommonsPub.Tag.Category.Queries

  alias CommonsPub.Characters

  @facet_name "Category"

  def cursor(), do: &[&1.id]
  def test_cursor(), do: &[&1["id"]]

  def one(filters), do: Repo.single(Queries.query(Category, filters))

  def get(id) do
    if CommonsPub.Common.is_ulid(id) do
      one([:default, id: id])
    else
      one([:default, username: id])
    end
  end

  def many(filters \\ []), do: {:ok, Repo.all(Queries.query(Category, filters))}
  def list(), do: many([:default])

  @doc """
  Retrieves an Page of categorys according to various filters

  Used by:
  * GraphQL resolver single-parent resolution
  """
  def page(cursor_fn, page_opts, base_filters \\ [], data_filters \\ [], count_filters \\ [])

  def page(cursor_fn, %{} = page_opts, base_filters, data_filters, count_filters) do
    base_q = Queries.query(Category, base_filters)
    data_q = Queries.filter(base_q, data_filters)
    count_q = Queries.filter(base_q, count_filters)

    with {:ok, [data, counts]} <- Repo.transact_many(all: data_q, count: count_q) do
      {:ok, Page.new(data, counts, cursor_fn, page_opts)}
    end
  end

  @doc """
  Retrieves an Pages of categorys according to various filters

  Used by:
  * GraphQL resolver bulk resolution
  """
  def pages(
        cursor_fn,
        group_fn,
        page_opts,
        base_filters \\ [],
        data_filters \\ [],
        count_filters \\ []
      )

  def pages(cursor_fn, group_fn, page_opts, base_filters, data_filters, count_filters) do
    Contexts.pages(
      Queries,
      Category,
      cursor_fn,
      group_fn,
      page_opts,
      base_filters,
      data_filters,
      count_filters
    )
  end

  ## mutations

  @doc """
  Create a brand-new category object, with info stored in profile and character mixins
  """
  def create(creator, %{category: %{} = cat_attrs} = attrs) do
    create(
      creator,
      attrs
      |> Map.merge(cat_attrs)
      |> Map.delete(:category)
    )
  end

  def create(creator, %{facet: facet} = attrs)
      when not is_nil(facet) do
    Repo.transact_with(fn ->
      # TODO: check that the category doesn't already exist (same name and parent)

      with attrs <- attrs_prepare(attrs),
           {:ok, category} <- insert_category(creator, attrs),
           attrs <- attrs_mixins_with_id(attrs, category),
           {:ok, taggable} <-
             CommonsPub.Tag.Taggables.make_taggable(creator, category, attrs),
           {:ok, profile} <- CommonsPub.Profiles.create(creator, attrs),
           {:ok, character} <-
             CommonsPub.Characters.create(creator, attrs) do
        category = %{category | taggable: taggable, character: character, profile: profile}

        # add to search index
        index(category)

        # post as an activity
        act_attrs = %{verb: "created", is_local: is_nil(character.peer_id)}
        {:ok, activity} = Activities.create(creator, category, act_attrs)
        Repo.preload(category, :caretaker)
        :ok = publish(creator, category.caretaker, character, activity)
        :ok = ap_publish("create", category)

        {:ok, category}
      end
    end)
  end

  def create(creator, attrs) do
    create(creator, Map.put(attrs, :facet, @facet_name))
  end

  def maybe_create_hashtag(creator, "#" <> tag) do
    maybe_create_hashtag(creator, tag)
  end

  def maybe_create_hashtag(creator, tag) do
    create(
      creator,
      %{}
      |> Map.put(:name, tag)
      |> Map.put(:prefix, "#")
      |> Map.put(:facet, "Hashtag")
    )
  end

  defp attrs_prepare(attrs) do
    attrs
    |> attrs_with_parent_category()
    |> attrs_with_username()
  end

  def attrs_with_parent_category(%{parent_category: %{id: id} = parent_category} = attrs)
      when not is_nil(id) do
    put_attrs_with_parent_category(attrs, parent_category)
  end

  def attrs_with_parent_category(%{parent_category: id} = attrs)
      when is_binary(id) and id != "" do
    with {:ok, parent_category} <- get(id) do
      put_attrs_with_parent_category(attrs, parent_category)
    else
      _ ->
        put_attrs_with_parent_category(attrs, nil)
    end
  end

  def attrs_with_parent_category(%{parent_category_id: id} = attrs) when not is_nil(id) do
    attrs_with_parent_category(Map.put(attrs, :parent_category, id))
  end

  def attrs_with_parent_category(attrs) do
    put_attrs_with_parent_category(attrs, nil)
  end

  def put_attrs_with_parent_category(attrs, nil) do
    attrs
    |> Map.put(:parent_category, nil)
    |> Map.put(:parent_category_id, nil)
  end

  def put_attrs_with_parent_category(attrs, parent_category) do
    attrs
    |> Map.put(:parent_category, parent_category)
    |> Map.put(:parent_category_id, parent_category.id)
  end

  # todo: improve
  def attrs_with_username(%{preferred_username: preferred_username, name: _name} = attrs)
      when not is_nil(preferred_username) and preferred_username != "" do
    put_generated_username(attrs, preferred_username)
  end

  def attrs_with_username(
        %{preferred_username: preferred_username, profile: %{name: _name}} = attrs
      )
      when not is_nil(preferred_username) and preferred_username != "" do
    put_generated_username(attrs, preferred_username)
  end

  def attrs_with_username(
        %{character: %{preferred_username: preferred_username}, profile: %{name: _name}} = attrs
      )
      when not is_nil(preferred_username) and preferred_username != "" do
    put_generated_username(attrs, preferred_username)
  end

  def attrs_with_username(%{name: name} = attrs) do
    put_generated_username(attrs, name)
  end

  def attrs_with_username(%{profile: %{name: name}} = attrs) do
    put_generated_username(attrs, name)
  end

  def put_generated_username(
        %{parent_category: %{character: %{preferred_username: parent_name}}} = attrs,
        name
      )
      when not is_nil(name) and not is_nil(parent_name) do
    Map.put(attrs, :preferred_username, name <> "-" <> parent_name)
  end

  def put_generated_username(
        %{parent_category: %{profile: %{name: parent_name}}} = attrs,
        name
      )
      when not is_nil(name) and not is_nil(parent_name) do
    Map.put(attrs, :preferred_username, name <> "-" <> parent_name)
  end

  def put_generated_username(
        %{parent_category: %{name: parent_name}} = attrs,
        name
      )
      when not is_nil(name) and not is_nil(parent_name) do
    Map.put(attrs, :preferred_username, name <> "-" <> parent_name)
  end

  def put_generated_username(attrs, name) do
    # <> "-" <> attrs.facet
    Map.put(attrs, :preferred_username, name)
  end

  defp attrs_mixins_with_id(attrs, category) do
    Map.put(attrs, :id, category.id)
  end

  defp insert_category(user, attrs) do
    # IO.inspect(insert_category: attrs)
    cs = Category.create_changeset(user, attrs)
    with {:ok, category} <- Repo.insert(cs), do: {:ok, category}
  end

  def update(user, %Category{} = category, %{category: %{} = cat_attrs} = attrs) do
    update(
      user,
      category,
      attrs
      |> Map.merge(cat_attrs)
      |> Map.delete(:category)
    )
  end

  def update(user, %Category{} = category, attrs) do
    category = Repo.preload(category, [:profile, :character])

    # IO.inspect(category)
    # IO.inspect(attrs)

    Repo.transact_with(fn ->
      # :ok <- publish(category, :updated)
      with {:ok, category} <- Repo.update(Category.update_changeset(category, attrs)),
           {:ok, profile} <- CommonsPub.Profiles.update(user, category.profile, attrs),
           {:ok, character} <- Characters.update(user, category.character, attrs) do
        {:ok, %{category | character: character, profile: profile}}
      end
    end)
  end

  # Feeds

  defp publish(%{outbox_id: creator_outbox}, %{outbox_id: caretaker_outbox}, category, activity) do
    feeds = [
      caretaker_outbox,
      creator_outbox,
      category.outbox_id,
      Feeds.instance_outbox_id()
    ]

    FeedActivities.publish(activity, feeds)
  end

  defp publish(%{outbox_id: creator_outbox}, _, category, activity) do
    feeds = [category.outbox_id, creator_outbox, Feeds.instance_outbox_id()]
    FeedActivities.publish(activity, feeds)
  end

  defp publish(_, _, category, activity) do
    feeds = [category.outbox_id, Feeds.instance_outbox_id()]
    FeedActivities.publish(activity, feeds)
  end

  defp ap_publish(verb, communities) when is_list(communities) do
    APPublishWorker.batch_enqueue(verb, communities)
    :ok
  end

  defp ap_publish(verb, %{character: %{peer_id: nil}} = category) do
    APPublishWorker.enqueue(verb, %{"context_id" => category.id})
    :ok
  end

  defp ap_publish(_, _), do: :ok

  def indexing_object_format(%{id: _} = obj) do
    follower_count =
      case CommonsPub.Follows.FollowerCounts.one(context: obj.id) do
        {:ok, struct} -> struct.count
        {:error, _} -> nil
      end

    # icon = CommonsPub.Uploads.remote_url_from_id(character.icon_id)
    # image = CommonsPub.Uploads.remote_url_from_id(character.image_id)

    canonical_url = CommonsPub.ActivityPub.Utils.get_actor_canonical_url(obj)

    %{
      "index_type" => "Category",
      "facet" => obj.facet,
      "id" => obj.id,
      "canonicalUrl" => canonical_url,
      "followers" => %{
        "totalCount" => follower_count
      },
      "context" => indexing_object_format(Map.get(obj, :parent_category)),
      # "icon" => icon,
      # "image" => image,
      "name" => obj.name || obj.profile.name,
      "username" => CommonsPub.Characters.display_username(obj),
      # "summary" => character.summary,
      "createdAt" => obj.published_at,
      # home instance of object
      "index_instance" => CommonsPub.Search.Indexer.host(canonical_url)
    }
  end

  def indexing_object_format(_), do: nil

  defp index(obj) do
    object = indexing_object_format(obj)

    CommonsPub.Search.Indexer.maybe_index_object(object)

    :ok
  end


  def soft_delete(%Category{} = c) do
    Repo.transact_with(fn ->
      with {:ok, c} <- Common.Deletion.soft_delete(c) do
        {:ok, c}
      else
        e ->
          {:error, e}
      end
    end)
  end
end
