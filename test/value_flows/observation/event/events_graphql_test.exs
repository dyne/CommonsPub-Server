defmodule ValueFlows.Observation.EconomicEvent.EventsGraphQLTest do
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

  describe "EconomicEvent" do
    test "fetches an economic event by ID (via HTTP)" do
      user = fake_user!()
      unit = fake_unit!(user)

      provider = fake_agent_from_user!(user)
      receiver = fake_agent!()

      action = action()

      event =
        fake_economic_event!(user, %{
          provider: provider.id,
          receiver: receiver.id,
          action: action.id,
          input_of: fake_process!(user).id,
          output_of: fake_process!(user).id,
          resource_conforms_to: fake_resource_specification!(provider).id,
          resource_inventoried_as: fake_economic_resource!(provider, %{}, unit).id,
          to_resource_inventoried_as: fake_economic_resource!(receiver, %{}, unit).id,
        }, unit)

      q = economic_event_query()
      conn = user_conn(user)
      assert fetched = grumble_post_key(q, conn, :economic_event, %{id: event.id})
      assert_economic_event(fetched)
    end

    test "fetches a full nested economic event by ID (via Absinthe.run)" do
      user = fake_user!()

      location = fake_geolocation!(user)

      unit = fake_unit!(user)

      provider = fake_agent_from_user!(user)
      receiver = fake_agent!()
      action = action()

      triggered_by = fake_economic_event!(user, %{}, unit)

      event =
        fake_economic_event!(user, %{
          in_scope_of: [fake_community!(user).id],
          provider: provider.id,
          receiver: receiver.id,
          action: action.id,
          input_of: fake_process!(user).id,
          output_of: fake_process!(user).id,
          triggered_by: triggered_by.id,
          resource_conforms_to: fake_resource_specification!(user).id,
          resource_inventoried_as: fake_economic_resource!(user, %{}, unit).id,
          to_resource_inventoried_as: fake_economic_resource!(receiver, %{}, unit).id,
          at_location: location.id
        }, unit)

      # IO.inspect(created: event)

      assert queried =
               CommonsPub.Web.GraphQL.QueryHelper.run_query_id(
                 event.id,
                 @schema,
                 :economic_event,
                 3,
                 nil,
                 @debug
               )

      assert_economic_event(queried)
    end

    test "fails if has been deleted" do
      user = fake_user!()
      unit = fake_unit!(user)

      event =
        fake_economic_event!(user, %{
          input_of: fake_process!(user).id,
          output_of: fake_process!(user).id,
          resource_conforms_to: fake_resource_specification!(user).id,
          to_resource_inventoried_as: fake_economic_resource!(user, %{}, unit).id,
          resource_inventoried_as: fake_economic_resource!(user, %{}, unit).id
        }, unit)

      q = economic_event_query()
      conn = user_conn(user)

      assert {:ok, spec} = EconomicEvents.soft_delete(event)

      assert [%{"code" => "not_found", "path" => ["economicEvent"], "status" => 404}] =
               grumble_post_errors(q, conn, %{id: event.id})
    end
  end

  describe "economicEvent.inScopeOf" do
    test "return the scope of the intent" do
      user = fake_user!()

      parent = fake_user!()

      event =
        fake_economic_event!(user, %{
          in_scope_of: [parent.id]
        })

      q = economic_event_query(fields: [in_scope_of: [:__typename]])
      conn = user_conn(user)
      assert fetched = grumble_post_key(q, conn, :economic_event, %{id: event.id})
      assert hd(fetched["inScopeOf"])["__typename"] == "Person"
    end
  end

  describe "EconomicEvents" do
    test "return a list of economicEvents" do
      user = fake_user!()

      events =
        some(5, fn ->
          fake_economic_event!(user)
        end)

      # deleted
      some(2, fn ->
        event = fake_economic_event!(user)

        {:ok, event} = EconomicEvents.soft_delete(event)
        event
      end)

      q = economic_events_query()
      conn = user_conn(user)
      assert fetched_economic_events = grumble_post_key(q, conn, :economic_events, %{})
      assert Enum.count(events) == Enum.count(fetched_economic_events)
    end
  end

  describe "EconomicEventsPages" do
    test "fetches all items that are not deleted" do
      user = fake_user!()

      events =
        some(5, fn ->
          fake_economic_event!(user)
        end)

      after_event = List.first(events)
      # deleted
      some(2, fn ->
        event = fake_economic_event!(user)

        {:ok, event} = EconomicEvents.soft_delete(event)
        event
      end)

      q = economic_events_pages_query()
      conn = user_conn(user)
      vars = %{after: after_event.id, limit: 2}
      assert page = grumble_post_key(q, conn, :economic_events_pages, vars)
      assert Enum.count(events) == page["totalCount"]
      assert List.first(page["edges"])["id"] == after_event.id
    end
  end

  describe "EconomicEvent.track" do
    test "Returns a list of EconomicResources or Processes" do
      user = fake_user!()
      unit = fake_unit!(user)

      process = fake_process!(user)
      another_process = fake_process!(user)

      resource = fake_economic_resource!(user, %{}, unit)
      another_resource = fake_economic_resource!(user, %{}, unit)

      event =
        fake_economic_event!(
          user,
          %{
            input_of: process.id,
            output_of: another_process.id,
            resource_inventoried_as: resource.id,
            to_resource_inventoried_as: another_resource.id,
            action: "transfer"
          },
          unit
        )

      q = economic_event_query(fields: [track: [:__typename]])
      conn = user_conn(user)

      assert event = grumble_post_key(q, conn, :economic_event, %{id: event.id})
      assert Enum.count(event["track"]) == 3
    end
  end

  describe "EconomicEvent.trace" do
    test "Returns a list of economic events that are outputs" do
      user = fake_user!()
      unit = fake_unit!(user)

      process = fake_process!(user)
      another_process = fake_process!(user)

      resource = fake_economic_resource!(user, %{}, unit)
      another_resource = fake_economic_resource!(user, %{}, unit)

      event =
        fake_economic_event!(
          user,
          %{
            input_of: process.id,
            output_of: another_process.id,
            resource_inventoried_as: resource.id,
            to_resource_inventoried_as: another_resource.id,
            action: "transfer"
          },
          unit
        )

      q = economic_event_query(fields: [trace: [:__typename]])
      conn = user_conn(user)

      assert event = grumble_post_key(q, conn, :economic_event, %{id: event.id})
      assert Enum.count(event["trace"]) == 3
    end
  end

  describe "createEconomicEvent" do
    test "create a new economic event" do
      user = fake_user!()

      q = create_economic_event_mutation()
      conn = user_conn(user)

      vars = %{
        event: economic_event_input()
      }

      assert event = grumble_post_key(q, conn, :create_economic_event, vars)["economicEvent"]
      assert_economic_event(event)
    end

    test "creates a new economic event with a scope" do
      user = fake_user!()

      parent = fake_user!()

      q = create_economic_event_mutation(fields: [in_scope_of: [:__typename]])
      conn = user_conn(user)

      vars = %{
        event:
          economic_event_input(%{
            "inScopeOf" => [parent.id]
          })
      }

      assert event = grumble_post_key(q, conn, :create_economic_event, vars)["economicEvent"]
      assert_economic_event(event)
      assert hd(event["inScopeOf"])["__typename"] == "Person"
    end

    test "create an economic event with an input and an output" do
      user = fake_user!()

      process = fake_process!(user)

      q = create_economic_event_mutation(fields: [input_of: [:id], output_of: [:id]])
      conn = user_conn(user)

      vars = %{
        event:
          economic_event_input(%{
            "inputOf" => process.id,
            "outputOf" => process.id
          })
      }

      assert event = grumble_post_key(q, conn, :create_economic_event, vars)["economicEvent"]
      assert_economic_event(event)
      assert event["inputOf"]["id"] == process.id
      assert event["outputOf"]["id"] == process.id
    end

    test "create an economic event with a resourceInventoriedAs" do
      user = fake_user!()

      resource_inventoried_as = fake_economic_resource!(user)

      q = create_economic_event_mutation(fields: [resource_inventoried_as: [:id]])
      conn = user_conn(user)

      vars = %{
        event:
          economic_event_input(%{
            "resourceInventoriedAs" => resource_inventoried_as.id
          })
      }

      assert event = grumble_post_key(q, conn, :create_economic_event, vars)["economicEvent"]
      assert_economic_event(event)
      assert event["resourceInventoriedAs"]["id"] == resource_inventoried_as.id
    end

    test "create an economic event with toResourceInventoriedAs" do
      user = fake_user!()

      resource_inventoried_as = fake_economic_resource!(user)

      q = create_economic_event_mutation(fields: [to_resource_inventoried_as: [:id]])
      conn = user_conn(user)

      vars = %{
        event:
          economic_event_input(%{
            "toResourceInventoriedAs" => resource_inventoried_as.id
          })
      }

      assert event = grumble_post_key(q, conn, :create_economic_event, vars)["economicEvent"]
      assert_economic_event(event)
      assert event["toResourceInventoriedAs"]["id"] == resource_inventoried_as.id
    end

    test "create an economic event with resource conforms to" do
      user = fake_user!()

      resource_conforms_to = fake_resource_specification!(user)

      q = create_economic_event_mutation(fields: [resource_conforms_to: [:id]])
      conn = user_conn(user)

      vars = %{
        event:
          economic_event_input(%{
            "resourceConformsTo" => resource_conforms_to.id
          })
      }

      assert event = grumble_post_key(q, conn, :create_economic_event, vars)["economicEvent"]
      assert_economic_event(event)
      assert event["resourceConformsTo"]["id"] == resource_conforms_to.id
    end

    test "create an economic event with measurements" do
    end

    test "create an economic event with location" do
      user = fake_user!()

      geo = fake_geolocation!(user)

      q = create_economic_event_mutation(fields: [at_location: [:id]])
      conn = user_conn(user)

      vars = %{
        event:
          economic_event_input(%{
            "at_location" => geo.id
          })
      }

      assert event = grumble_post_key(q, conn, :create_economic_event, vars)["economicEvent"]
      assert_economic_event(event)
      assert event["atLocation"]["id"] == geo.id
    end

    test "create an economic event triggered by another economic event" do
      user = fake_user!()
      unit = fake_unit!(user)

      trigger = fake_economic_event!(user, %{}, unit)
      q = create_economic_event_mutation(fields: [triggered_by: [:id]])
      conn = user_conn(user)

      vars = %{
        event:
          economic_event_input(%{
            "triggered_by" => trigger.id
          })
      }

      assert event = grumble_post_key(q, conn, :create_economic_event, vars)["economicEvent"]
      assert_economic_event(event)
      assert event["triggeredBy"]["id"] == trigger.id
    end

    test "create an economic event with tags" do
      user = fake_user!()

      tags = some(5, fn -> fake_category!(user).id end)

      q = create_economic_event_mutation(fields: [tags: [:__typename]])
      conn = user_conn(user)

      vars = %{
        event:
          economic_event_input(%{
            "tags" => tags
          })
      }

      assert event = grumble_post_key(q, conn, :create_economic_event, vars)["economicEvent"]

      assert_economic_event(event)
      assert hd(event["tags"])["__typename"] == "Category"
    end
  end

  describe "updateEconomicEvent" do
    test "update an existing economic event" do
    end

    test "fails if it has previously been deleted" do
    end
  end

  describe "deleteEconomicEvent" do
    test "deletes an existing economic event" do
    end

    test "fails to delete an economic resource if the user does not have rights to delete it" do
    end
  end
end
