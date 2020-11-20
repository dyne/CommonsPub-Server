# # SPDX-License-Identifier: AGPL-3.0-only
defmodule Measurement.UnitsTest do
  use CommonsPub.Web.ConnCase, async: true

  import Measurement.Test.Faking

  import CommonsPub.Utils.Trendy
  import CommonsPub.Utils.Simulation
  import CommonsPub.Web.Test.Orderings
  import CommonsPub.Web.Test.Automaton
  import CommonsPub.Common.{Enums, NotFoundError}

  import Grumble
  import Zest

  alias CommonsPub.Utils.Simulation

  import Measurement.Simulate
  alias Measurement.Unit
  alias Measurement.Unit.Units

  describe "one" do
    test "returns an item if it exists" do
      user = fake_user!(%{is_instance_admin: true})
      comm = fake_community!(user)
      unit = fake_unit!(user, comm)

      assert {:ok, fetched} = Units.one(id: unit.id)
      assert_unit(unit, fetched)
      assert {:ok, fetched} = Units.one(user: user)
      assert_unit(unit, fetched)
      assert {:ok, fetched} = Units.one(context_id: comm.id)
      assert_unit(unit, fetched)
    end

    test "returns NotFound if item is missing" do
      assert {:error, %CommonsPub.Common.NotFoundError{}} = Units.one(id: Simulation.ulid())
    end

    test "returns NotFound if item is deleted" do
      unit = fake_user!() |> fake_unit!()
      assert {:ok, unit} = Units.soft_delete(unit)
      assert {:error, %CommonsPub.Common.NotFoundError{}} = Units.one([:default, id: unit.id])
    end
  end

  describe "create without context" do
    test "creates a new unit" do
      user = fake_user!()
      assert {:ok, unit = %Unit{}} = Units.create(user, unit())
      assert unit.creator_id == user.id
    end
  end

  describe "create with context" do
    test "creates a new unit" do
      user = fake_user!()
      comm = fake_community!(user)

      assert {:ok, unit = %Unit{}} = Units.create(user, comm, unit())
      assert unit.creator_id == user.id
      assert unit.context_id == comm.id
    end

    test "fails with invalid attributes" do
      assert {:error, %Ecto.Changeset{}} = Units.create(fake_user!(), %{})
    end
  end

  describe "update" do
    test "updates a a unit" do
      user = fake_user!()
      comm = fake_community!(user)
      unit = fake_unit!(user, comm, %{label: "Bottle Caps", symbol: "C"})
      assert {:ok, updated} = Units.update(unit, %{label: "Rad", symbol: "rad"})
      assert unit != updated
    end
  end

  describe "soft_delete" do
    test "deletes an existing unit" do
      unit = fake_user!() |> fake_unit!()
      refute unit.deleted_at
      assert {:ok, deleted} = Units.soft_delete(unit)
      assert deleted.deleted_at
    end
  end

  # describe "units" do

  #   test "works for a guest" do
  #     users = some_fake_users!(3)
  #     communities = some_fake_communities!(3, users) # 9
  #     units = some_fake_collections!(1, users, communities) # 27
  #     root_page_test %{
  #       query: units_query(),
  #       connection: json_conn(),
  #       return_key: :units,
  #       default_limit: 10,
  #       total_count: 27,
  #       data: order_follower_count(units),
  #       assert_fn: &assert_unit/2,
  #       cursor_fn: &[&1.id],
  #       after: :collections_after,
  #       before: :collections_before,
  #       limit: :collections_limit,
  #     }
  #   end

  # end
end
