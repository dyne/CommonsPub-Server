# SPDX-License-Identifier: AGPL-3.0-only
defmodule Geolocation.GraphQL do
  use Absinthe.Schema.Notation
  require Logger

  alias CommonsPub.{
    # Activities,
    GraphQL,
    Repo
  }

  alias CommonsPub.GraphQL.{
    # ResolvePage,
    # ResolvePages,
    ResolveField,
    # ResolveFields,
    ResolveRootPage,
    FetchPage
    # FetchPages,
    # CommonResolver
  }

  # alias CommonsPub.Resources.Resource
  # alias CommonsPub.Common.Enums

  alias Geolocation
  alias Geolocation.Geolocations
  alias Geolocation.Queries
  alias Organisation

  # SDL schema import

  import_sdl(path: "lib/extensions/geolocations/geolocation.gql")

  ## resolvers

  def geolocation(%{id: id}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_geolocation,
      context: id,
      info: info
    })
  end

  def all_geolocations(_page_opts, _info) do
    Geolocations.many()
  end

  def geolocations(page_opts, info) do
    ResolveRootPage.run(%ResolveRootPage{
      module: __MODULE__,
      fetcher: :fetch_geolocations,
      page_opts: page_opts,
      info: info,
      # popularity
      cursor_validators: [&(is_integer(&1) and &1 >= 0), &Ecto.ULID.cast/1]
    })
  end

  ## fetchers

  def fetch_geolocation(info, id) do
    with {:ok, geo} <-
           Geolocations.one(user: GraphQL.current_user(info), id: id, preload: :character) do
      {:ok, Geolocations.populate_coordinates(geo)}
    end
  end

  def fetch_geolocations(page_opts, info) do
    page_result =
      FetchPage.run(%FetchPage{
        queries: Queries,
        query: Geolocation,
        cursor_fn: Geolocations.cursor(:followers),
        page_opts: page_opts,
        base_filters: [user: GraphQL.current_user(info)],
        data_filters: [page: [desc: [followers: page_opts]]]
      })

    with {:ok, %{edges: edges} = page} <- page_result do
      edges = Enum.map(edges, &Geolocations.populate_coordinates/1)
      {:ok, %{page | edges: edges}}
    end
  end

  def last_activity_edge(_, _, _info) do
    {:ok, DateTime.utc_now()}
  end



  defp default_outbox_query_contexts() do
    CommonsPub.Config.get!(Geolocations)
    |> Keyword.fetch!(:default_outbox_query_contexts)
  end

  ## finally the mutations...

  def create_geolocation(%{spatial_thing: attrs, in_scope_of: context_id}, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, pointer} <- CommonsPub.Meta.Pointers.one(id: context_id),
           context = CommonsPub.Meta.Pointers.follow!(pointer),
           attrs = Map.merge(attrs, %{is_public: true}),
           {:ok, g} <- Geolocations.create(user, context, attrs) do
        {:ok, %{spatial_thing: g}}
      end
    end)
  end

  def create_geolocation(%{spatial_thing: attrs}, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           attrs = Map.merge(attrs, %{is_public: true}),
           {:ok, g} <- Geolocations.create(user, attrs) do
        {:ok, %{spatial_thing: g}}
      end
    end)
  end

  def update_geolocation(%{spatial_thing: %{id: id} = changes}, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, geolocation} <- geolocation(%{id: id}, info),
           :ok <- ensure_update_allowed(user, geolocation),
           {:ok, geo} <- Geolocations.update(user, geolocation, changes) do
        {:ok, %{spatial_thing: geo}}
      end
    end)
  end

  def ensure_update_allowed(user, geo) do
    if user.local_user.is_instance_admin or geo.creator_id == user.id do
      :ok
    else
      GraphQL.not_permitted("update")
    end
  end

  def delete_geolocation(%{id: id}, info) do
    with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
         {:ok, geo} <- geolocation(%{id: id}, info),
         :ok <- ensure_delete_allowed(user, geo),
         {:ok, _geo} <- Geolocations.soft_delete(user, geo) do
      {:ok, true}
    end
  end

  def ensure_delete_allowed(user, geo) do
    if user.local_user.is_instance_admin or geo.creator_id == user.id do
      :ok
    else
      GraphQL.not_permitted("delete")
    end
  end
end
