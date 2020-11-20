# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.AdminTest do
  use CommonsPub.Web.ConnCase

  import CommonsPub.Utils.Simulation
  import ActivityPub.Factory
  alias CommonsPub.Utils.Simulation
  import CommonsPub.Web.Test.GraphQLFields

  describe "invites" do
    test "sends an invite" do
      user = fake_admin!()
      conn = user_conn(user)
      q = invite_mutation()

      assert true == grumble_post_key(q, conn, :send_invite, %{email: Simulation.email()})
    end

    test "fails if user is not an admin" do
      user = fake_user!()
      conn = user_conn(user)
      q = invite_mutation()

      assert [
               %{
                 "code" => "unauthorized",
                 "locations" => [%{"column" => 3, "line" => 2}],
                 "message" => "You do not have permission to do this.",
                 "path" => ["sendInvite"],
                 "status" => 403
               }
             ] = grumble_post_errors(q, conn, %{email: Simulation.email()})
    end
  end

  describe "actor deactivation" do
    test "deactivates an actor" do
      actor = actor()
      admin = fake_admin!()
      {:ok, actor} = CommonsPub.ActivityPub.Adapter.get_actor_by_ap_id(actor.ap_id)

      conn = user_conn(admin)
      q = deactivation_mutation()

      res = grumble_post_key(q, conn, :deactivate_user, %{id: actor.id})
      assert res["isDisabled"]
      {:ok, actor} = ActivityPub.Actor.get_by_local_id(actor.id)
      assert actor.deactivated
    end

    test "not permitted when user not admin" do
      actor = actor()
      user = fake_user!()
      {:ok, actor} = CommonsPub.ActivityPub.Adapter.get_actor_by_ap_id(actor.ap_id)

      conn = user_conn(user)
      q = deactivation_mutation()

      assert [
               %{
                 "code" => "unauthorized",
                 "locations" => [%{"column" => 3, "line" => 2}],
                 "message" => "You do not have permission to do this.",
                 "path" => ["deactivateUser"],
                 "status" => 403
               }
             ] = grumble_post_errors(q, conn, %{id: actor.id})
    end
  end
end
