# SPDX-License-Identifier: AGPL-3.0-only
defmodule Geolocation.Geolocations do
  alias CommonsPub.{
    Activities,
    Common,
    Feeds,
    # Follows,
    Repo
  }

  alias CommonsPub.Characters

  alias CommonsPub.GraphQL.{Fields, Page}
  alias CommonsPub.Contexts
  alias Geolocation
  alias Geolocation.Queries
  alias CommonsPub.Feeds.FeedActivities
  alias CommonsPub.Users.User
  alias CommonsPub.Workers.APPublishWorker

  def cursor(:followers), do: &[&1.follower_count, &1.id]
  def test_cursor(:followers), do: &[&1["followerCount"], &1["id"]]

  @doc """
  Retrieves a single collection by arbitrary filters.
  Used by:
  * GraphQL Item queries
  * ActivityPub integration
  * Various parts of the codebase that need to query for collections (inc. tests)
  """
  def one(filters), do: Repo.single(Queries.query(Geolocation, filters))

  @doc """
  Retrieves a list of collections by arbitrary filters.
  Used by:
  * Various parts of the codebase that need to query for collections (inc. tests)
  """
  def many(filters \\ []), do: {:ok, Repo.all(Queries.query(Geolocation, filters))}

  def fields(group_fn, filters \\ [])
      when is_function(group_fn, 1) do
    {:ok, fields} = many(filters)
    {:ok, Fields.new(fields, group_fn)}
  end

  @doc """
  Retrieves an Page of geolocations according to various filters

  Used by:
  * GraphQL resolver single-parent resolution
  """
  def page(cursor_fn, page_opts, base_filters \\ [], data_filters \\ [], count_filters \\ [])

  def page(cursor_fn, %{} = page_opts, base_filters, data_filters, count_filters) do
    base_q = Queries.query(Geolocation, base_filters)
    data_q = Queries.filter(base_q, data_filters)
    count_q = Queries.filter(base_q, count_filters)

    with {:ok, [data, counts]} <- Repo.transact_many(all: data_q, count: count_q) do
      {:ok, Page.new(data, counts, cursor_fn, page_opts)}
    end
  end

  @doc """
  Retrieves an Pages of geolocations according to various filters

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
      Geolocation,
      cursor_fn,
      group_fn,
      page_opts,
      base_filters,
      data_filters,
      count_filters
    )
  end

  ## mutations

  @spec create(User.t(), context :: any, attrs :: map) ::
          {:ok, Geolocation.t()} | {:error, Changeset.t()}
  def create(creator, %{} = context, attrs) when is_map(attrs) do
    Repo.transact_with(fn ->
      with {:ok, attrs} <- resolve_mappable_address(attrs),
           {:ok, item} <- insert_geolocation(creator, context, attrs),
           {:ok, character} <- Characters.create(creator, attrs, item),
           act_attrs = %{verb: "created", is_local: true},
           {:ok, activity} <- Activities.create(creator, item, act_attrs),
           :ok <- publish(creator, context, item, activity, :created) do
        {:ok, populate_result(item, character)}
      end
    end)
  end

  def create(creator, _, attrs) when is_map(attrs) do
    create(creator, attrs)
  end

  @spec create(User.t(), attrs :: map) :: {:ok, Geolocation.t()} | {:error, Changeset.t()}
  def create(creator, attrs) when is_map(attrs) do
    Repo.transact_with(fn ->
      with {:ok, attrs} <- resolve_mappable_address(attrs),
           {:ok, item} <- insert_geolocation(creator, attrs),
           {:ok, character} <- Characters.create(creator, attrs, item),
           act_attrs = %{verb: "created", is_local: true},
           {:ok, activity} <- Activities.create(creator, item, act_attrs),
           :ok <- publish(creator, item, activity, :created) do
        {:ok, populate_result(item, character)}
      end
    end)
  end

  defp insert_geolocation(creator, context, attrs) do
    cs = Geolocation.create_changeset(creator, context, attrs)

    with {:ok, item} <- Repo.insert(cs) do
      {:ok, %{item | context: context}}
    end
  end

  defp insert_geolocation(creator, attrs) do
    cs = Geolocation.create_changeset(creator, attrs)
    with {:ok, item} <- Repo.insert(cs), do: {:ok, item}
  end


  defp publish(creator, context, geolocation, activity, :created) do
    feeds = [
      CommonsPub.Feeds.outbox_id(context),
      CommonsPub.Feeds.outbox_id(creator),
      CommonsPub.Feeds.outbox_id(geolocation),
      Feeds.instance_outbox_id()
    ]

    with :ok <- FeedActivities.publish(activity, feeds) do
      ap_publish("create", geolocation.id, creator.id)
    end
  end

  defp publish(creator, geolocation, activity, :created) do
    feeds = [
      CommonsPub.Feeds.outbox_id(creator),
      CommonsPub.Feeds.outbox_id(geolocation),
      Feeds.instance_outbox_id()
    ]

    with :ok <- FeedActivities.publish(activity, feeds) do
      ap_publish("create", geolocation.id, CommonsPub.Common.maybe_get(creator, :id))
    end
  end

  defp ap_publish(verb, context_id, user_id) do
    job_result =
      APPublishWorker.enqueue(verb, %{
        "context_id" => context_id,
        "user_id" => user_id
      })

    with {:ok, _} <- job_result, do: :ok
  end

  defp ap_publish(_, _, _), do: :ok

  @spec update(User.t(), Geolocation.t(), attrs :: map) ::
          {:ok, Geolocation.t()} | {:error, Changeset.t()}
  def update(%User{} = user, %Geolocation{} = geolocation, attrs) do
    with {:ok, attrs} <- resolve_mappable_address(attrs),
         {:ok, item} <- Repo.update(Geolocation.update_changeset(geolocation, attrs)),
         :ok <- ap_publish("update", item.id, user.id) do
      {:ok, populate_coordinates(item)}
    end
  end

  @spec soft_delete(User.t(), Geolocation.t()) :: {:ok, Geolocation.t()} | {:error, Changeset.t()}
  def soft_delete(%User{} = user, %Geolocation{} = geo) do
    Repo.transact_with(fn ->
      with {:ok, geo} <- Common.Deletion.soft_delete(geo),
           :ok <- ap_publish("delete", geo.id, user.id) do
        {:ok, geo}
      end
    end)
  end

  def populate_result(geo, character) do
    populate_coordinates(%{geo | character: character})
  end

  def populate_coordinates(%Geolocation{geom: geom} = geo) when not is_nil(geom) do
    {lat, long} = geo.geom.coordinates

    %{geo | lat: lat, long: long}
  end

  def populate_coordinates(geo), do: geo || %{}

  def resolve_mappable_address(%{mappable_address: address} = attrs) when is_binary(address) do
    with {:ok, coords} <- Geocoder.call(address) do
      # IO.inspect(attrs)
      # IO.inspect(coords)
      # TODO: should take bounds and save in `geom`
      {:ok, Map.put(Map.put(attrs, :lat, coords.lat), :long, coords.lon)}
    else
      _ -> {:ok, attrs}
    end
  end

  def resolve_mappable_address(attrs), do: {:ok, attrs}
end
