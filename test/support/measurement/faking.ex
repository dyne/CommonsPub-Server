# # SPDX-License-Identifier: AGPL-3.0-only
defmodule Measurement.Test.Faking do
  @moduledoc false

  import Measurement.Simulate

  # import ExUnit.Assertions
  import CommonsPub.Web.Test.GraphQLAssertions
  import CommonsPub.Web.Test.GraphQLFields
  import CommonsPub.Utils.Trendy

  import Grumble

  # alias CommonsPub.Utils.Simulation
  alias Measurement.{Measure, Unit}
  # alias Measurement.Measure.Measures
  # alias Measurement.Unit.Units

  ## Unit

  ### Graphql fields

  def unit_subquery(options \\ []) do
    gen_subquery(:id, :unit, &unit_fields/1, options)
  end

  def unit_query(options \\ []) do
    options = Keyword.put_new(options, :id_type, :id)
    gen_query(:id, &unit_subquery/1, options)
  end

  def unit_fields(extra \\ []) do
    extra ++ ~w(id label symbol)a
  end

  @doc """
  Same as `unit_fields/1`, but with the parameter being nested inside of
  another type.
  """
  def unit_response_fields(extra \\ []) do
    [unit: unit_fields(extra)]
  end

  def units_query(options \\ []) do
    params =
      [
        after: list_type(:cursor),
        before: list_type(:cursor),
        limit: :int
      ] ++ Keyword.get(options, :params, [])

    gen_query(&units_subquery/1, [{:params, params} | options])
  end

  def units_subquery(options \\ []) do
    args = [
      after: var(:after),
      before: var(:before),
      limit: var(:limit)
    ]

    page_subquery(
      :units_pages,
      &unit_fields/1,
      [{:args, args} | options]
    )
  end

  def create_unit_mutation(options \\ []) do
    [unit: type!(:unit_create_params)]
    |> gen_mutation(&create_unit_submutation/1, options)
  end

  def create_unit_submutation(options \\ []) do
    [unit: var(:unit)]
    |> gen_submutation(:create_unit, &unit_response_fields/1, options)
  end

  def update_unit_mutation(options \\ []) do
    [unit: type!(:unit_update_params)]
    |> gen_mutation(&update_unit_submutation/1, options)
  end

  def update_unit_submutation(options \\ []) do
    [unit: var(:unit)]
    |> gen_submutation(:update_unit, &unit_response_fields/1, options)
  end

  def delete_unit_mutation(options \\ []) do
    [id: type!(:id)]
    |> gen_mutation(&delete_unit_submutation/1, options)
  end

  def delete_unit_submutation(_options \\ []) do
    field(:delete_unit, args: [id: var(:id)])
  end

  ### Unit assertion

  def assert_unit(unit) do
    assert_object(unit, :assert_unit,
      id: &assert_ulid/1,
      label: &assert_binary/1,
      symbol: &assert_binary/1
    )
  end

  def assert_unit(%Unit{} = unit, %{id: _} = unit2) do
    assert_units_eq(unit, unit2)
  end

  def assert_unit(%Unit{} = unit, %{} = unit2) do
    assert_units_eq(unit, assert_unit(unit2))
  end

  def assert_units_eq(%Unit{} = unit, %{} = unit2) do
    assert_maps_eq(unit, unit2, :assert_unit, [:id, :label, :symbol])
    unit2
  end

  def some_fake_units!(opts \\ %{}, some_arg, users, communities) do
    flat_pam_product_some(users, communities, some_arg, &fake_unit!(&1, &2, opts))
  end

  ## Measures

  def measure_fields(extra \\ []) do
    extra ++ ~w(id has_numerical_value)a
  end

  @doc """
  Same as `measure_fields/1`, but with the parameter being nested inside of
  another type.
  """
  def measure_response_fields(extra \\ []) do
    [measure: measure_fields(extra)]
  end

  def measure_subquery(options \\ []) do
    gen_subquery(:id, :measure, &measure_fields/1, options)
  end

  def measure_query(options \\ []) do
    options = Keyword.put_new(options, :id_type, :id)
    gen_query(:id, &measure_subquery/1, options)
  end

  def measures_pages_query(options \\ []) do
    params =
      [
        after: list_type(:cursor),
        before: list_type(:cursor),
        limit: :int
      ] ++ Keyword.get(options, :params, [])

    gen_query(&measures_pages_subquery/1, [{:params, params} | options])
  end

  def measures_pages_subquery(options \\ []) do
    args = [
      after: var(:after),
      before: var(:before),
      limit: var(:limit)
    ]

    page_subquery(
      :measures_pages,
      &measure_fields/1,
      [{:args, args} | options]
    )
  end


  def create_measure_mutation(options \\ []) do
    [measure: type!(:measure_create_params)]
    |> gen_mutation(&create_measure_submutation/1, options)
  end

  def create_measure_submutation(options \\ []) do
    [measure: var(:measure)]
    |> gen_submutation(:create_measure, &measure_response_fields/1, options)
  end

  def create_measure_with_unit_mutation(options \\ []) do
    [measure: type!(:measure_create_params), has_unit: type!(:id)]
    |> gen_mutation(&create_measure_with_unit_submutation/1, options)
  end

  def create_measure_with_unit_submutation(options \\ []) do
    [measure: var(:measure), has_unit: var(:has_unit)]
    |> gen_submutation(:create_measure, &measure_response_fields/1, options)
  end

  def update_measure_mutation(options \\ []) do
    [measure: type!(:measure_update_params)]
    |> gen_mutation(&update_measure_submutation/1, options)
  end

  def update_measure_submutation(options \\ []) do
    [measure: var(:measure)]
    |> gen_submutation(:update_measure, &measure_response_fields/1, options)
  end

  def assert_measure(%Measure{} = measure) do
    assert_measure(Map.from_struct(measure))
  end

  def assert_measure(measure) do
    assert_object(measure, :assert_measure, has_numerical_value: &assert_float/1)
  end

  def assert_measure(%Measure{} = measure, %{} = measure2) do
    assert_measures_eq(measure, assert_measure(measure2))
  end

  def assert_measures_eq(%Measure{} = measure, %{} = measure2) do
    assert_maps_eq(measure, measure2, :assert_measure, [
      :has_numerical_value,
      :published_at,
      :disabled_at
    ])
  end
end
