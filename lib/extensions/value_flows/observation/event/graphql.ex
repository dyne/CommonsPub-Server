# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Observation.EconomicEvent.GraphQL do
  # default to 100 km radius
  @radius_default_distance 100_000

  require Logger

  alias CommonsPub.{GraphQL, Repo}

  alias CommonsPub.GraphQL.{
    ResolveField,
    ResolvePages,
    ResolveRootPage,
    FetchPage
  }

  alias ValueFlows.Observation.EconomicEvent
  alias ValueFlows.Observation.EconomicEvent.EconomicEvents
  alias ValueFlows.Observation.EconomicEvent.Queries
  alias CommonsPub.Web.GraphQL.UploadResolver

  ## resolvers

  def simulate(%{id: _id}, _) do
    {:ok, ValueFlows.Simulate.economic_event()}
  end

  def simulate(_, _) do
    {:ok, CommonsPub.Utils.Trendy.some(1..5, &ValueFlows.Simulate.economic_event/0)}
  end

  def event(%{id: id}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_event,
      context: id,
      info: info
    })
  end

  def events(page_opts, info) do
    ResolveRootPage.run(%ResolveRootPage{
      module: __MODULE__,
      fetcher: :fetch_events,
      page_opts: page_opts,
      info: info,
      # popularity
      cursor_validators: [&(is_integer(&1) and &1 >= 0), &Ecto.ULID.cast/1]
    })
  end

  def all_events(_, _) do
    EconomicEvents.many([:default])
  end

  def events_filtered(page_opts, _ \\ nil) do
    events_filter(page_opts, [])
  end

  # TODO: support several filters combined, plus pagination on filtered queries

  defp events_filter(%{agent: id} = page_opts, filters_acc) do
    events_filter_next(:agent, [agent_id: id], page_opts, filters_acc)
  end

  defp events_filter(%{provider: id} = page_opts, filters_acc) do
    events_filter_next(:provider, [provider_id: id], page_opts, filters_acc)
  end

  defp events_filter(%{receiver: id} = page_opts, filters_acc) do
    events_filter_next(:receiver, [receiver_id: id], page_opts, filters_acc)
  end

  defp events_filter(%{action: id} = page_opts, filters_acc) do
    events_filter_next(:action, [action_id: id], page_opts, filters_acc)
  end

  defp events_filter(%{in_scope_of: context_id} = page_opts, filters_acc) do
    events_filter_next(:in_scope_of, [context_id: context_id], page_opts, filters_acc)
  end

  defp events_filter(%{tag_ids: tag_ids} = page_opts, filters_acc) do
    events_filter_next(:tag_ids, [tag_ids: tag_ids], page_opts, filters_acc)
  end

  defp events_filter(%{at_location: at_location_id} = page_opts, filters_acc) do
    events_filter_next(:at_location, [at_location_id: at_location_id], page_opts, filters_acc)
  end

  defp events_filter(
         %{
           geolocation: %{
             near_point: %{lat: lat, long: long},
             distance: %{meters: distance_meters}
           }
         } = page_opts,
         filters_acc
       ) do
    events_filter_next(
      :geolocation,
      {
        :near_point,
        %Geo.Point{coordinates: {lat, long}, srid: 4326},
        :distance_meters,
        distance_meters
      },
      page_opts,
      filters_acc
    )
  end

  defp events_filter(
         %{
           geolocation: %{near_address: address} = geolocation
         } = page_opts,
         filters_acc
       ) do
    with {:ok, coords} <- Geocoder.call(address) do
      events_filter(
        Map.merge(
          page_opts,
          %{
            geolocation:
              Map.merge(geolocation, %{
                near_point: %{lat: coords.lat, long: coords.lon},
                distance: Map.get(geolocation, :distance, %{meters: @radius_default_distance})
              })
          }
        ),
        filters_acc
      )
    else
      _ ->
        events_filter_next(
          :geolocation,
          [],
          page_opts,
          filters_acc
        )
    end
  end

  defp events_filter(
         %{
           geolocation: geolocation
         } = page_opts,
         filters_acc
       ) do
    events_filter(
      Map.merge(
        page_opts,
        %{
          geolocation:
            Map.merge(geolocation, %{
              # default to 100 km radius
              distance: %{meters: @radius_default_distance}
            })
        }
      ),
      filters_acc
    )
  end

  defp events_filter(
         _,
         filters_acc
       ) do
    # finally, if there's no more known params to acumulate, query with the filters
    EconomicEvents.many(filters_acc)
  end

  defp events_filter_next(param_remove, filter_add, page_opts, filters_acc)
       when is_list(param_remove) and is_list(filter_add) do
    events_filter(Map.drop(page_opts, param_remove), filters_acc ++ filter_add)
  end

  defp events_filter_next(param_remove, filter_add, page_opts, filters_acc)
       when not is_list(filter_add) do
    events_filter_next(param_remove, [filter_add], page_opts, filters_acc)
  end

  defp events_filter_next(param_remove, filter_add, page_opts, filters_acc)
       when not is_list(param_remove) do
    events_filter_next([param_remove], filter_add, page_opts, filters_acc)
  end

  def track(event, _, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_track,
      context: event,
      info: info
    })
  end

  def trace(event, _, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_trace,
      context: event,
      info: info
    })
  end

  ## fetchers

  def fetch_event(info, id) do
    EconomicEvents.one([
      :default,
      user: GraphQL.current_user(info),
      id: id
      # preload: :tags
    ])
  end

  def agent_events(%{id: agent}, %{} = _page_opts, _info) do
    events_filtered(%{agent: agent})
  end

  def agent_events(_, _page_opts, _info) do
    {:ok, nil}
  end

  def agent_events_edge(%{agent: agent}, %{} = page_opts, info) do
    ResolvePages.run(%ResolvePages{
      module: __MODULE__,
      fetcher: :fetch_agent_events_edge,
      context: agent,
      page_opts: page_opts,
      info: info
    })
  end

  def fetch_agent_events_edge(page_opts, info, ids) do
    list_events(
      page_opts,
      [
        :default,
        agent_id: ids,
        user: GraphQL.current_user(info)
      ],
      nil,
      nil
    )
  end

  def list_events(page_opts, base_filters, _data_filters, _cursor_type) do
    FetchPage.run(%FetchPage{
      queries: Queries,
      query: EconomicEvent,
      page_opts: page_opts,
      base_filters: base_filters
    })
  end

  def fetch_events(page_opts, info) do
    FetchPage.run(%FetchPage{
      queries: ValueFlows.Observation.EconomicEvent.Queries,
      query: ValueFlows.Observation.EconomicEvent,
      page_opts: page_opts,
      cursor_fn:  & &1.id,
      base_filters: [
        :default,
        user: GraphQL.current_user(info)
      ]
    })
  end

  def fetch_resource_inventoried_as_edge(%{resource_inventoried_as: {:error, _} = error}, _, _),
    do: error

  def fetch_resource_inventoried_as_edge(%{resource_inventoried_as_id: id} = thing, _, _)
      when not is_nil(id) do
    thing = Repo.preload(thing, :resource_inventoried_as)
    {:ok, Map.get(thing, :resource_inventoried_as)}
  end

  def fetch_resource_inventoried_as_edge(_, _, _) do
    {:ok, nil}
  end

  def fetch_to_resource_inventoried_as_edge(%{to_resource_inventoried_as: {:error, _} = error}, _, _),
   do: error

  def fetch_to_resource_inventoried_as_edge(%{to_resource_inventoried_as_id: id} = thing, _, _)
    when not is_nil(id) do
      thing = Repo.preload(thing, :to_resource_inventoried_as)
      {:ok, Map.get(thing, :to_resource_inventoried_as)}
  end

  def fetch_to_resource_inventoried_as_edge(_, _, _) do
    {:ok, nil}
  end

  def fetch_output_of_edge(%{output_of_id: id} = thing, _, _) when is_binary(id) do
    thing = Repo.preload(thing, :output_of)
    {:ok, Map.get(thing, :output_of)}
  end

  def fetch_output_of_edge(_, _, _) do
    {:ok, nil}
  end

  def fetch_input_of_edge(%{input_of_id: id} = thing, _, _) when is_binary(id) do
    thing = Repo.preload(thing, :input_of)
    {:ok, Map.get(thing, :input_of)}
  end

  def fetch_input_of_edge(_, _, _) do
    {:ok, nil}
  end

  def fetch_triggered_by_edge(%{triggered_by_id: id} = thing, _, _) when is_binary(id) do
    thing = Repo.preload(thing, :triggered_by)
    {:ok, Map.get(thing, :triggered_by)}
  end

  def fetch_triggered_by_edge(_, _, _) do
    {:ok, nil}
  end

  def fetch_track(_, event) do
    EconomicEvents.track(event)
  end

  def fetch_trace(_, event) do
    EconomicEvents.trace(event)
  end

  # Mutations

  def create_event(%{event: event_attrs} = params, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, uploads} <- UploadResolver.upload(user, event_attrs, info),
           event_attrs = Map.merge(event_attrs, uploads),
           event_attrs = Map.merge(event_attrs, %{is_public: true}),
           {:ok, event, new_resource} <- EconomicEvents.create(user, event_attrs, params) do
        {:ok, %{economic_event: event, economic_resource: new_resource}}
      end
    end)
  end

  def update_event(%{event: %{id: id} = changes}, info) do
    with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
         {:ok, event} <- event(%{id: id}, info),
         :ok <- ensure_update_permission(user, event),
         {:ok, uploads} <- UploadResolver.upload(user, changes, info),
         changes = Map.merge(changes, uploads),
         {:ok, event} <- EconomicEvents.update(event, changes) do
      {:ok, %{economic_event: event}}
    end
  end

  def delete_event(%{id: id}, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, event} <- event(%{id: id}, info),
           :ok <- ensure_update_permission(user, event),
           {:ok, _} <- EconomicEvents.soft_delete(event) do
        {:ok, true}
      end
    end)
  end

  def ensure_update_permission(user, event) do
    if user.local_user.is_instance_admin or event.creator_id == user.id do
      :ok
    else
      GraphQL.not_permitted("update")
    end
  end

  # defp validate_agent(pointer) do
  #   if Pointers.table!(pointer).schema in valid_contexts() do
  #     :ok
  #   else
  #     GraphQL.not_permitted()
  #   end
  # end

  # defp valid_contexts() do
  #   [User, Community, Organisation]
  #   # Keyword.fetch!(CommonsPub.Config.get(Threads), :valid_contexts)
  # end
end
