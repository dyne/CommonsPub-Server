# SPDX-License-Identifier: AGPL-3.0-only
defmodule Measurement.Measure.GraphQL do
  use Absinthe.Schema.Notation

  alias CommonsPub.{GraphQL, Repo}

  alias CommonsPub.GraphQL.{
    ResolveField,
    ResolveFields,
    # ResolvePage,
    # ResolvePages,
    ResolveRootPage,
    FetchPage,
    # FetchPages,
    FetchFields
  }

  alias Measurement.Measure.Measures
  alias Measurement.Unit.Units

  # resolvers

  def measure(%{id: id}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_measure,
      context: id,
      info: info
    })
  end

  def measures_pages(page_opts, info) do
    ResolveRootPage.run(%ResolveRootPage{
      module: __MODULE__,
      fetcher: :fetch_measures,
      page_opts: page_opts,
      info: info,
      cursor_validators: [&(is_integer(&1) and &1 >= 0), &Ecto.ULID.cast/1]
    })
  end

  # fetchers

  def fetch_measure(info, id) do
    Measures.one([
      :default,
      user: GraphQL.current_user(info),
      id: id
    ])
  end

  def fetch_measures(page_opts, info) do
    FetchPage.run(%FetchPage{
      queries: Measurement.Measure.Queries,
      query: Measurement.Measure,
      cursor_fn:  & &1.id,
      page_opts: page_opts,
      base_filters: [user: GraphQL.current_user(info)],
      data_filters: [:default]
    })
  end

  def has_unit_edge(%{unit_id: id}, _, info) do
    ResolveFields.run(%ResolveFields{
      module: __MODULE__,
      fetcher: :fetch_has_unit_edge,
      context: id,
      info: info
    })
  end

  def has_unit_edge(_, _, info) do
    {:ok, nil}
  end

  def fetch_has_unit_edge(_, ids) do
    FetchFields.run(%FetchFields{
      queries: Measurement.Unit.Queries,
      query: Measurement.Unit,
      group_fn: & &1.id,
      filters: [:deleted, :private, id: ids]
    })
  end

  # mutations

  def create_measures(attrs, info, fields) do
    Repo.transact_with(fn ->
      attrs
      |> Map.take(fields)
      |> map_ok_error(&create_measure(&1, info))
    end)
  end

  def update_measures(attrs, info, fields) do
    Repo.transact_with(fn ->
      attrs
      |> Map.take(fields)
      |> map_ok_error(fn
        %{id: id} = measure when is_binary(id) ->
          update_measure(measure, info)

        measure ->
          create_measure(measure, info)
      end)
    end)
  end

  # TODO: move to a generic module
  @doc """
  Iterate over a set of elements in a map calling `func`.

  `func` is expected to return either one of `{:ok, val}` or `{:error, reason}`.
  If `{:error, reason}` is returned, iteration halts.
  """
  @spec map_ok_error(items, func) :: {:ok, any} | {:error, term}
        when items: [Map.t()],
             func: (Map.t(), any -> {:ok, any} | {:error, term})
  def map_ok_error(items, func) do
    Enum.reduce_while(items, %{}, fn {field_name, item}, acc ->
      case func.(item) do
        {:ok, val} ->
          {:cont, Map.put(acc, field_name, val)}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:error, _} = e -> e
      val -> {:ok, Enum.into(val, %{})}
    end
  end

  def create_measure(%{has_unit: unit_id} = attrs, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, unit} <- Units.one(user: user, id: unit_id),
           {:ok, measure} <- Measures.create(user, unit, attrs) do
        {:ok, %{measure | unit: unit, creator: user}}
      end
    end)
  end

  def update_measure(%{id: id} = changes, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, measure} <- measure(%{id: id}, info) do
        cond do
          user.local_user.is_instance_admin ->
            {:ok, m} = Measures.update(measure, changes)
            {:ok, %{measure: m}}

          measure.creator_id == user.id ->
            {:ok, m} = Measures.update(measure, changes)
            {:ok, %{measure: m}}

          true ->
            GraphQL.not_permitted("update")
        end
      end
    end)
  end
end
