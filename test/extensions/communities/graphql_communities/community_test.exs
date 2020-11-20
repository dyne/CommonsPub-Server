# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.CommunityTest do
  use CommonsPub.Web.ConnCase, async: true
  import CommonsPub.Web.Test.Automaton
  import CommonsPub.Web.Test.GraphQLAssertions
  import CommonsPub.Web.Test.GraphQLFields
  import CommonsPub.Utils.Trendy
  import CommonsPub.Utils.Simulation
  import CommonsPub.Web.Test.Orderings
  import CommonsPub.Web.Test.Automaton
  import Grumble
  import Zest
  alias CommonsPub.{Follows, Likes, Collections, Threads}

  describe "community" do
    test "works for anyone for a public community" do
      [alice, bob] = some_fake_users!(%{}, 2)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      vars = %{community_id: comm.id}

      for conn <- [json_conn(), user_conn(alice), user_conn(bob), user_conn(lucy)] do
        comm2 = grumble_post_key(community_query(), conn, :community, vars)
        _comm2 = assert_community(comm, comm2)
      end
    end
  end

  # describe "community.last_activity" do
  #   @tag :skip
  #   test "placeholder" do
  #   end
  # end

  describe "community.my_like" do
    test "is nil for a guest or a non-liking user or instance admin" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      vars = %{community_id: comm.id}
      q = community_query(fields: [my_like: like_fields()])

      for conn <- [json_conn(), user_conn(alice), user_conn(bob), user_conn(lucy)] do
        comm2 = grumble_post_key(q, conn, :community, vars)
        comm2 = assert_community(comm, comm2)
        assert comm2.my_like == nil
      end
    end

    test "works for a liking user or instance admin" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      vars = %{community_id: comm.id}
      q = community_query(fields: [my_like: like_fields()])

      for user <- [alice, bob, lucy] do
        {:ok, like} = Likes.create(user, comm, %{is_local: true})
        comm2 = grumble_post_key(q, user_conn(user), :community, vars)
        comm2 = assert_community(comm, comm2)
        assert_like(like, comm2.my_like)
      end
    end
  end

  describe "community.my_follow" do
    test "is nil for a guest or a non-following user or instance admin" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      vars = %{community_id: comm.id}
      q = community_query(fields: [my_follow: follow_fields()])

      for conn <- [json_conn(), user_conn(bob), user_conn(lucy)] do
        comm2 = assert_community(comm, grumble_post_key(q, conn, :community, vars))
        assert comm2.my_follow == nil
      end
    end

    test "works for a following user or instance admin" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      vars = %{community_id: comm.id}
      q = community_query(fields: [my_follow: follow_fields()])
      comm2 = grumble_post_key(q, user_conn(alice), :community, vars)
      comm2 = assert_community(comm, comm2)
      assert_follow(comm2.my_follow)

      for user <- [bob, lucy] do
        {:ok, follow} = Follows.create(user, comm, %{is_local: true})
        comm2 = assert_community(comm, grumble_post_key(q, user_conn(user), :community, vars))
        assert_follow(follow, comm2.my_follow)
      end
    end
  end

  describe "community.my_flag" do
    test "is nil for a guest or a non-flagging user or instance admin" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      vars = %{community_id: comm.id}
      q = community_query(fields: [my_flag: flag_fields()])

      for conn <- [json_conn(), user_conn(alice), user_conn(bob), user_conn(lucy)] do
        comm2 = assert_community(comm, grumble_post_key(q, conn, :community, vars))
        assert comm2.my_flag == nil
      end
    end

    test "works for a flagging user or instance admin" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!(%{is_instance_admin: true})
      comm = fake_community!(alice)
      vars = %{community_id: comm.id}
      q = community_query(fields: [my_flag: flag_fields()])

      for user <- [alice, bob, lucy] do
        flag = flag!(user, comm)
        comm2 = grumble_post_key(q, user_conn(user), :community, vars)
        comm2 = assert_community(comm, comm2)
        assert_flag(flag, comm2.my_flag)
      end
    end
  end

  describe "community.creator" do
    test "works for a guest" do
      alice = fake_user!()
      comm = fake_community!(alice)
      q = community_query(fields: [creator: user_fields()])
      conn = json_conn()
      comm2 = grumble_post_key(q, conn, :community, %{community_id: comm.id})
      comm2 = assert_community(comm, comm2)
      assert %{creator: creator} = comm2
      assert_user(alice, creator)
    end
  end

  describe "community.collections" do
    test "works for anyone for a public community" do
      [alice, bob, eve] = users = some_fake_users!(3)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      # 24
      colls = order_follower_count(some_fake_collections!(9, users, [comm]))
      conns = Enum.map([alice, bob, eve, lucy], &user_conn/1)

      each([json_conn() | conns], fn conn ->
        params = [
          collections_after: list_type(:cursor),
          collections_before: list_type(:cursor),
          collections_limit: :int
        ]

        q =
          community_query(
            params: params,
            fields: [:collection_count, collections_subquery(fields: [:follower_count])]
          )

        child_page_test(%{
          query: q,
          vars: %{community_id: comm.id},
          connection: conn,
          parent_key: :community,
          child_key: :collections,
          count_key: :collection_count,
          default_limit: 5,
          total_count: 27,
          parent_data: comm,
          child_data: colls,
          assert_parent: &assert_community/2,
          assert_child: &assert_collection/2,
          cursor_fn: Collections.cursor(:followers),
          after: :collections_after,
          before: :collections_before,
          limit: :collections_limit
        })
      end)
    end
  end

  describe "community.followers" do
    test "works for anyone for a public community" do
      [alice, bob, eve] = some_fake_users!(3)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      {:ok, bob_follow} = Follows.one(context: comm.id, creator: alice.id)
      follows = some_randomer_follows!(26, comm) ++ [bob_follow]

      params = [
        followers_after: list_type(:cursor),
        followers_before: list_type(:cursor),
        followers_limit: :int
      ]

      query =
        community_query(
          params: params,
          fields: [:follower_count, followers_subquery()]
        )

      conns = Enum.map([alice, bob, lucy, eve], &user_conn/1)

      each([json_conn() | conns], fn conn ->
        child_page_test(%{
          query: query,
          vars: %{community_id: comm.id},
          connection: conn,
          parent_key: :community,
          child_key: :followers,
          count_key: :follower_count,
          default_limit: 5,
          total_count: 27,
          parent_data: comm,
          child_data: follows,
          assert_parent: &assert_community/2,
          assert_child: &assert_follow/2,
          cursor_fn: &[&1.id],
          after: :followers_after,
          before: :followers_before,
          limit: :followers_limit
        })
      end)
    end
  end

  describe "community.likers" do
    test "works for anyone for a public community" do
      [alice, bob, eve] = some_fake_users!(3)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      likes = some_randomer_likes!(27, comm)

      params = [
        likers_after: list_type(:cursor),
        likers_before: list_type(:cursor),
        likers_limit: :int
      ]

      query = community_query(params: params, fields: [:liker_count, likers_subquery()])
      conns = Enum.map([alice, bob, lucy, eve], &user_conn/1)

      each([json_conn() | conns], fn conn ->
        child_page_test(%{
          query: query,
          vars: %{community_id: comm.id},
          connection: conn,
          parent_key: :community,
          child_key: :likers,
          count_key: :liker_count,
          default_limit: 5,
          total_count: 27,
          parent_data: comm,
          child_data: likes,
          assert_parent: &assert_community/2,
          assert_child: &assert_like/2,
          cursor_fn: &[&1.id],
          after: :likers_after,
          before: :likers_before,
          limit: :likers_limit
        })
      end)
    end
  end

  describe "community.flags" do
    test "empty for a guest or non-flagging user" do
      [alice, bob, eve] = some_fake_users!(3)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      flag!(bob, comm)
      flag!(lucy, comm)
      q = community_query(fields: [flags: page_fields(flag_fields())])
      vars = %{community_id: comm.id}

      each([user_conn(eve), json_conn()], fn conn ->
        comm2 = assert_community(comm, grumble_post_key(q, conn, :community, vars))
        assert_page(comm2.flags, 0, 0, false, false, &[&1.id])
      end)
    end

    # TODO: Bob should also see all
    test "not empty for a flagging user, community owner, community owner or admin" do
      [alice, bob] = some_fake_users!(%{}, 2)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      flag!(bob, comm)
      flag!(lucy, comm)
      q = community_query(fields: [flags: page_fields(flag_fields())])
      vars = %{community_id: comm.id}

      _comm2 = assert_community(comm, grumble_post_key(q, user_conn(bob), :community, vars))

      for conn <- [user_conn(lucy)] do
        comm2 = assert_community(comm, grumble_post_key(q, conn, :community, vars))
        assert_page(comm2.flags, 2, 2, false, false, &[&1.id])
      end
    end
  end

  # # TODO: the last comment view is clearly broken *sigh*

  describe "community.threads" do
    test "works for anyone when there are no threads" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      q = community_query(fields: [threads_subquery(fields: [comments_subquery()])])
      vars = %{community_id: comm.id}

      for conn <- [json_conn(), user_conn(bob), user_conn(alice), user_conn(lucy)] do
        comm2 = assert_community(comm, grumble_post_key(q, conn, :community, vars))
        assert %{threads: threads} = comm2
        assert_page(comm2.threads, 0, 0, false, false, & &1.id)
      end
    end

    test "works for anyone when there are threads" do
      [alice, bob] = some_fake_users!(%{}, 2)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      randomers = some_fake_users!(5)
      many_randomers = repeat_for_count(randomers, 25)

      threads_and_initials =
        flat_pam_some(randomers, 5, fn user ->
          thread = fake_thread!(user, comm)
          comment = fake_comment!(user, thread)
          {thread, comment}
        end)

      threads_and_replies =
        zip(many_randomers, threads_and_initials, fn user, {thread, initial} ->
          reply = fake_reply!(user, thread, initial)
          {thread, reply}
        end)

      _ =
        zip(many_randomers, threads_and_replies, fn user, {thread, comment} ->
          fake_reply!(user, thread, comment)
        end)

      {_thraeds, _initials} = unpiz(threads_and_initials)

      q =
        community_query(fields: [threads_subquery(fields: [comments_subquery(args: [limit: 1])])])

      vars = %{community_id: comm.id}

      for conn <- [json_conn(), user_conn(bob), user_conn(alice), user_conn(lucy)] do
        comm2 = assert_community(comm, grumble_post_key(q, conn, :community, vars))
        assert %{threads: threads} = comm2
        _threads = assert_page(threads, 5, 25, false, true, Threads.test_cursor(:followers))
        # initials2 = Enum.flat_map(threads.edges, fn thread ->
        #   assert_page(thread["comments"], 1, 3, nil, true, &(&1["id"])).edges
        # end)
        # assert Enum.count(initials2) == 5
        # each(Enum.reverse(initials), initials2, &assert_comment/2)
      end
    end
  end

  #   test "works for anyone when there are threads" do
  #     alice = fake_user!()
  #     lucy = fake_admin!()
  #     comm = fake_community!(alice)
  #     randomers = some_fake_users!(5)
  #     many_randomers = repeat_for_count(randomers, 25)
  #     # threads_and_initials = flat_pam_some(randomers, 5, fn user -> # 25
  #     #   thread = fake_thread!(user, comm)
  #     #   comment = fake_comment!(user, thread)
  #     #   {thread, comment}
  #     # end)
  #     # threads_and_replies =
  #     #   zip(many_randomers, threads_and_initials, fn user, {thread, initial} ->
  #     #     reply = fake_reply!(user, thread, initial)
  #     #     {thread, reply}
  #     #   end)
  #     # # final_replies =
  #     # _ = zip(many_randomers, threads_and_replies, fn user, {thread, comment} ->
  #     #     fake_reply!(user, thread, comment)
  #     #   end)
  #     # {_threads, _initials} = unpiz(threads_and_initials)
  #     # replies = Enum.map(threads_and_replies, &elem(&1, 1))
  #     # comments = final_replies ++ replies ++ initials
  #     # q = community_query(fields: [threads_subquery(fields: [comments_subquery(args: [limit: 1])])])
  #     # vars = %{community_id: comm.id}
  #     # for conn <- [json_conn(), user_conn(alice), user_conn(lucy)] do
  #     #   comm2 = assert_community(comm, grumble_post_key(q, conn, "community", vars))
  #     #   assert %{"threads" => threads} = comm2
  #     #   # _threads = assert_page(threads, 5, 25, false, true, &(&1["id"]))
  #     #   # initials2 = Enum.flat_map(threads.edges, fn thread ->
  #     #   #   assert_page(thread["comments"], 1, 3, false, true, &(&1["id"])).edges
  #     #   # end)
  #     #   # assert Enum.count(initials2) == 5
  #     #   # each(Enum.reverse(initials), initials2, &assert_comment/2)
  #     # end
  #   end

  # end

  # describe "community.outbox" do

  #   test "Works for self" do
  #     # user = fake_user!()
  #     # comm = fake_community!(user)
  #     # conn = user_conn(user)
  #     # query = """
  #     # { community(communityId: "#{comm.id}") {
  #     #     #{community_basics()}
  #     #     outbox { #{page_basics()} edges { #{activity_basics()} } }
  #     #   }
  #     # }
  #     # """
  #     # _coll = fake_collection!(user, comm)
  #     # _coll = fake_collection!(user, comm)
  #     # assert %{"community" => comm2} = gql_post_data(conn, %{query: query})
  #     # comm2 = assert_community(comm, comm2)
  #     # assert %{"outbox" => outbox} = comm2
  #     # edges = assert_edges_page(outbox)
  #     # assert Enum.count(edges.edges) == 3
  #     # for edge <- edges.edges do
  #     #   assert_activity(edge)
  #     # end
  #   end
  # end

  # describe "community.inbox" do
  #   @tag :skip
  #   test "placeholder" do
  #   end
  # end

  describe "community.icon" do
    test "works" do
      user = fake_user!()
      comm = fake_community!(user)

      assert {:ok, upload} =
               CommonsPub.Uploads.upload(
                 CommonsPub.Uploads.IconUploader,
                 user,
                 %{upload: %{path: "test/fixtures/images/150.png", filename: "150.png"}},
                 %{}
               )

      assert {:ok, comm} = CommonsPub.Communities.update(user, comm, %{icon_id: upload.id})

      conn = user_conn(user)
      q = community_query(fields: [icon: [:id, :url, upload: [:path]]])
      assert resp = grumble_post_key(q, conn, :community, %{community_id: comm.id})
      assert resp["icon"]["id"] == comm.icon_id
      assert_url(resp["icon"]["url"])
    end
  end

  describe "community.image" do
    test "works" do
      user = fake_user!()
      comm = fake_community!(user)

      assert {:ok, upload} =
               CommonsPub.Uploads.upload(
                 CommonsPub.Uploads.ImageUploader,
                 user,
                 %{upload: %{path: "test/fixtures/images/150.png", filename: "150.png"}},
                 %{}
               )

      assert {:ok, comm} = CommonsPub.Communities.update(user, comm, %{image_id: upload.id})

      conn = user_conn(user)
      q = community_query(fields: [image: [:id, :url, upload: [:path]]])
      assert resp = grumble_post_key(q, conn, :community, %{community_id: comm.id})
      assert resp["image"]["id"] == comm.image_id
      assert_url(resp["image"]["url"])
    end
  end
end
