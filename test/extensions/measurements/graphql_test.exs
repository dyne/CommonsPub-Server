# SPDX-License-Identifier: AGPL-3.0-only
defmodule Measurement.GraphQLTest do
  use CommonsPub.Web.ConnCase, async: true

  import CommonsPub.Utils.Simulation
  import Measurement.Test.Faking
  import CommonsPub.Utils.Trendy

  import Measurement.Simulate
  alias Measurement.Measure.Measures
  alias Measurement.Unit.Units

  describe "unit" do
    test "fetches an existing unit by ID" do
      user = fake_user!()
      unit = fake_unit!(user)

      q = unit_query()
      conn = user_conn(user)
      assert_unit(grumble_post_key(q, conn, :unit, %{id: unit.id}))
    end

    test "fails for deleted units" do
      user = fake_user!()
      unit = fake_unit!(user)
      assert {:ok, unit} = Units.soft_delete(unit)

      q = unit_query()
      conn = user_conn(user)
      assert [%{"status" => 404}] = grumble_post_errors(q, conn, %{id: unit.id})
    end

    test "fails if ID is missing" do
      user = fake_user!()
      q = unit_query()
      conn = user_conn(user)
      vars = %{id: Ecto.ULID.generate()}
      assert [%{"status" => 404}] = grumble_post_errors(q, conn, vars)
    end
  end

  describe "unitsPages" do
    test "fetches a page of units" do
      user = fake_user!()
      units = some(5, fn -> fake_unit!(user) end)
      after_unit = List.first(units)

      q = units_query()
      conn = user_conn(user)
      vars = %{after: after_unit.id, limit: 2}
      assert %{"edges" => fetched} = grumble_post_key(q, conn, :units_pages, vars)
      assert Enum.count(fetched) == 2
      assert List.first(fetched)["id"] == after_unit.id
    end
  end

  describe "create_unit" do
    test "creates a new unit given valid attributes" do
      user = fake_user!()

      q = create_unit_mutation()
      conn = user_conn(user)
      vars = %{unit: unit_input()}
      assert_unit(grumble_post_key(q, conn, :create_unit, vars)["unit"])
    end

    test "creates a new unit with a scope" do
      user = fake_user!()
      comm = fake_community!(user)

      q = create_unit_mutation(fields: [in_scope_of: [:__typename]])
      conn = user_conn(user)
      vars = %{unit: Map.put(unit_input(), :in_scope_of, comm.id)}
      assert_unit(grumble_post_key(q, conn, :create_unit, vars)["unit"])
    end
  end

  describe "update_unit" do
    test "updates an existing unit" do
      user = fake_user!()
      unit = fake_unit!(user)

      q = update_unit_mutation()
      conn = user_conn(user)
      vars = %{unit: Map.put(unit_input(), "id", unit.id)}
      assert_unit(grumble_post_key(q, conn, :update_unit, vars)["unit"])
    end
  end

  describe "delete_unit" do
    test "deletes an existing unit" do
      user = fake_user!()
      unit = fake_unit!(user)

      q = delete_unit_mutation()
      conn = user_conn(user)
      assert grumble_post_key(q, conn, :delete_unit, %{id: unit.id})
    end

    test "fails to delete a unit if it has dependent measures" do
      user = fake_user!()
      unit = fake_unit!(user)
      _measures = some(5, fn -> fake_measure!(user, unit) end)

      q = delete_unit_mutation()
      conn = user_conn(user)
      assert [%{"status" => 403}] = grumble_post_errors(q, conn, %{id: unit.id})
    end
  end

  describe "measure" do
    test "fetches an existing measure by ID" do
      user = fake_user!()
      unit = fake_unit!(user)
      measure = fake_measure!(user, unit)

      q = measure_query()
      conn = user_conn(user)
      assert_measure(grumble_post_key(q, conn, :measure, %{id: measure.id}))
    end
  end

  describe "measuresPages" do
    test "fetches a page of measures" do
      user = fake_user!()
      unit = fake_unit!(user)
      measures = some(5, fn -> fake_measure!(user, unit) end)
      after_measure = List.first(measures)

      q = measures_pages_query()
      conn = user_conn(user)
      vars = %{after: after_measure.id, limit: 2}
      assert %{"edges" => fetched} = grumble_post_key(q, conn, :measures_pages, vars)
      assert Enum.count(fetched) == 2
      assert List.first(fetched)["id"] == after_measure.id
    end
  end

end
