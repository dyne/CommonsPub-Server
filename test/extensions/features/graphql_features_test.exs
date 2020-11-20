# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.FeaturesTest do
  use CommonsPub.Web.ConnCase, async: true

  import CommonsPub.Utils.Simulation
  import CommonsPub.Web.Test.ConnHelpers
  import CommonsPub.Web.Test.GraphQLAssertions
  import CommonsPub.Web.Test.GraphQLFields

  describe "feature" do
    test "works for anyone for a community feature" do
      [alice, bob] = some_fake_users!(2)
      eve = fake_admin!()
      comm = fake_community!(alice)
      feature = feature!(alice, comm)
      q = feature_query()
      vars = %{feature_id: feature.id}

      for conn <- [json_conn(), user_conn(alice), user_conn(bob), user_conn(eve)] do
        feature2 = grumble_post_key(q, conn, :feature, vars)
        assert_feature(feature, feature2)
      end
    end

    test "works for anyone for a collection feature" do
      [alice, bob] = some_fake_users!(2)
      eve = fake_admin!()
      comm = fake_community!(alice)
      coll = fake_collection!(alice, comm)
      feature = feature!(alice, coll)
      q = feature_query()
      vars = %{feature_id: feature.id}

      for conn <- [json_conn(), user_conn(alice), user_conn(bob), user_conn(eve)] do
        feature2 = grumble_post_key(q, conn, :feature, vars)
        assert_feature(feature, feature2)
      end
    end
  end

  # describe "feature.creator" do
  #   test "returns the feature creator" do
  #     user = fake_user!()
  #     comm = fake_community!(user)

  #     assert {:ok, feature} = Features.create(user, comm, %{is_local: true})

  #     q = """
  #     {
  #       feature(featureId: "#{feature.id}") {
  #         #{feature_basics()}
  #         creator { #{user_basics()} }
  #       }
  #     }
  #     """
  #     assert %{"feature" => fetched} = gql_post_data(%{query: q})
  #     assert %{"creator" => creator} = fetched
  #     assert_user(user, creator)
  #   end
  # end

  # describe "feature.context" do
  #   test "returns the feature context" do
  #     user = fake_user!()
  #     comm = fake_community!(user)

  #     assert {:ok, feature} = Features.create(user, comm, %{is_local: true})

  #     q = """
  #     {
  #       feature(featureId: "#{feature.id}") {
  #         #{feature_basics()}
  #         context { ... on Community { #{community_basics()} } }
  #       }
  #     }
  #     """
  #     assert %{"feature" => fetched} = gql_post_data(%{query: q})
  #     assert %{"context" => context} = fetched
  #     assert_community(comm, context)
  #   end
  # end

  # describe "createFeature" do
  #   test "works for an admin" do
  #     user = fake_user!(%{is_instance_admin: true})
  #     conn = user_conn(user)
  #     comm = fake_community!(user)

  #     q = """
  #     mutation Test {
  #       createFeature(contextId: "#{comm.id}") {
  #         #{feature_basics()}
  #       }
  #     }
  #     """

  #     assert %{"createFeature" => feature} = gql_post_data(conn, %{query: q, mutation: "Test"})
  #     assert feature["id"]

  #     assert {:ok, _} = Features.one(context: comm.id)
  #   end

  #   test "fails for a normal user" do
  #     user = fake_user!()
  #     conn = user_conn(user)
  #     comm = fake_community!(user)

  #     q = """
  #     mutation Test {
  #       createFeature(contextId: "#{comm.id}") {
  #         #{feature_basics()}
  #       }
  #     }
  #     """

  #     assert [%{"code" => "unauthorized", "status" => 403}] = gql_post_errors(conn, %{query: q, mutation: "Test"})
  #   end
  # end
end
