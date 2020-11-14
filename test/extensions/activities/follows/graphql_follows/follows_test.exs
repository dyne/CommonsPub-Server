# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.FollowsTest do
  use CommonsPub.Web.ConnCase
  alias CommonsPub.Follows
  # import CommonsPub.MediaProxy.URLBuilder, only: [encode: 1]
  import CommonsPub.Test.Faking
  import CommonsPub.Web.Test.ConnHelpers
  import CommonsPub.Web.Test.GraphQLAssertions
  import CommonsPub.Web.Test.GraphQLFields
  import Tesla.Mock

  setup do
    mock(fn
      env ->
        apply(CommonsPub.HttpRequestMock, :request, [env])
    end)

    :ok
  end

  describe "follow" do
    test "works for guest for a public follow of a user" do
      [alice, bob] = some_fake_users!(2)
      # alice follows bob
      {:ok, follow} = Follows.create(alice, bob, %{is_local: true})
      q = follow_query()
      conn = json_conn()
      follow2 = grumble_post_key(q, conn, :follow, %{follow_id: follow.id})
      assert_follow(follow, follow2)
    end

    test "works for guest for a public follow of a community" do
      alice = fake_user!()
      bob = fake_community!(alice, nil, %{is_local: true})
      {:ok, follow} = Follows.one(creator: alice.id, context: bob.id)
      q = follow_query()
      conn = json_conn()
      follow2 = grumble_post_key(q, conn, :follow, %{follow_id: follow.id})
      assert_follow(follow, follow2)
    end

    test "works for guest for a public follow of a collection" do
      alice = fake_user!()
      bob = fake_community!(alice, nil, %{is_local: true})
      _celia = fake_collection!(alice, bob, %{is_local: true})
      {:ok, follow} = Follows.one(creator: alice.id, context: bob.id)
      q = follow_query()
      conn = json_conn()
      follow2 = grumble_post_key(q, conn, :follow, %{follow_id: follow.id})
      assert_follow(follow, follow2)
    end
  end

  describe "follow.creator" do
    test "works for guest" do
      alice = fake_user!()
      bob = fake_user!()
      # alice follows bob
      {:ok, follow} = Follows.create(alice, bob, %{is_local: true})
      q = follow_query(fields: [creator: user_fields()])
      conn = json_conn()
      follow2 = assert_follow(follow, grumble_post_key(q, conn, :follow, %{follow_id: follow.id}))
      assert_user(alice, follow2.creator)
    end
  end

  describe "follow.context" do
    test "works for guest with a user follow" do
      alice = fake_user!()
      bob = fake_user!()
      follow = follow!(alice, bob)
      q = follow_query(fields: [context: [user_spread()]])
      conn = json_conn()
      follow2 = assert_follow(follow, grumble_post_key(q, conn, :follow, %{follow_id: follow.id}))
      assert_user(bob, follow2.context)
    end

    test "works for guest with a community follow" do
      alice = fake_user!()
      bob = fake_community!(alice)
      q = follow_query(fields: [context: [community_spread()]])
      conn = json_conn()
      {:ok, follow} = Follows.one(creator: alice.id, context: bob.id)
      follow2 = assert_follow(follow, grumble_post_key(q, conn, :follow, %{follow_id: follow.id}))
      assert_community(bob, follow2.context)
    end

    test "works for guest with a collection follow" do
      alice = fake_user!()
      bob = fake_community!(alice)
      eve = fake_collection!(alice, bob)
      q = follow_query(fields: [context: [collection_spread()]])
      conn = json_conn()
      {:ok, follow} = Follows.one(creator: alice.id, context: eve.id)
      follow2 = assert_follow(follow, grumble_post_key(q, conn, :follow, %{follow_id: follow.id}))
      assert_collection(eve, follow2.context)
    end
  end

  describe "createFollow" do
    test "works for a user following a user" do
      [alice, bob] = some_fake_users!(2)
      conn = user_conn(alice)
      q = create_follow_mutation()
      follow2 = assert_follow(grumble_post_key(q, conn, :create_follow, %{context_id: bob.id}))
      {:ok, follow} = Follows.one(creator: alice.id, context: bob.id)
      assert_follow(follow, follow2)
    end

    @remote_actor "https://kawen.space/users/karen"
    # bizarre error possibly related to cachex
    @tag :skip
    test "works for a user following a remote user" do
      actor = fake_user!()
      conn = user_conn(actor)
      q = follow_remote_actor_mutation()
      vars = %{url: @remote_actor}
      follow2 = grumble_post_key(q, conn, :follow_remote_actor, vars)
      {:ok, followed} = CommonsPub.ActivityPub.Adapter.get_actor_by_ap_id(@remote_actor)
      {:ok, follow} = Follows.one(creator: actor.id, context: followed.id)
      assert_follow(follow, follow2)
    end
  end

  # defp assert_already_following(errs, path) do
  #   assert [err] = errs
  #   assert %{"code" => code, "message" => message} = err
  #   assert %{"path" => ^path, "locations" => [loc]} = err
  #   assert code == "already_following"
  #   assert message == "already following"
  #   assert_location(loc)
  # end
end
