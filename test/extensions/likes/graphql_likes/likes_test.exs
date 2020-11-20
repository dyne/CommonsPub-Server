# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.LikesTest do
  use CommonsPub.Web.ConnCase, async: true
  alias CommonsPub.Likes
  # import CommonsPub.MediaProxy.URLBuilder, only: [encode: 1]
  import CommonsPub.Utils.Simulation
  import CommonsPub.Web.Test.ConnHelpers
  import CommonsPub.Web.Test.GraphQLAssertions
  import CommonsPub.Web.Test.GraphQLFields

  describe "like" do
    test "works for guest for a like of a user" do
      [alice, bob] = some_fake_users!(2)
      like = like!(alice, bob)
      q = like_query()
      conn = json_conn()
      assert_like(like, grumble_post_key(q, conn, :like, %{like_id: like.id}))
    end

    test "works for guest for a like of a community" do
      alice = fake_user!()
      bob = fake_community!(alice)
      like = like!(alice, bob)
      q = like_query()
      conn = json_conn()
      assert_like(like, grumble_post_key(q, conn, :like, %{like_id: like.id}))
    end

    test "works for guest for a like of a collection" do
      alice = fake_user!()
      bob = fake_community!(alice)
      celia = fake_collection!(alice, bob, %{is_local: true})
      like = like!(alice, celia)
      q = like_query()
      conn = json_conn()
      assert_like(like, grumble_post_key(q, conn, :like, %{like_id: like.id}))
    end
  end

  describe "like.creator" do
    test "works for guest" do
      [alice, bob] = some_fake_users!(2)
      like = like!(alice, bob)
      q = like_query(fields: [creator: user_fields()])
      conn = json_conn()
      like2 = assert_like(like, grumble_post_key(q, conn, :like, %{like_id: like.id}))
      assert_user(alice, like2.creator)
    end
  end

  describe "like.context" do
    test "works for guest with a user like" do
      [alice, bob] = some_fake_users!(2)
      like = like!(alice, bob)
      q = like_query(fields: [context: [user_spread()]])
      conn = json_conn()
      like2 = assert_like(like, grumble_post_key(q, conn, :like, %{like_id: like.id}))
      assert_user(bob, like2.context)
    end

    # community likes are blocked at present
    @tag :skip
    test "works for guest with a community like" do
      alice = fake_user!()
      bob = fake_community!(alice)
      like = like!(alice, bob)
      q = like_query(fields: [context: [community_spread()]])
      conn = json_conn()
      like2 = assert_like(like, grumble_post_key(q, conn, :like, %{like_id: like.id}))
      assert_community(bob, like2.context)
    end

    test "works for guest with a collection like" do
      alice = fake_user!()
      bob = fake_community!(alice)
      eve = fake_collection!(alice, bob)
      like = like!(alice, eve)
      q = like_query(fields: [context: [collection_spread()]])
      conn = json_conn()
      like2 = assert_like(like, grumble_post_key(q, conn, :like, %{like_id: like.id}))
      assert_collection(eve, like2.context)
    end
  end

  describe "create_like" do
    test "works for a user liking a user" do
      [alice, bob] = some_fake_users!(2)
      conn = user_conn(alice)
      q = create_like_mutation()
      vars = %{context_id: bob.id}
      like2 = grumble_post_key(q, conn, :create_like, vars)
      {:ok, like} = Likes.one(creator: alice.id, context: bob.id)
      assert_like(like, like2)
    end
  end
end
