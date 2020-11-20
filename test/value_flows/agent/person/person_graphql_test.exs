defmodule Valueflows.Agent.Person.GraphQLTest do
  use CommonsPub.Web.ConnCase, async: true

  import CommonsPub.Utils.Simulation
  import CommonsPub.Utils.Simulation
  import CommonsPub.Web.Test.GraphQLAssertions

  import Geolocation.Test.Faking
  import Measurement.Simulate

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  @debug false
  @schema CommonsPub.Web.GraphQL.Schema

  describe "person" do
    test "fetches an existing person by id (via HTTP)" do
      user = fake_agent!()

      q = person_query()
      conn = user_conn(user)
      assert_agent(grumble_post_key(q, conn, :person, %{id: user.id}, "test", @debug))
    end

    test "fetches an existing person by id (via Absinthe.run)" do
      user = fake_agent!()
      user2 = fake_agent!()

      # attach some data to the person...

      unit = fake_unit!(user)

      intent = fake_intent!(user, %{provider: user.id})

      rspec = fake_resource_specification!(user)

      from_resource =
        fake_economic_resource!(user2, %{name: "Previous Resource", conforms_to: rspec.id}, unit)

      resource =
        fake_economic_resource!(
          user,
          %{
            primary_accountable: user.id,
            name: "Resulting Resource",
            conforms_to: rspec.id
          },
          unit
        )

      pspec = fake_process_specification!(user)
      process = fake_process!(user, %{based_on: pspec.id})

      event =
        fake_economic_event!(
          user,
          %{
            provider: user2.id,
            receiver: user.id,
            action: "transfer",
            input_of: fake_process!(user).id,
            output_of: fake_process!(user2).id,
            resource_conforms_to: fake_resource_specification!(user).id,
            resource_inventoried_as: from_resource.id,
            to_resource_inventoried_as: resource.id
          },
          unit
        )

      # IO.inspect(intent: intent)
      # IO.inspect(resource: resource)
      # IO.inspect(event: event)

      assert queried =
               CommonsPub.Web.GraphQL.QueryHelper.run_query_id(
                 user.id,
                 @schema,
                 :person,
                 3,
                 nil,
                 @debug
               )

      assert_agent(queried)
      # assert_optional(assert_url(queried["image"]))
      assert_intent(List.first(queried["intents"]))
      assert_process(List.first(queried["processes"]))
      assert_economic_event(List.first(queried["economicEvents"]))
      assert_economic_resource(List.first(queried["inventoriedEconomicResources"]))
      assert_geolocation(queried["primaryLocation"])
    end
  end

  describe "persons" do
    test "fetches all" do
      user = fake_user!()
      people = ValueFlows.Agent.People.people(user)
      num_people = Enum.count(people)

      q = people_query()
      conn = user_conn(user)

      assert fetched = grumble_post_key(q, conn, :people, %{})
      assert num_people == Enum.count(fetched)
    end
  end
end
