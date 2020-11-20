# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.FlagsTest do
  use CommonsPub.Web.ConnCase, async: true
  import CommonsPub.Utils.Simulation
  import CommonsPub.Web.Test.ConnHelpers
  import CommonsPub.Web.Test.GraphQLAssertions
  import CommonsPub.Web.Test.GraphQLFields

  describe "flag" do
    test "is not found for people who can't see the flag" do
      [alice, bob, eve] = some_fake_users!(3)
      flag = flag!(alice, bob)
      q = flag_query()

      for conn <- [json_conn(), user_conn(bob), user_conn(eve)] do
        grumble_post_errors(q, conn, %{flag_id: flag.id})
      end
    end

    test "is visible to the creator" do
      [alice, bob] = some_fake_users!(2)
      flag = flag!(alice, bob)
      q = flag_query()
      conn = user_conn(alice)
      assert_flag(flag, grumble_post_key(q, conn, :flag, %{flag_id: flag.id}))
    end
  end

  describe "flag.creator" do
    test "works for the creator or an admin" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      flag = flag!(alice, bob)
      q = flag_query(fields: [creator: user_fields()])

      for conn <- [user_conn(alice), user_conn(lucy)] do
        flag2 = assert_flag(flag, grumble_post_key(q, conn, :flag, %{flag_id: flag.id}))
        assert_user(alice, flag2.creator)
      end
    end
  end

  describe "flag.context" do
    test "works for the flagger or an admin with a user flag" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      flag = flag!(alice, bob)
      q = flag_query(fields: [context: [user_spread()]])

      for conn <- [user_conn(alice), user_conn(lucy)] do
        flag2 = assert_flag(flag, grumble_post_key(q, conn, :flag, %{flag_id: flag.id}))
        assert_user(bob, flag2.context)
      end
    end

    test "works for the flagger or an admin with a community flag" do
      alice = fake_user!()
      bob = fake_community!(alice)
      lucy = fake_admin!()
      flag = flag!(alice, bob)
      q = flag_query(fields: [context: [community_spread()]])

      for conn <- [user_conn(alice), user_conn(lucy)] do
        flag2 = assert_flag(flag, grumble_post_key(q, conn, :flag, %{flag_id: flag.id}))
        assert_community(bob, flag2.context)
      end
    end

    test "works for the flagger or an admin with a collection flag" do
      alice = fake_user!()
      bob = fake_community!(alice)
      eve = fake_collection!(alice, bob)
      lucy = fake_admin!()
      flag = flag!(alice, eve)
      q = flag_query(fields: [context: [collection_spread()]])

      for conn <- [user_conn(alice), user_conn(lucy)] do
        flag2 = assert_flag(flag, grumble_post_key(q, conn, :flag, %{flag_id: flag.id}))
        assert_collection(eve, flag2.context)
      end
    end
  end

  # # defp assert_already_flagged(errs, path) do
  # #   assert [err] = errs
  # #   assert %{"code" => code, "message" => message} = err
  # #   assert %{"path" => ^path, "locations" => [loc]} = err
  # #   assert code == "already_flagged"
  # #   assert message == "already flagged"
  # #   assert_location(loc)
  # # end
end
