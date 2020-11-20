# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.UsersTest do
  use CommonsPub.Web.ConnCase, async: true
  import CommonsPub.Web.Test.Automaton
  import CommonsPub.Web.Test.GraphQLAssertions
  import CommonsPub.Web.Test.GraphQLFields
  import CommonsPub.Utils.Trendy
  import CommonsPub.Utils.Simulation
  import Grumble
  import Zest
  alias CommonsPub.Utils.Simulation

  describe "username_available" do
    test "works for a guest or a user" do
      alice = fake_user!()
      q = username_available_query()

      for conn <- [json_conn(), user_conn(alice)] do
        vars = %{username: Simulation.preferred_username()}
        assert true == grumble_post_key(q, conn, :username_available, vars)
        vars = %{username: alice.character.preferred_username}
        assert false == grumble_post_key(q, conn, :username_available, vars)
      end
    end
  end

  describe "me" do
    test "works for a logged in user" do
      alice = fake_user!()
      q = me_query()
      me = grumble_post_key(q, user_conn(alice), :me)
      assert_me(alice, me)
    end

    test "does not work for a guest" do
      assert_not_logged_in(grumble_post_errors(me_query(), json_conn()), ["me"])
    end
  end

  describe "user" do
    test "Works for anyone with a public user" do
      alice = fake_user!()
      lucy = fake_admin!()
      q = user_query()

      for conn <- [json_conn(), user_conn(alice), user_conn(lucy)] do
        user = grumble_post_key(q, conn, :user, %{user_id: alice.id})
        assert_user(alice, user)
      end
    end
  end

  describe "user.last_activity" do
    @tag :skip
    test "placeholder" do
    end
  end

  describe "user.my_follow" do
    test "is nil for a guest or a non-following user or instance admin" do
      [alice, bob] = some_fake_users!(%{}, 2)
      lucy = fake_admin!()
      vars = %{user_id: bob.id}
      q = user_query(fields: [my_follow: follow_fields()])

      for conn <- [json_conn(), user_conn(alice), user_conn(lucy)] do
        user = assert_user(bob, grumble_post_key(q, conn, :user, vars))
        assert user.my_follow == nil
      end
    end

    test "works for a following user or instance admin" do
      [alice, bob] = some_fake_users!(%{}, 2)
      lucy = fake_admin!()
      vars = %{user_id: bob.id}
      q = user_query(fields: [my_follow: follow_fields()])

      for user <- [alice, lucy] do
        follow = follow!(user, bob)
        user2 = assert_user(bob, grumble_post_key(q, user_conn(user), :user, vars))
        assert_follow(follow, user2.my_follow)
      end
    end
  end

  describe "user.my_like" do
    test "is nil for a guest or a non-liking user or instance admin" do
      [alice, bob] = some_fake_users!(%{}, 2)
      lucy = fake_admin!()
      vars = %{user_id: bob.id}
      q = user_query(fields: [my_like: like_fields()])

      for conn <- [json_conn(), user_conn(alice), user_conn(lucy)] do
        user = assert_user(bob, grumble_post_key(q, conn, :user, vars))
        assert user.my_like == nil
      end
    end

    test "works for a liking user or instance admin" do
      [alice, bob] = some_fake_users!(%{}, 2)
      lucy = fake_admin!()
      vars = %{user_id: bob.id}
      q = user_query(fields: [my_like: like_fields()])

      for user <- [alice, lucy] do
        like = like!(user, bob)
        user2 = assert_user(bob, grumble_post_key(q, user_conn(user), :user, vars))
        assert_like(like, user2.my_like)
      end
    end
  end

  describe "user.collection_follows" do
    test "works for anyone" do
      [alice, bob, dave, eve] = some_fake_users!(4)
      lucy = fake_admin!()
      # 9
      comms = some_fake_communities!(3, [alice, bob, dave])
      # 27
      colls = some_fake_collections!(1, [alice, bob, dave], comms)
      follows = pam(colls, &follow!(eve, &1))

      params = [
        collection_follows_after: list_type(:cursor),
        collection_follows_before: list_type(:cursor),
        collection_follows_limit: :int
      ]

      query = user_query(fields: [collection_follows_subquery()], params: params)
      user_conns = pam([alice, bob, dave, eve, lucy], &user_conn/1)

      each([json_conn() | user_conns], fn conn ->
        child_page_test(%{
          query: query,
          vars: %{user_id: eve.id},
          connection: conn,
          parent_key: :user,
          child_key: :collection_follows,
          default_limit: 10,
          total_count: 27,
          parent_data: eve,
          child_data: follows,
          assert_parent: &assert_user/2,
          assert_child: &assert_follow/2,
          cursor_fn: &[&1.id],
          after: :collection_follows_after,
          before: :collection_follows_before,
          limit: :collection_follows_limit
        })
      end)
    end
  end

  describe "user.community_follows" do
    test "works for anyone" do
      [alice, bob, dave, eve] = some_fake_users!(4)
      lucy = fake_admin!()
      comms = some_fake_communities!(9, [alice, bob, dave])
      follows = pam(comms, &follow!(eve, &1))

      params = [
        community_follows_after: list_type(:cursor),
        community_follows_before: list_type(:cursor),
        community_follows_limit: :int
      ]

      query = user_query(fields: [community_follows_subquery()], params: params)
      user_conns = pam([alice, bob, dave, eve, lucy], &user_conn/1)

      each([json_conn() | user_conns], fn conn ->
        child_page_test(%{
          query: query,
          vars: %{user_id: eve.id},
          connection: conn,
          parent_key: :user,
          child_key: :community_follows,
          default_limit: 10,
          total_count: 27,
          parent_data: eve,
          child_data: follows,
          assert_parent: &assert_user/2,
          assert_child: &assert_follow/2,
          cursor_fn: &[&1.id],
          after: :community_follows_after,
          before: :community_follows_before,
          limit: :community_follows_limit
        })
      end)
    end
  end

  describe "user.user_follows" do
    test "works for anyone" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      users = some_fake_users!(25) ++ [lucy, bob]
      follows = pam(users, &follow!(alice, &1))

      params = [
        user_follows_after: list_type(:cursor),
        user_follows_before: list_type(:cursor),
        user_follows_limit: :int
      ]

      query = user_query(fields: [user_follows_subquery()], params: params)
      user_conns = pam([alice, bob, lucy], &user_conn/1)

      each([json_conn() | user_conns], fn conn ->
        child_page_test(%{
          query: query,
          vars: %{user_id: alice.id},
          connection: conn,
          parent_key: :user,
          child_key: :user_follows,
          default_limit: 10,
          total_count: 27,
          parent_data: alice,
          child_data: follows,
          assert_parent: &assert_user/2,
          assert_child: &assert_follow/2,
          cursor_fn: &[&1.id],
          after: :user_follows_after,
          before: :user_follows_before,
          limit: :user_follows_limit
        })
      end)
    end
  end

  describe "user.follows" do
    test "works for anyone for a public user" do
      [alice, bob, eve] = some_fake_users!(3)
      lucy = fake_admin!()
      users = [bob | some_fake_users!(26)]
      follows = pam(users, &follow!(alice, &1))

      params = [
        follows_after: list_type(:cursor),
        follows_before: list_type(:cursor),
        follows_limit: :int
      ]

      query =
        user_query(
          params: params,
          fields: [:follow_count, follows_subquery()]
        )

      user_conns = pam([alice, bob, eve, lucy], &user_conn/1)

      each([json_conn() | user_conns], fn conn ->
        child_page_test(%{
          query: query,
          vars: %{user_id: alice.id},
          connection: conn,
          parent_key: :user,
          child_key: :follows,
          count_key: :follow_count,
          default_limit: 5,
          total_count: 27,
          parent_data: alice,
          child_data: follows,
          assert_parent: &assert_user/2,
          assert_child: &assert_follow/2,
          cursor_fn: &[&1.id],
          after: :follows_after,
          before: :follows_before,
          limit: :follows_limit
        })
      end)
    end
  end

  describe "user.followers" do
    test "works for anyone for a public user" do
      [alice, bob, eve] = some_fake_users!(3)
      lucy = fake_admin!()
      bob_follow = follow!(bob, alice)
      follows = some_randomer_follows!(26, alice) ++ [bob_follow]

      params = [
        followers_after: list_type(:cursor),
        followers_before: list_type(:cursor),
        followers_limit: :int
      ]

      query =
        user_query(
          params: params,
          fields: [:follower_count, followers_subquery()]
        )

      user_conns = pam([alice, bob, eve, lucy], &user_conn/1)

      each([json_conn() | user_conns], fn conn ->
        child_page_test(%{
          query: query,
          vars: %{user_id: alice.id},
          connection: conn,
          parent_key: :user,
          child_key: :followers,
          count_key: :follower_count,
          default_limit: 5,
          total_count: 27,
          parent_data: alice,
          child_data: follows,
          assert_parent: &assert_user/2,
          assert_child: &assert_follow/2,
          cursor_fn: &[&1.id],
          after: :followers_after,
          before: :followers_before,
          limit: :followers_limit
        })
      end)
    end
  end

  describe "user.likers" do
    test "works for anyone for a public user" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      likes = some_randomer_likes!(27, alice)

      params = [
        likers_after: list_type(:cursor),
        likers_before: list_type(:cursor),
        likers_limit: :int
      ]

      query = user_query(fields: [:liker_count, likers_subquery()], params: params)
      conns = pam([alice, bob, lucy], &user_conn/1)

      each([json_conn() | conns], fn conn ->
        child_page_test(%{
          query: query,
          vars: %{user_id: alice.id},
          connection: conn,
          parent_key: :user,
          child_key: :likers,
          count_key: :liker_count,
          default_limit: 5,
          total_count: 27,
          parent_data: alice,
          child_data: likes,
          assert_parent: &assert_user/2,
          assert_child: &assert_like/2,
          cursor_fn: &[&1.id],
          after: :likers_after,
          before: :likers_before,
          limit: :likers_limit
        })
      end)
    end
  end

  describe "user.likes" do
    test "works for anyone for a public user" do
      [alice, bob, dave, eve] = some_fake_users!(4)
      lucy = fake_admin!()
      comms = some_fake_communities!(9, [bob])
      #
      colls = some_fake_collections!(2, [dave], comms)
      likes = pam(colls ++ comms, &like!(alice, &1))

      params = [
        likes_after: list_type(:cursor),
        likes_before: list_type(:cursor),
        likes_limit: :int
      ]

      query = user_query(fields: [:like_count, likes_subquery()], params: params)
      conns = [user_conn(alice), user_conn(bob), user_conn(lucy), user_conn(eve), json_conn()]

      each(conns, fn conn ->
        child_page_test(%{
          query: query,
          vars: %{user_id: alice.id},
          connection: conn,
          parent_key: :user,
          child_key: :likes,
          count_key: :like_count,
          default_limit: 5,
          total_count: 27,
          parent_data: alice,
          child_data: likes,
          assert_parent: &assert_user/2,
          assert_child: &assert_likes_eq/2,
          cursor_fn: &[&1.id],
          after: :likes_after,
          before: :likes_before,
          limit: :likes_limit
        })
      end)
    end
  end

  describe "user.icon" do
    test "works" do
      user = fake_user!()

      assert {:ok, upload} =
               CommonsPub.Uploads.upload(
                 CommonsPub.Uploads.IconUploader,
                 user,
                 %{upload: %{path: "test/fixtures/images/150.png", filename: "150.png"}},
                 %{}
               )

      assert {:ok, user} = CommonsPub.Users.update(user, %{icon_id: upload.id})

      conn = user_conn(user)

      q =
        user_query(
          fields: [icon: [:id, :url, :media_type, upload: [:path, :size], mirror: [:url]]]
        )

      assert resp = grumble_post_key(q, conn, :user, %{user_id: user.id})
      assert resp["icon"]["id"] == user.icon_id
      assert_url(resp["icon"]["url"])
      assert resp["icon"]["upload"]
    end
  end

  describe "user.image" do
    test "works" do
      user = fake_user!()

      assert {:ok, upload} =
               CommonsPub.Uploads.upload(
                 CommonsPub.Uploads.ImageUploader,
                 user,
                 %{upload: %{path: "test/fixtures/images/150.png", filename: "150.png"}},
                 %{}
               )

      assert {:ok, user} = CommonsPub.Users.update(user, %{image_id: upload.id})

      conn = user_conn(user)

      q =
        user_query(
          fields: [image: [:id, :url, :media_type, upload: [:path, :size], mirror: [:url]]]
        )

      assert resp = grumble_post_key(q, conn, :user, %{user_id: user.id})
      assert resp["image"]["id"] == user.image_id
      assert_url(resp["image"]["url"])
      assert resp["image"]["upload"]
    end
  end

  # describe "comments" do
  #   @tag :skip
  #   test "placeholder" do
  #   end
  # end

  # describe "inbox" do
  #   @tag :skip # broken
  #   test "Works for self" do
  #     alice = fake_user!()
  #     bob = fake_user!()
  #     comm = fake_community!(bob)
  #     conn = user_conn(alice)
  #     query = """
  #     { me {
  #         #{me_basics()}
  #         user {
  #           #{user_basics()}
  #           inbox { #{page_basics()} edges { #{activity_basics()} }
  #         }
  #       }
  #     }
  #     """
  #     assert %{"me" => me} = gql_post_data(conn, %{query: query})
  #     me = assert_me(me)
  #     assert %{"user" => user2} = me
  #     user2 = assert_user(alice, user2)
  #     assert %{"inbox" => inbox} = user2
  #     edges = assert_edges_page(inbox)
  #     assert Enum.count(edges.edges) == 1
  #     for edge <- edges.edges do
  #       activity = assert_activity(edge)
  #     end
  #   end
  #   # test "Does not work for other" do
  #   # end
  #   # test "Does not work for guest" do
  #   # end
  # end

  # describe "outbox" do

  #   test "Works for self" do
  #     user = fake_user!()
  #     conn = user_conn(user)
  #     query = """
  #     { me {
  #         #{me_basics()}
  #         user {
  #           #{user_basics()}
  #           outbox { #{page_basics()} edges { #{activity_basics()} } }
  #         }
  #       }
  #     }
  #     """
  #     assert %{"me" => me} = gql_post_data(conn, %{query: query})
  #     me = assert_me(me)
  #     assert %{"user" => user2} = me
  #     user2 = assert_user(user, user2)
  #     assert %{"outbox" => outbox} = user2
  #     edges = assert_edges_page(outbox)
  #     # assert Enum.count(edges.edges) == 5
  #     for edge <- edges.edges do
  #       activity = assert_activity(edge)
  #     end
  #   end
  # end
end
