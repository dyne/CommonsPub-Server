# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.Communities.MutationsTest do
  use CommonsPub.Web.ConnCase, async: true
  import CommonsPub.Utils.Simulation
  import CommonsPub.Web.Test.GraphQLAssertions
  import CommonsPub.Web.Test.GraphQLFields
  import CommonsPub.Utils.Simulation

  describe "create_community" do
    test "works for a user or instance admin" do
      alice = fake_user!()
      lucy = fake_user!(%{is_instance_admin: true})
      q = create_community_mutation()

      for conn <- [user_conn(alice), user_conn(lucy)] do
        ci = community_input()
        comm = grumble_post_key(q, conn, :create_community, %{community: ci})
        assert_community_created(ci, comm)
      end
    end

    test "does not work for a guest" do
      ci = community_input()
      q = create_community_mutation()
      assert err = grumble_post_errors(q, json_conn(), %{community: ci})
    end
  end

  describe "update community" do
    test "works for the community owner or admin" do
      alice = fake_user!()
      lucy = fake_admin!()
      comm = fake_community!(alice)
      conns = [user_conn(alice), user_conn(lucy)]
      q = update_community_mutation()

      for conn <- conns do
        ci = community_update_input()
        vars = %{community: ci, community_id: comm.id}
        comm = grumble_post_key(q, conn, :update_community, vars)
        assert_community_updated(ci, comm)
      end
    end

    test "does not work for a random or a guest" do
      [alice, bob] = some_fake_users!(2)
      comm = fake_community!(alice)

      for conn <- [user_conn(bob), json_conn()] do
        ci = community_update_input()
        vars = %{community: ci, community_id: comm.id}
        q = update_community_mutation()
        grumble_post_errors(q, conn, vars)
      end
    end
  end
end
