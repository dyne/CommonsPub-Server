# # SPDX-License-Identifier: AGPL-3.0-only
defmodule Measurement.MeasuresTest do
  use CommonsPub.Web.ConnCase, async: true

  import CommonsPub.Utils.Trendy
  import CommonsPub.Utils.Simulation
  import CommonsPub.Web.Test.Orderings
  import CommonsPub.Web.Test.Automaton
  import CommonsPub.Web.Test.GraphQLAssertions
  import CommonsPub.Common.Enums
  import Grumble
  import Zest
  alias CommonsPub.Utils.Simulation

  import Measurement.Test.Faking
  import Measurement.Simulate
  alias Measurement.Measure
  alias Measurement.Measure.Measures

  describe "one" do
    test "fetches an existing measure" do
      user = fake_user!()
      unit = fake_unit!(user)
      measure = fake_measure!(user, unit)

      assert {:ok, fetched} = Measures.one(id: measure.id)
      assert_measure(measure, fetched)
      assert {:ok, fetched} = Measures.one(user: user)
      assert_measure(measure, fetched)
    end
  end

  describe "create" do
    test "creates a new measure" do
      user = fake_user!()
      unit = fake_unit!(user)
      assert {:ok, measure} = Measures.create(user, unit, measure())
      assert_measure(measure)
    end

    test "fails when missing attributes" do
      user = fake_user!()
      unit = fake_unit!(user)
      assert {:error, %Ecto.Changeset{}} = Measures.create(user, unit, %{})
    end
  end

  describe "update" do
    test "updates an existing measure with new content" do
      user = fake_user!()
      unit = fake_unit!(user)
      measure = fake_measure!(user, unit)

      attrs = measure()
      assert {:ok, updated} = Measures.update(measure, attrs)
      assert_measure(updated)
      assert measure != updated
    end
  end
end
