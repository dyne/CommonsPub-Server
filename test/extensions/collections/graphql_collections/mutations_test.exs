# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.Collections.MutationsTest do
  use CommonsPub.Web.ConnCase, async: true
  import CommonsPub.Utils.Simulation
  import CommonsPub.Web.Test.GraphQLAssertions
  import CommonsPub.Web.Test.GraphQLFields
  import CommonsPub.Utils.Simulation

  describe "create_collection" do
    test "works for the community creator, randomer and instance admin" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      conns = [user_conn(alice), user_conn(bob), user_conn(lucy)]
      comm = fake_community!(alice)

      for conn <- conns do
        ci = collection_input()

        vars = %{
          collection: ci,
          context_id: comm.id,
          icon: %{url: "https://via.placeholder.com/150.png"}
        }

        q = create_collection_mutation(fields: [icon: [:url]])

        coll = grumble_post_key(q, conn, :create_collection, vars)
        assert_collection_created(ci, coll)
        assert_url(coll["icon"]["url"])
      end
    end

    test "does not work for a guest" do
      bob = fake_user!()
      comm = fake_community!(bob)
      ci = collection_input()
      q = create_collection_mutation()
      vars = %{collection: ci, context_id: comm.id}
      assert err = grumble_post_errors(q, json_conn(), vars)
    end
  end

  describe "update_collection" do
    test "works for the community owner  or admin" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      coll = fake_collection!(bob, comm)
      conns = [user_conn(alice), user_conn(lucy)]

      for conn <- conns do
        ci = collection_update_input()

        vars = %{
          collection: ci,
          collection_id: coll.id,
          icon: %{url: "https://via.placeholder.com/50.png"}
        }

        q = update_collection_mutation()
        coll = grumble_post_key(q, conn, :update_collection, vars)
        assert_collection_updated(ci, coll)
      end
    end

    test "does not work for a random or a guest" do
      [alice, bob, eve] = some_fake_users!(3)
      comm = fake_community!(alice)
      coll = fake_collection!(bob, comm)

      for conn <- [user_conn(eve), json_conn()] do
        ci = collection_update_input()
        vars = %{collection: ci, collection_id: coll.id}
        q = update_collection_mutation()
        grumble_post_errors(q, conn, vars)
      end
    end
  end
end
