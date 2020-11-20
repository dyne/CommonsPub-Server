# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.Resources.MutationsTest do
  use CommonsPub.Web.ConnCase, async: true
  import CommonsPub.Utils.Simulation
  import CommonsPub.Web.Test.GraphQLAssertions
  import CommonsPub.Web.Test.GraphQLFields
  import CommonsPub.Utils.Simulation
  import Zest

  describe "create_resource" do
    test "works for users" do
      [alice, bob, eve] = some_fake_users!(3)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      coll = fake_collection!(bob, comm)
      q = create_resource_mutation(fields: [content: [:url], icon: [:url]])

      for conn <- [user_conn(alice), user_conn(bob), user_conn(eve), user_conn(lucy)] do
        vars = %{
          context_id: coll.id,
          resource: resource_input(),
          content: content_input(),
          icon: %{url: "https://via.placeholder.com/150.png"}
        }

        res = grumble_post_key(q, conn, :create_resource, vars)
        assert_resource(res)
        assert res["content"]["url"]
        assert res["icon"]["url"]
      end
    end

    test "does not work for a guest" do
      alice = fake_user!()
      comm = fake_community!(alice)
      coll = fake_collection!(alice, comm)
      q = create_resource_mutation()
      conn = json_conn()
      ri = resource_input()
      ci = content_input()
      vars = %{context_id: coll.id, resource: ri, content: ci}
      assert_not_logged_in(grumble_post_errors(q, conn, vars), ["createResource"])
    end
  end

  describe "update_resource" do
    @tag :skip
    test "works for the resource, collection or community creator or an admin" do
      [alice, bob, eve] = some_fake_users!(3)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      coll = fake_collection!(bob, comm)
      resource = fake_resource!(eve, coll)
      q = update_resource_mutation()

      each([user_conn(alice), user_conn(bob), user_conn(eve), user_conn(lucy)], fn conn ->
        ri = resource_input()
        vars = %{resource_id: resource.id, resource: ri, content: content_input()}
        assert_resource(grumble_post_key(q, conn, :update_resource, vars))
      end)
    end

    test "does not work for a guest" do
      alice = fake_user!()
      comm = fake_community!(alice)
      coll = fake_collection!(alice, comm)
      resource = fake_resource!(alice, coll)
      conn = json_conn()
      q = update_resource_mutation()
      ri = resource_input()
      vars = %{resource_id: resource.id, resource: ri}
      assert_not_logged_in(grumble_post_errors(q, conn, vars), ["updateResource"])
    end
  end

  describe "copy_resource" do
    @tag :skip
    test "works for a user" do
      [alice, bob] = some_fake_users!(2)
      comm = fake_community!(alice)
      coll = fake_collection!(alice, comm)
      coll2 = fake_collection!(alice, comm)
      resource = fake_resource!(alice, coll)
      conn = user_conn(bob)
      q = copy_resource_mutation()
      vars = %{resource_id: resource.id, context_id: coll2.id}
      assert_copied_resource(resource, grumble_post_key(q, conn, :copy_resource, vars))
    end

    test "does not work for a guest" do
      alice = fake_user!()
      comm = fake_community!(alice)
      coll = fake_collection!(alice, comm)
      coll2 = fake_collection!(alice, comm)
      resource = fake_resource!(alice, coll)
      conn = json_conn()
      q = copy_resource_mutation()
      vars = %{resource_id: resource.id, context_id: coll2.id}
      assert_not_logged_in(grumble_post_errors(q, conn, vars), ["copyResource"])
    end
  end

  describe "delete (via common)" do
    @tag :skip
    test "works for creator" do
    end

    @tag :skip
    test "works for collection creator" do
    end

    @tag :skip
    test "works for community creator" do
    end

    @tag :skip
    test "works for admin" do
    end

    @tag :skip
    test "doesn't work for random" do
    end

    @tag :skip
    test "doesn't work for guest" do
    end
  end

  describe "follow (via common)" do
    @tag :skip
    test "does not work" do
    end
  end
end
