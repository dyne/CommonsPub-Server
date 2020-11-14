# SPDX-License-Identifier: AGPL-3.0-only
defmodule Measurement.Unit.GraphQL do
  use Absinthe.Schema.Notation
  require Logger

  alias CommonsPub.{
    # Activities,
    GraphQL,
    Repo
  }

  alias CommonsPub.GraphQL.{
    # CommonResolver,
    ResolveField,
    # ResolveFields,
    # ResolvePage,
    # ResolvePages,
    ResolveRootPage,
    FetchPage
    # FetchPages
  }

  # alias CommonsPub.Resources.Resource
  # alias CommonsPub.Common.Enums
  alias CommonsPub.Meta.Pointers

  # alias ValueFlows.Simulate
  alias Measurement.Unit
  alias Measurement.Unit.Units
  alias Measurement.Unit.Queries
  alias Measurement.Measure.Measures

  import_sdl(path: "lib/extensions/measurements/measurement.gql")

  ## resolvers

  def unit(%{id: id}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_unit,
      context: id,
      info: info
    })
  end

  def all_units(_, _) do
    {:error, "Use unitsPages instead."}
  end

  def units(page_opts, info) do
    ResolveRootPage.run(%ResolveRootPage{
      module: __MODULE__,
      fetcher: :fetch_units,
      page_opts: page_opts,
      info: info,
      # popularity
      cursor_validators: [&(is_integer(&1) and &1 >= 0), &Ecto.ULID.cast/1]
    })
  end

  ## fetchers

  def fetch_unit(info, id) do
    Units.one([
      :default,
      user: GraphQL.current_user(info),
      id: id
    ])
  end

  # FIXME
  def fetch_units(page_opts, info) do
    FetchPage.run(%FetchPage{
      queries: Queries,
      query: Unit,
      cursor_fn: & &1.id,
      page_opts: page_opts,
      base_filters: [:default, user: GraphQL.current_user(info)]
    })
  end


  def create_unit(%{unit: %{in_scope_of: context_id} = attrs}, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, pointer} <- CommonsPub.Meta.Pointers.one(id: context_id),
           :ok <- validate_unit_context(pointer),
           context = CommonsPub.Meta.Pointers.follow!(pointer),
           attrs = Map.merge(attrs, %{is_public: true}),
           {:ok, unit} <- Units.create(user, context, attrs) do
        {:ok, %{unit: unit}}
      end
    end)
  end

  # without context/scope
  def create_unit(%{unit: attrs} = _params, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           attrs = Map.merge(attrs, %{is_public: true}),
           {:ok, unit} <- Units.create(user, attrs) do
        {:ok, %{unit: unit}}
      end
    end)
  end

  def update_unit(%{unit: %{id: id} = changes}, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, unit} <- unit(%{id: id}, info) do
        cond do
          user.local_user.is_instance_admin ->
            {:ok, u} = Units.update(unit, changes)
            {:ok, %{unit: u}}

          unit.creator_id == user.id ->
            {:ok, u} = Units.update(unit, changes)
            {:ok, %{unit: u}}

          true ->
            GraphQL.not_permitted("update")
        end
      end
    end)
  end

  def delete_unit(%{id: id}, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, unit} <- unit(%{id: id}, info) do
        if allow_delete?(user, unit) do
          with {:ok, _} <- Units.soft_delete(unit) do
            {:ok, true}
          end
        else
          GraphQL.not_permitted("delete")
        end
      end
    end)
  end

  defp allow_delete?(user, unit) do
    not dependent_measures?(unit) and allow_user_delete?(user, unit)
  end

  defp allow_user_delete?(user, unit) do
    user.local_user.is_instance_admin or unit.creator_id == user.id
  end

  # TODO: provide a more helpful error message
  defp dependent_measures?(%Unit{id: unit_id} = unit) do
    {:ok, measures} = Measures.many([:default, group_count: :unit_id, unit: unit])

    n_measures =
      case measures do
        [{^unit_id, n_measures}] -> n_measures
        [] -> 0
      end

    n_measures > 0
  end

  # TEMP
  # def all_units(_, _, _) do
  #   {:ok, long_list(&Simulate.unit/0)}
  # end

  # def a_unit(%{id: id}, info) do
  #   {:ok, Simulate.unit()}
  # end

  # context validation

  defp validate_unit_context(pointer) do
    if Pointers.table!(pointer).schema in valid_contexts() do
      :ok
    else
      GraphQL.not_permitted("in_scope_of")
    end
  end

  defp valid_contexts do
    Keyword.fetch!(CommonsPub.Config.get!(Units), :valid_contexts)
  end
end
