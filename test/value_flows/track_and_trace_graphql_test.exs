defmodule ValueFlows.TrackAndTraceGraphQLTest do
  use CommonsPub.Web.ConnCase, async: true

  import CommonsPub.Utils.Simulation
  import CommonsPub.Tag.Simulate

  import CommonsPub.Utils.{Trendy, Simulation}
  import ValueFlows.Simulate
  import Measurement.Simulate
  import Geolocation.Simulate

  import ValueFlows.Test.Faking

  alias ValueFlows.Observation.EconomicEvent.EconomicEvents
  alias ValueFlows.Observation.EconomicResource.EconomicResources

  @schema CommonsPub.Web.GraphQL.Schema

  describe "Trace" do
    test "3 level nesting" do
      user = fake_user!()
      unit = fake_unit!(user)

      resource = fake_economic_resource!(user, %{}, unit)
      other_resource = fake_economic_resource!(user, %{}, unit)

      process = fake_process!(user)

      output_event = fake_economic_event!(user, %{
        output_of: process.id,
        resource_inventoried_as: resource.id,
        action: "produce"
      }, unit)
      input_event = fake_economic_event!(user, %{
        input_of: process.id,
        resource_inventoried_as: other_resource.id,
        action: "use"
      }, unit)

      query = """
        query ($id: ID) {
        economicResource(id: $id) {
          id
          trace {
            id
            trace {
              __typename
              ... on Process {
                id
                trace {
                  id
                  trace {
                    __typename
                  }
                }
              }
              ... on EconomicResource {
                id
                trace {
                  id
                  trace {
                    __typename
                  }
                }
              }
            }
          }
        }
      }
      """
      assert {:ok, %{data: result}} = Absinthe.run(query, @schema, variables: %{"id" => resource.id})
      assert result["economicResource"]["id"] == resource.id
      assert hd(result["economicResource"]["trace"])["id"] == output_event.id
      assert hd(hd(result["economicResource"]["trace"])["trace"])["id"] == process.id
      assert hd(hd(hd(result["economicResource"]["trace"])["trace"])["trace"])["id"] == input_event.id
      assert hd(hd(hd(hd(result["economicResource"]["trace"])["trace"])["trace"])["trace"])["__typename"] == "EconomicResource"
    end
  end

  describe "Track" do
    test "3 level nesting" do
      user = fake_user!()
      unit = fake_unit!(user)

      resource = fake_economic_resource!(user, %{}, unit)
      other_resource = fake_economic_resource!(user, %{}, unit)

      process = fake_process!(user)
      output_event = fake_economic_event!(user, %{
        output_of: process.id,
        resource_inventoried_as: resource.id,
        action: "produce"
      }, unit)
      input_event = fake_economic_event!(user, %{
        input_of: process.id,
        resource_inventoried_as: other_resource.id,
        action: "use"
      }, unit)
      query = """
        query ($id: ID) {
        economicResource(id: $id) {
          id
          track {
            id
            track {
              __typename
              ... on Process {
                id
                track {
                  id
                  track {
                    __typename
                  }
                }
              }
              ... on EconomicResource {
                id
                track {
                  id
                  track {
                    __typename
                  }
                }
              }
            }
          }
        }
      }
      """
      assert {:ok, %{data: result}} = Absinthe.run(query, @schema, variables: %{"id" => other_resource.id})
      assert result["economicResource"]["id"] == other_resource.id
      assert hd(result["economicResource"]["track"])["id"] == input_event.id
      assert hd(hd(result["economicResource"]["track"])["track"])["id"] == process.id
      assert hd(hd(hd(result["economicResource"]["track"])["track"])["track"])["id"] == output_event.id
      assert hd(hd(hd(hd(result["economicResource"]["track"])["track"])["track"])["track"])["__typename"] == "EconomicResource"
    end
  end
end
