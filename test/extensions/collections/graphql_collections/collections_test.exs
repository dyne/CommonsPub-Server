# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.Collections.CollectionsTest do
  use CommonsPub.Web.ConnCase, async: true
  alias CommonsPub.Collections
  import CommonsPub.Utils.Simulation
  import CommonsPub.Web.Test.GraphQLAssertions
  import CommonsPub.Web.Test.GraphQLFields
  import CommonsPub.Web.Test.Orderings
  import CommonsPub.Web.Test.Automaton
  # import CommonsPub.Common.Enums
  import Grumble
  import Zest

  describe "collections" do
    test "works for a guest" do
      users = some_fake_users!(3)
      # 9
      communities = some_fake_communities!(3, users)
      # 27
      collections = some_fake_collections!(1, users, communities)

      root_page_test(%{
        query: collections_query(),
        connection: json_conn(),
        return_key: :collections,
        default_limit: 5,
        total_count: 27,
        data: order_follower_count(collections),
        assert_fn: &assert_collection/2,
        cursor_fn: Collections.test_cursor(:followers),
        after: :collections_after,
        before: :collections_before,
        limit: :collections_limit
      })
    end
  end

  describe "collections.resources" do
    test "works for anyone for public stuff" do
      [alice, bob, dave, eve] = some_fake_users!(4)
      users = [alice, bob, dave]
      lucy = fake_admin!(%{is_instance_admin: true})
      # 3
      comms = some_fake_communities!(1, users)
      # 9
      colls = some_fake_collections!(1, users, comms)

      colls =
        Enum.map(colls, fn coll ->
          # 3
          Map.put(coll, :resources, some_fake_resources!(1, users, [coll]))
        end)

      q =
        collections_query(
          params: [resources_limit: :int],
          fields: [
            :resource_count,
            field(
              :resources,
              args: [limit: var(:resources_limit)],
              fields: page_fields(resource_fields())
            )
          ]
        )

      vars = %{}
      conns = Enum.map([alice, bob, lucy, eve], &user_conn/1)

      each([json_conn() | conns], fn conn ->
        colls2 = grumble_post_key(q, conn, :collections, vars)
        colls2 = assert_page(colls2, 5, 9, false, true, Collections.test_cursor(:followers))

        each(colls, colls2.edges, fn coll, coll2 ->
          coll2 = assert_collection(coll, coll2)
          assert coll2.resource_count == 3
          resources = assert_page(coll2.resources, 3, 3, false, false, &[&1.id])
          each(coll.resources, resources.edges, &assert_resource/2)
        end)
      end)
    end
  end

  # describe "collections.my_like" do

  #   test "is nil for a guest or a non-liking user or instance admin" do
  #     [alice, bob] = some_fake_users!(2)
  #     lucy = fake_admin!()
  #     comm = fake_community!(alice)
  #     coll = fake_collection!(bob, comm)
  #     vars = %{collection_id: coll.id}
  #     q = collection_query(fields: [my_like: like_fields()])
  #     for conn <- [json_conn(), user_conn(alice), user_conn(bob), user_conn(lucy)] do
  #       coll2 = grumble_post_key(q, conn, :collection, vars)
  #       coll2 = assert_collection(coll, coll2)
  #       assert coll2.my_like == nil
  #     end
  #   end

  #   test "works for a liking user or instance admin" do
  #     [alice, bob] = some_fake_users!(2)
  #     lucy = fake_admin!()
  #     comm = fake_community!(alice)
  #     coll = fake_collection!(bob, comm)
  #     vars = %{collection_id: coll.id}
  #     q = collection_query(fields: [my_like: like_fields()])
  #     for user <- [alice, bob, lucy] do
  #       {:ok, like} = Likes.create(user, coll, %{is_local: true})
  #       coll2 = grumble_post_key(q, user_conn(user), :collection, vars)
  #       coll2 = assert_collection(coll, coll2)
  #       assert_like(like, coll2.my_like)
  #     end
  #   end

  # end
end
