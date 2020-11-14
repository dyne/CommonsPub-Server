# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Planning.Intent.GraphQL do
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

  alias ValueFlows.Planning.Intent
  alias ValueFlows.Planning.Intent.Intents
  alias ValueFlows.Planning.Intent.Queries
  alias CommonsPub.Web.GraphQL.UploadResolver

  ## resolvers

  def intent(%{id: id}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_intent,
      context: id,
      info: info
    })
  end

  def intents(page_opts, info) do
    ResolveRootPage.run(%ResolveRootPage{
      module: __MODULE__,
      fetcher: :fetch_intents,
      page_opts: page_opts,
      info: info,
      # popularity
      cursor_validators: [&(is_integer(&1) and &1 >= 0), &Ecto.ULID.cast/1]
    })
  end

  def all_intents(_, _) do
    Intents.many([:default])
  end

  def intents_filtered(page_opts, _ \\ nil) do
    intents_filter(page_opts, [])
  end

  # def intents_filtered(page_opts, _) do
  #   IO.inspect(unhandled_filtering: page_opts)
  #   all_intents(page_opts, nil)
  # end

  # TODO: support several filters combined, plus pagination on filtered queries

  defp intents_filter(%{agent: id} = page_opts, filters_acc) do
    intents_filter_next(:agent, [agent_id: id], page_opts, filters_acc)
  end

  defp intents_filter(%{provider: id} = page_opts, filters_acc) do
    intents_filter_next(:provider, [provider_id: id], page_opts, filters_acc)
  end

  defp intents_filter(%{receiver: id} = page_opts, filters_acc) do
    intents_filter_next(:receiver, [receiver_id: id], page_opts, filters_acc)
  end

  defp intents_filter(%{action: id} = page_opts, filters_acc) do
    intents_filter_next(:action, [action_id: id], page_opts, filters_acc)
  end

  defp intents_filter(%{in_scope_of: context_id} = page_opts, filters_acc) do
    intents_filter_next(:in_scope_of, [context_id: context_id], page_opts, filters_acc)
  end

  defp intents_filter(%{tag_ids: tag_ids} = page_opts, filters_acc) do
    intents_filter_next(:tag_ids, [tag_ids: tag_ids], page_opts, filters_acc)
  end

  defp intents_filter(%{at_location: at_location_id} = page_opts, filters_acc) do
    intents_filter_next(:at_location, [at_location_id: at_location_id], page_opts, filters_acc)
  end

  defp intents_filter(
         %{
           geolocation: %{
             near_point: %{lat: lat, long: long},
             distance: %{meters: distance_meters}
           }
         } = page_opts,
         filters_acc
       ) do
    intents_filter_next(
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

  defp intents_filter(
         %{
           geolocation: %{near_address: address} = geolocation
         } = page_opts,
         filters_acc
       ) do
    with {:ok, coords} <- Geocoder.call(address) do

      intents_filter(
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
        intents_filter_next(
          :geolocation,
          [],
          page_opts,
          filters_acc
        )
    end
  end

  defp intents_filter(
         %{
           geolocation: geolocation
         } = page_opts,
         filters_acc
       ) do
    intents_filter(
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

  defp intents_filter(
         _,
         filters_acc
       ) do
    # finally, if there's no more known params to acumulate, query with the filters
    Intents.many(filters_acc)
  end

  defp intents_filter_next(param_remove, filter_add, page_opts, filters_acc)
       when is_list(param_remove) and is_list(filter_add) do
    intents_filter(Map.drop(page_opts, param_remove), filters_acc ++ filter_add)
  end

  defp intents_filter_next(param_remove, filter_add, page_opts, filters_acc)
       when not is_list(filter_add) do
    intents_filter_next(param_remove, [filter_add], page_opts, filters_acc)
  end

  defp intents_filter_next(param_remove, filter_add, page_opts, filters_acc)
       when not is_list(param_remove) do
    intents_filter_next([param_remove], filter_add, page_opts, filters_acc)
  end

  def offers(page_opts, info) do
    ResolveRootPage.run(%ResolveRootPage{
      module: __MODULE__,
      fetcher: :fetch_offers,
      page_opts: page_opts,
      info: info,
      # popularity
      cursor_validators: [&(is_integer(&1) and &1 >= 0), &Ecto.ULID.cast/1]
    })
  end

  def needs(page_opts, info) do
    ResolveRootPage.run(%ResolveRootPage{
      module: __MODULE__,
      fetcher: :fetch_needs,
      page_opts: page_opts,
      info: info,
      # popularity
      cursor_validators: [&(is_integer(&1) and &1 >= 0), &Ecto.ULID.cast/1]
    })
  end

  ## fetchers

  def fetch_intent(info, id) do
    Intents.one([
      :default,
      user: GraphQL.current_user(info),
      id: id
      # preload: :tags
    ])
  end

  def agent_intents(%{id: agent}, %{} = _page_opts, _info) do
    intents_filtered(%{agent: agent})
  end

  def agent_intents(_, _page_opts, _info) do
    {:ok, nil}
  end

  def provider_intents(%{id: provider}, %{} = _page_opts, _info) do
    intents_filtered(%{provider: provider})
  end

  def provider_intents(_, _page_opts, _info) do
    {:ok, nil}
  end

  def agent_intents_edge(%{id: agent}, %{} = page_opts, info) do
    ResolvePages.run(%ResolvePages{
      module: __MODULE__,
      fetcher: :fetch_agent_intents_edge,
      context: agent,
      page_opts: page_opts,
      info: info
    })
  end

  def fetch_agent_intents_edge(page_opts, info, ids) do
    list_intents(
      page_opts,
      [
        :default,
        agent_id: ids,
        user: GraphQL.current_user(info)
      ]
    )
  end

  def provider_intents_edge(%{id: provider}, %{} = page_opts, info) do
    ResolvePages.run(%ResolvePages{
      module: __MODULE__,
      fetcher: :fetch_provider_intents_edge,
      context: provider,
      page_opts: page_opts,
      info: info
    })
  end

  def fetch_provider_intents_edge(page_opts, info, ids) do
    list_intents(
      page_opts,
      [
        :default,
        provider_id: ids,
        user: GraphQL.current_user(info)
      ]
    )
  end

  def fetch_resource_inventoried_as_edge(%{resource_inventoried_as_id: id} = thing, _, _)
      when is_binary(id) do
    thing = Repo.preload(thing, :resource_inventoried_as)
    {:ok, Map.get(thing, :resource_inventoried_as)}
  end

  def fetch_resource_inventoried_as_edge(_, _, _) do
    {:ok, nil}
  end

  def fetch_input_of_edge(%{input_of_id: id} = thing, _, _)
      when is_binary(id) do
    thing = Repo.preload(thing, :input_of)
    {:ok, Map.get(thing, :input_of)}
  end

  def fetch_input_of_edge(_, _, _) do
    {:ok, nil}
  end

  def fetch_output_of_edge(%{output_of_id: id} = thing, _, _)
      when is_binary(id) do
    thing = Repo.preload(thing, :output_of)
    {:ok, Map.get(thing, :output_of)}
  end

  def fetch_output_of_edge(_, _, _) do
    {:ok, nil}
  end

  def list_intents(page_opts, base_filters) do
    FetchPage.run(%FetchPage{
      queries: Queries,
      query: Intent,
      # cursor_fn: Intents.cursor(cursor_type),
      page_opts: page_opts,
      base_filters: base_filters
      # data_filters: data_filters
    })
  end

  def fetch_intents(page_opts, info) do
    list_intents(
      page_opts,
      [:default, user: GraphQL.current_user(info)]
    )
  end

  def fetch_offers(page_opts, info) do
    list_intents(
      page_opts,
      [:default, :offer, user: GraphQL.current_user(info)]
    )
  end

  def fetch_needs(page_opts, info) do
    list_intents(
      page_opts,
      [:default, :need, user: GraphQL.current_user(info)]
    )
  end

  def create_offer(%{intent: intent_attrs}, info) do
    with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info) do
      create_intent(
        %{intent: Map.put(intent_attrs, :provider, user.id)},
        info
      )
    end
  end

  def create_need(%{intent: intent_attrs}, info) do
    with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info) do
      create_intent(
        %{intent: Map.put(intent_attrs, :receiver, user.id)},
        info
      )
    end
  end

  def create_intent(%{intent: intent_attrs}, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, uploads} <- UploadResolver.upload(user, intent_attrs, info),
           intent_attrs = Map.merge(intent_attrs, uploads),
           intent_attrs = Map.merge(intent_attrs, %{is_public: true}),
           {:ok, intent} <- Intents.create(user, intent_attrs) do
        {:ok, %{intent: intent}}
      end
    end)
  end

  def update_intent(%{intent: %{id: id} = changes}, info) do
    with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
         {:ok, intent} <- intent(%{id: id}, info),
         :ok <- ensure_update_permission(user, intent),
         {:ok, uploads} <- UploadResolver.upload(user, changes, info),
         changes = Map.merge(changes, uploads),
         {:ok, intent} <- Intents.update(intent, changes) do
      {:ok, %{intent: intent}}
    end
  end

  def delete_intent(%{id: id}, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, intent} <- intent(%{id: id}, info),
           :ok <- ensure_update_permission(user, intent),
           {:ok, _} <- Intents.soft_delete(intent) do
        {:ok, true}
      end
    end)
  end

  def ensure_update_permission(user, intent) do
    if user.local_user.is_instance_admin or intent.creator_id == user.id do
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
