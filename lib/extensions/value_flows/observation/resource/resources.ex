# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Observation.EconomicResource.EconomicResources do
  import CommonsPub.Common, only: [maybe_put: 3, attr_get_id: 2, maybe_get_id: 1]

  alias CommonsPub.{Activities, Common, Feeds, Repo}
  alias CommonsPub.GraphQL.{Fields, Page}
  alias CommonsPub.Contexts
  alias CommonsPub.Feeds.FeedActivities
  alias CommonsPub.Users.User

  alias ValueFlows.Observation.EconomicResource
  alias ValueFlows.Observation.EconomicResource.Queries
  alias ValueFlows.Observation.EconomicEvent.EconomicEvents

  def cursor(), do: &[&1.id]
  def test_cursor(), do: &[&1["id"]]

  @doc """
  Retrieves a single one by arbitrary filters.
  Used by:
  * GraphQL Item queries
  * ActivityPub integration
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def one(filters), do: Repo.single(Queries.query(EconomicResource, filters))

  @doc """
  Retrieves a list of them by arbitrary filters.
  Used by:
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def many(filters \\ []), do: {:ok, Repo.all(Queries.query(EconomicResource, filters))}

  def fields(group_fn, filters \\ [])
      when is_function(group_fn, 1) do
    {:ok, fields} = many(filters)
    {:ok, Fields.new(fields, group_fn)}
  end

  @doc """
  Retrieves an Page of resources according to various filters

  Used by:
  * GraphQL resolver single-parent resolution
  """
  def page(cursor_fn, page_opts, base_filters \\ [], data_filters \\ [], count_filters \\ [])

  def page(cursor_fn, %{} = page_opts, base_filters, data_filters, count_filters) do
    base_q = Queries.query(EconomicResource, base_filters)
    data_q = Queries.filter(base_q, data_filters)
    count_q = Queries.filter(base_q, count_filters)

    with {:ok, [data, counts]} <- Repo.transact_many(all: data_q, count: count_q) do
      {:ok, Page.new(data, counts, cursor_fn, page_opts)}
    end
  end

  @doc """
  Retrieves an Pages of resources according to various filters

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
      EconomicResource,
      cursor_fn,
      group_fn,
      page_opts,
      base_filters,
      data_filters,
      count_filters
    )
  end

  def track(%{id: id}) do
    track(id)
  end

  def track(id) when is_binary(id) do
    EconomicEvents.many([:default, track_resource: id])
  end

  def trace(%{id: id}) do
    trace(id)
  end

  def trace(id) when is_binary(id) do
    EconomicEvents.many([:default, trace_resource: id])
  end

  def preload_all(resource) do
    {:ok, resource} = one(id: resource.id, preload: :all)
    preload_state(resource)
  end

  def preload_state(resource) do
    resource |> Map.put(:state, ValueFlows.Knowledge.Action.Actions.action!(resource.state_id))
  end

  ## mutations

  # @spec create(User.t(), attrs :: map) :: {:ok, EconomicResource.t()} | {:error, Changeset.t()}
  def create(%User{} = creator, attrs) when is_map(attrs) do
    Repo.transact_with(fn ->
      attrs = prepare_attrs(attrs, creator)

      with {:ok, resource} <- Repo.insert(EconomicResource.create_changeset(creator, attrs)),
           {:ok, resource} <- ValueFlows.Util.try_tag_thing(creator, resource, attrs),
           act_attrs = %{verb: "created", is_local: true},
           # FIXME
           {:ok, activity} <- Activities.create(creator, resource, act_attrs),
           :ok <- publish(creator, resource, activity, :created) do
        resource = %{resource | creator: creator}
        resource = preload_all(resource)

        index(resource)
        {:ok, resource}
      end
    end)
  end

  # TODO: take the user who is performing the update
  # @spec update(%EconomicResource{}, attrs :: map) :: {:ok, EconomicResource.t()} | {:error, Changeset.t()}
  def update(%EconomicResource{} = resource, attrs) do
    Repo.transact_with(fn ->
      attrs = prepare_attrs(attrs)

      with {:ok, resource} <- Repo.update(EconomicResource.update_changeset(resource, attrs)),
           {:ok, resource} <- ValueFlows.Util.try_tag_thing(nil, resource, attrs),
           :ok <- publish(resource, :updated) do
        {:ok, preload_all(resource)}
      end
    end)
  end

  def soft_delete(%EconomicResource{} = resource) do
    Repo.transact_with(fn ->
      with {:ok, resource} <- Common.Deletion.soft_delete(resource),
           :ok <- publish(resource, :deleted) do
        {:ok, resource}
      end
    end)
  end

  defp publish(creator, resource, activity, :created) do
    feeds = [
      CommonsPub.Feeds.outbox_id(creator),
      Feeds.instance_outbox_id()
    ]

    with :ok <- FeedActivities.publish(activity, feeds) do
      ap_publish("create", resource.id, creator.id)
    end
  end

  defp publish(resource, :updated) do
    # TODO: wrong if edited by admin
    ap_publish("update", resource.id, resource.creator_id)
  end

  defp publish(resource, :deleted) do
    # TODO: wrong if edited by admin
    ap_publish("delete", resource.id, resource.creator_id)
  end

  # FIXME
  defp ap_publish(verb, context_id, user_id) do
    CommonsPub.Workers.APPublishWorker.enqueue(verb, %{
      "context_id" => context_id,
      "user_id" => user_id
    })

    :ok
  end

  def indexing_object_format(obj) do
    # icon = CommonsPub.Uploads.remote_url_from_id(obj.icon_id)
    image = CommonsPub.Uploads.remote_url_from_id(obj.image_id)

    %{
      "index_type" => "EconomicResource",
      "id" => obj.id,
      # "canonicalUrl" => obj.canonical_url,
      # "icon" => icon,
      "image" => image,
      "name" => obj.name,
      "summary" => Map.get(obj, :note),
      "published_at" => obj.published_at,
      "creator" => CommonsPub.Search.Indexer.format_creator(obj)
      # "index_instance" => URI.parse(obj.canonical_url).host, # home instance of object
    }
  end

  defp index(obj) do
    object = indexing_object_format(obj)

    CommonsPub.Search.Indexer.maybe_index_object(object)

    :ok
  end

  defp prepare_attrs(attrs, creator \\ nil) do
    attrs
    |> maybe_put(:primary_accountable_id, attr_get_id(attrs, :primary_accountable) || maybe_get_id(creator))
    |> maybe_put(:context_id,
      attrs |> Map.get(:in_scope_of) |> CommonsPub.Common.maybe(&List.first/1)
    )
    |> maybe_put(:current_location_id, attr_get_id(attrs, :current_location))
    |> maybe_put(:conforms_to_id, attr_get_id(attrs, :conforms_to))
    |> maybe_put(:contained_in_id, attr_get_id(attrs, :contained_in))
    |> maybe_put(:unit_of_effort_id, attr_get_id(attrs, :unit_of_effort))
    |> maybe_put(:state_id, attr_get_id(attrs, :state))
    |> parse_measurement_attrs()
  end

  defp parse_measurement_attrs(attrs) do
    for {k, v} <- attrs, into: %{} do
      v =
        if is_map(v) and Map.has_key?(v, :has_unit) do
          CommonsPub.Common.map_key_replace(v, :has_unit, :unit_id)
        else
          v
        end

      {k, v}
    end
  end
end
