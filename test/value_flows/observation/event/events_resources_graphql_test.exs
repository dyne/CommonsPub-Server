defmodule ValueFlows.Observation.EconomicEvent.EventsResourcesGraphQLTest do
  use CommonsPub.Web.ConnCase, async: true

  import CommonsPub.Utils.Trendy, only: [some: 2]
  import CommonsPub.Utils.Simulation
  import CommonsPub.Tag.Simulate

  import CommonsPub.Utils.Simulation

  import Measurement.Simulate
  import Measurement.Test.Faking

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking
  alias Grumble.PP
  alias ValueFlows.Observation.EconomicEvent.EconomicEvents

  import Geolocation.Simulate
  import Geolocation.Test.Faking

  @debug false
  @schema CommonsPub.Web.GraphQL.Schema

  describe "EconomicEventsResourcesMutations" do
    test "create an economic resource produced by an economic event" do
      user = fake_user!()

      q = create_economic_event_mutation([fields: [provider: [:id]]], fields: [:id])

      conn = user_conn(user)

      vars = %{
        event:
          economic_event_input(%{
            "action" => "produce"
          }),
        newInventoriedResource: economic_resource_input()
      }

      assert response = grumble_post_key(q, conn, :create_economic_event, vars, "test", false)
      assert event = response["economicEvent"]
      assert resource = response["economicResource"]
      assert_economic_event(event)
      assert_economic_resource(resource)
      # assert event["resourceConformsTo"]["id"] == resource_conforms_to.id
    end

    test "increment an existing resource" do
      user = fake_user!()
      unit = fake_unit!(user)

      resource_inventoried_as = fake_economic_resource!(user, %{}, unit)

      q =
        create_economic_event_mutation(
          fields: [
            :id,
            resource_quantity: [:has_numerical_value],
            resource_inventoried_as: [
              :id,
              onhand_quantity: [:has_numerical_value],
              accounting_quantity: [:has_numerical_value]
            ]
          ]
        )

      conn = user_conn(user)

      vars = %{
        event:
          economic_event_input(%{
            "action" => "raise",
            "resourceQuantity" => measure_input(unit, %{"hasNumericalValue" => 42}),
            "resourceInventoriedAs" => resource_inventoried_as.id
          })
      }

      assert response = grumble_post_key(q, conn, :create_economic_event, vars, "test", @debug)
      assert event = response["economicEvent"]
      assert_economic_event(event)

      assert event["resourceInventoriedAs"]["accountingQuantity"]["hasNumericalValue"] ==
               resource_inventoried_as.accounting_quantity.has_numerical_value + 42
    end

    test "decrement an existing resource" do
      user = fake_user!()
      unit = fake_unit!(user)

      resource_inventoried_as = fake_economic_resource!(user, %{}, unit)

      q =
        create_economic_event_mutation(
          fields: [
            :id,
            resource_quantity: [:has_numerical_value],
            resource_inventoried_as: [
              :id,
              onhand_quantity: [:has_numerical_value],
              accounting_quantity: [:has_numerical_value]
            ]
          ]
        )

      conn = user_conn(user)

      vars = %{
        event:
          economic_event_input(%{
            "action" => "lower",
            "resourceQuantity" => measure_input(unit, %{"hasNumericalValue" => 42}),
            "resourceInventoriedAs" => resource_inventoried_as.id
          })
      }

      assert response = grumble_post_key(q, conn, :create_economic_event, vars, "test", @debug)
      assert event = response["economicEvent"]
      assert_economic_event(event)

      assert event["resourceInventoriedAs"]["accountingQuantity"]["hasNumericalValue"] ==
               resource_inventoried_as.accounting_quantity.has_numerical_value - 42
    end

    test "fails if trying to increment a resource with a different unit" do
      user = fake_user!()
      unit = fake_unit!(user)

      resource_inventoried_as = fake_economic_resource!(user)

      q = create_economic_event_mutation(fields: [resource_inventoried_as: [:id]])
      conn = user_conn(user)

      vars = %{
        event:
          economic_event_input(%{
            "action" => "raise",
            "resourceQuantity" => measure_input(unit),
            "resourceInventoriedAs" => resource_inventoried_as.id
          })
      }

      assert {:additional_errors, _} =
               catch_throw(
                 grumble_post_key(q, conn, :create_economic_event, vars, "test", @debug)
               )
    end

    test "transfer an existing economic resource" do
      user = fake_user!()
      unit = fake_unit!(user)
      resource_inventoried_as = fake_economic_resource!(user, %{}, unit)
      to_resource_inventoried_as = fake_economic_resource!(user, %{}, unit)

      q =
        create_economic_event_mutation(
          fields: [
            :id,
            resource_quantity: [:has_numerical_value],
            resource_inventoried_as: [
              :id,
              onhand_quantity: [:has_numerical_value],
              accounting_quantity: [:has_numerical_value]
            ],
            to_resource_inventoried_as: [
              :id,
              onhand_quantity: [:has_numerical_value],
              accounting_quantity: [:has_numerical_value]
            ]
          ]
        )

      conn = user_conn(user)

      vars = %{
        event:
          economic_event_input(%{
            "action" => "transfer",
            "resourceQuantity" => measure_input(unit, %{"hasNumericalValue" => 42}),
            "resourceInventoriedAs" => resource_inventoried_as.id,
            "toResourceInventoriedAs" => to_resource_inventoried_as.id
            # "provider" => user.id,
            # "receiver" => user.id
          })
      }

      assert response = grumble_post_key(q, conn, :create_economic_event, vars, "test", @debug)
      assert event = response["economicEvent"]
      assert_economic_event(event)

      assert event["resourceInventoriedAs"]["accountingQuantity"]["hasNumericalValue"] ==
               resource_inventoried_as.accounting_quantity.has_numerical_value - 42

      assert event["toResourceInventoriedAs"]["accountingQuantity"]["hasNumericalValue"] ==
               to_resource_inventoried_as.accounting_quantity.has_numerical_value + 42
    end

    test "create an economic resource produced by an economic event, and then transfer part of it" do
      alice = fake_user!()
      bob = fake_user!()

      unit = fake_unit!(alice)

      event_fields = [
        fields: [
          :id,
          resource_quantity: [:has_numerical_value],
          provider: [:id],
          receiver: [:id],
          resource_inventoried_as: [
            :id,
            primary_accountable: [:id],
            onhand_quantity: [:id, :has_numerical_value],
            accounting_quantity: [:id, :has_numerical_value]
          ],
          to_resource_inventoried_as: [
            :id,
            primary_accountable: [:id],
            onhand_quantity: [:id, :has_numerical_value],
            accounting_quantity: [:id, :has_numerical_value]
          ]
        ],
      ]
      resource_fields = [
        fields: [
          :id,
          primary_accountable: [:id],
          onhand_quantity: [:has_numerical_value],
          accounting_quantity: [:has_numerical_value]
        ]
      ]

      q_a = create_economic_event_mutation(event_fields, resource_fields)

      conn_a = user_conn(alice)

      vars_a = %{
        event:
          economic_event_input(%{
            "action" => "produce",
            "provider" => alice.id,
            "receiver" => alice.id,
            "resourceQuantity" => measure_input(unit, %{"hasNumericalValue" => 10})
          }),
        new_inventoried_resource: economic_resource_input(%{"name" => "resource A"})
      }

      assert response_a =
               grumble_post_key(q_a, conn_a, :create_economic_event, vars_a, "test", false)

      assert event_a = response_a["economicEvent"]
      assert_economic_event(event_a)

      resource_a = response_a["economicResource"]
      # assert_economic_resource(resource_a)

      resource_a_alt = event_a["resourceInventoriedAs"]
      # assert_economic_resource(resource_a_alt)

      from_resource_id = Map.get(resource_a || resource_a_alt, "id")
      assert from_resource_id

      # now transfer it
      q_b = create_economic_event_mutation(event_fields, resource_fields)

      conn_b = user_conn(bob)

      vars_b = %{
        event:
          economic_event_input(%{
            "action" => "transfer",
            "resourceQuantity" => measure_input(unit, %{"hasNumericalValue" => 2}),
            "resourceInventoriedAs" => from_resource_id,
            "provider" => alice.id,
            "receiver" => bob.id
          }),
        new_inventoried_resource: economic_resource_input(%{"name" => "resource B"})
      }

      assert response_b =
               grumble_post_key(q_b, conn_b, :create_economic_event, vars_b, "test", @debug)

      assert event_b = response_b["economicEvent"]
      assert resource_a_updated = event_b["resourceInventoriedAs"]
      assert resource_b = event_b["toResourceInventoriedAs"]
      assert_economic_event(event_b)

      assert resource_a_updated["onhandQuantity"]["hasNumericalValue"] ==
               8
      assert resource_a_updated["accountingQuantity"]["hasNumericalValue"] ==
               8

      assert resource_b["onhandQuantity"]["hasNumericalValue"] ==
               2
      assert resource_b["accountingQuantity"]["hasNumericalValue"] ==
               2
    end

    test "create an economic event that consumes an existing resource" do
      user = fake_user!()
      unit = fake_unit!(user)

      resource_inventoried_as = fake_economic_resource!(user, %{}, unit)

      q =
        create_economic_event_mutation(
          fields: [
            :id,
            resource_quantity: [:has_numerical_value],
            resource_inventoried_as: [
              :id,
              onhand_quantity: [:has_numerical_value],
              accounting_quantity: [:has_numerical_value]
            ]
          ]
        )

      conn = user_conn(user)

      vars = %{
        event:
          economic_event_input(%{
            "action" => "consume",
            "resourceQuantity" => measure_input(unit, %{"hasNumericalValue" => 42}),
            "resourceInventoriedAs" => resource_inventoried_as.id
          })
      }

      assert response = grumble_post_key(q, conn, :create_economic_event, vars, "test", @debug)
      assert event = response["economicEvent"]
      assert_economic_event(event)

      assert event["resourceInventoriedAs"]["accountingQuantity"]["hasNumericalValue"] ==
               resource_inventoried_as.accounting_quantity.has_numerical_value - 42
    end

    test "fails if the economic event consumes an economic resource that does not exist" do
      user = fake_user!()
      unit = fake_unit!(user)

      q =
        create_economic_event_mutation(
          fields: [
            :id,
            resource_quantity: [:has_numerical_value],
            resource_inventoried_as: [
              :id,
              onhand_quantity: [:has_numerical_value],
              accounting_quantity: [:has_numerical_value]
            ]
          ]
        )

      conn = user_conn(user)

      vars = %{
        event:
          economic_event_input(%{
            "action" => "consume",
            "resourceQuantity" => measure_input(unit, %{"hasNumericalValue" => 42}),
            "resourceInventoriedAs" => ulid()
          })
      }

      assert [%{"status" => 404}] =
               grumble_post_errors(q, conn, vars)
    end

    test "create an economic event that transfers an existing resource from a provider to a receiver" do
      alice = fake_user!()
      bob = fake_user!()

      unit = fake_unit!(alice)

      resource_inventoried_as =
        fake_economic_resource!(alice, %{primary_accountable: alice.id}, unit)

      to_resource_inventoried_as = fake_economic_resource!(bob, %{}, unit)

      q =
        create_economic_event_mutation(
          fields: [
            :id,
            resource_quantity: [:has_numerical_value],
            resource_inventoried_as: [
              :id,
              onhand_quantity: [:has_numerical_value],
              accounting_quantity: [:has_numerical_value]
            ],
            to_resource_inventoried_as: [
              :id,
              onhand_quantity: [:has_numerical_value],
              accounting_quantity: [:has_numerical_value],
              primary_accountable: [:id]
            ]
          ]
        )

      conn = user_conn(alice)

      vars = %{
        event:
          economic_event_input(%{
            "action" => "transfer",
            "resourceQuantity" => measure_input(unit, %{"hasNumericalValue" => 42}),
            "resourceInventoriedAs" => resource_inventoried_as.id,
            "toResourceInventoriedAs" => to_resource_inventoried_as.id,
            "provider" => alice.id,
            "receiver" => bob.id
          })
      }

      assert response = grumble_post_key(q, conn, :create_economic_event, vars, "test", @debug)
      assert event = response["economicEvent"]
      assert_economic_event(event)

      assert event["resourceInventoriedAs"]["accountingQuantity"]["hasNumericalValue"] ==
               resource_inventoried_as.accounting_quantity.has_numerical_value - 42

      assert event["toResourceInventoriedAs"]["accountingQuantity"]["hasNumericalValue"] ==
               to_resource_inventoried_as.accounting_quantity.has_numerical_value + 42

      assert event["toResourceInventoriedAs"]["primaryAccountable"]["id"] == bob.id
    end

    test "fails to transfer an economic resource if the provider does not have rights to transfer it" do
      alice = fake_user!()
      unit = fake_unit!(alice)
      bob = fake_user!()

      resource_inventoried_as =
        fake_economic_resource!(alice, %{primary_accountable: bob.id}, unit)

      to_resource_inventoried_as = fake_economic_resource!(alice, %{}, unit)

      q =
        create_economic_event_mutation(
          fields: [
            :id,
            resource_quantity: [:has_numerical_value],
            resource_inventoried_as: [
              :id,
              onhand_quantity: [:has_numerical_value],
              accounting_quantity: [:has_numerical_value]
            ],
            to_resource_inventoried_as: [
              :id,
              onhand_quantity: [:has_numerical_value],
              accounting_quantity: [:has_numerical_value],
              primary_accountable: [:id]
            ]
          ]
        )

      conn = user_conn(alice)

      vars = %{
        event:
          economic_event_input(%{
            "action" => "transfer",
            "resourceQuantity" => measure_input(unit, %{"hasNumericalValue" => 42}),
            "resourceInventoriedAs" => resource_inventoried_as.id,
            "toResourceInventoriedAs" => to_resource_inventoried_as.id,
            "provider" => alice.id,
            "receiver" => bob.id
          })
      }

      assert [%{"status" => 403, "code" => "unauthorized"}] = grumble_post_errors(q, conn, vars)
    end

    test "cannot transfer custody of an economic resource when the provider does not have rights on the target resource" do
      user_provider = fake_user!()
      user_receiver = fake_user!()
      user_resource_to = fake_user!()

      unit = fake_unit!(user_provider)

      resource_inventoried_as =
        fake_economic_resource!(user_provider, %{primary_accountable: user_provider.id}, unit)

      to_resource_inventoried_as =
        fake_economic_resource!(user_provider, %{primary_accountable: user_resource_to.id}, unit)

      q =
        create_economic_event_mutation(
          fields: [
            :id,
            resource_quantity: [:has_numerical_value],
            resource_inventoried_as: [
              :id,
              onhand_quantity: [:has_numerical_value],
              accounting_quantity: [:has_numerical_value]
            ],
            to_resource_inventoried_as: [
              :id,
              onhand_quantity: [:has_numerical_value],
              accounting_quantity: [:has_numerical_value],
              primary_accountable: [:id]
            ]
          ]
        )

      conn = user_conn(user_provider)

      vars = %{
        event:
          economic_event_input(%{
            "action" => "transfer-custody",
            "resourceQuantity" => measure_input(unit, %{"hasNumericalValue" => 42}),
            "resourceInventoriedAs" => resource_inventoried_as.id,
            "toResourceInventoriedAs" => to_resource_inventoried_as.id,
            "provider" => user_provider.id,
            "receiver" => user_receiver.id
          })
      }

      catch_throw grumble_post_key(q, conn, :create_economic_event, vars, "test", @debug)
      # assert event = response["economicEvent"]
      # assert_economic_event(event)

      # assert event["resourceInventoriedAs"]["onhandQuantity"]["hasNumericalValue"] ==
      #          resource_inventoried_as.onhand_quantity.has_numerical_value - 42

      # assert event["toResourceInventoriedAs"]["onhandQuantity"]["hasNumericalValue"] ==
      #          to_resource_inventoried_as.onhand_quantity.has_numerical_value + 42

      # assert event["toResourceInventoriedAs"]["primaryAccountable"]["id"] == user_resource_to.id
    end
  end
end
