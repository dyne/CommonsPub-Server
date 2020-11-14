# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.Collections.CollectionTest do
  use CommonsPub.Web.ConnCase, async: true
  import CommonsPub.Web.Test.Automaton
  import CommonsPub.Web.Test.GraphQLAssertions
  import CommonsPub.Web.Test.GraphQLFields
  import CommonsPub.Utils.Trendy
  import CommonsPub.Test.Faking
  import Grumble
  import Zest
  alias CommonsPub.{Follows, Likes, Threads}

  describe "collection" do
    test "works for the owner, randoms, admins and guests" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      coll = fake_collection!(alice, comm)
      conns = [user_conn(alice), user_conn(bob), user_conn(lucy), json_conn()]
      vars = %{collection_id: coll.id}

      for conn <- conns do
        coll2 = grumble_post_key(collection_query(), conn, :collection, vars)
        assert_collection(coll, coll2)
      end
    end
  end

  describe "collection.last_activity" do
    @tag :skip
    test "placeholder" do
    end
  end

  describe "collection.my_like" do
    test "is nil for a guest or a non-liking user or instance admin" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      coll = fake_collection!(bob, comm)
      vars = %{collection_id: coll.id}
      q = collection_query(fields: [my_like: like_fields()])

      for conn <- [json_conn(), user_conn(alice), user_conn(bob), user_conn(lucy)] do
        coll2 = grumble_post_key(q, conn, :collection, vars)
        coll2 = assert_collection(coll, coll2)
        assert coll2.my_like == nil
      end
    end

    test "works for a liking user or instance admin" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      coll = fake_collection!(bob, comm)
      vars = %{collection_id: coll.id}
      q = collection_query(fields: [my_like: like_fields()])

      for user <- [alice, bob, lucy] do
        {:ok, like} = Likes.create(user, coll, %{is_local: true})
        coll2 = grumble_post_key(q, user_conn(user), :collection, vars)
        coll2 = assert_collection(coll, coll2)
        assert_like(like, coll2.my_like)
      end
    end
  end

  describe "collection.my_follow" do
    test "is nil for a guest or a non-following user or instance admin" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      coll = fake_collection!(bob, comm)
      vars = %{collection_id: coll.id}
      q = collection_query(fields: [my_follow: follow_fields()])

      for conn <- [json_conn(), user_conn(alice), user_conn(lucy)] do
        coll2 = grumble_post_key(q, conn, :collection, vars)
        coll2 = assert_collection(coll, coll2)
        assert coll2.my_follow == nil
      end
    end

    test "works for a following user or instance admin" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      coll = fake_collection!(bob, comm)
      vars = %{collection_id: coll.id}
      q = collection_query(fields: [my_follow: follow_fields()])
      coll2 = grumble_post_key(q, user_conn(bob), :collection, vars)
      coll2 = assert_collection(coll, coll2)
      assert_follow(coll2.my_follow)

      for user <- [alice, lucy] do
        {:ok, follow} = Follows.create(user, coll, %{is_local: true})
        coll2 = grumble_post_key(q, user_conn(user), :collection, vars)
        coll2 = assert_collection(coll, coll2)
        assert_follow(follow, coll2.my_follow)
      end
    end
  end

  describe "collection.my_flag" do
    test "is nil for a guest or a non-flagging user or instance admin" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      coll = fake_collection!(bob, comm)
      vars = %{collection_id: coll.id}
      q = collection_query(fields: [my_flag: flag_fields()])

      for conn <- [json_conn(), user_conn(alice), user_conn(bob), user_conn(lucy)] do
        coll2 = grumble_post_key(q, conn, :collection, vars)
        coll2 = assert_collection(coll, coll2)
        assert coll2.my_flag == nil
      end
    end

    test "works for a flagging user or instance admin" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      coll = fake_collection!(bob, comm)
      vars = %{collection_id: coll.id}
      q = collection_query(fields: [my_flag: flag_fields()])

      for user <- [alice, bob, lucy] do
        flag = flag!(user, coll)
        coll2 = assert_collection(coll, grumble_post_key(q, user_conn(user), :collection, vars))
        coll2 = assert_collection(coll, coll2)
        assert_flag(flag, coll2.my_flag)
      end
    end
  end

  describe "collection.creator" do
    @tag :skip
    test "placeholder" do
    end
  end

  describe "collection.context" do
    test "works for anyone" do
      [alice, bob, eve] = some_fake_users!(3)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      coll = fake_collection!(bob, comm)
      vars = %{collection_id: coll.id}
      q = collection_query(fields: [community: community_fields()])
      conns = [user_conn(alice), user_conn(bob), user_conn(lucy), user_conn(eve), json_conn()]

      for conn <- conns do
        coll2 = assert_collection(coll, grumble_post_key(q, conn, :collection, vars))
        assert_communities_eq(comm, coll2.community)
      end
    end
  end

  describe "collection.resources" do
    test "works for anyone for a public collection" do
      [alice, bob, eve] = some_fake_users!(3)
      lucy = fake_admin!()
      users = some_fake_users!(9)
      comm = fake_community!(alice)
      coll = fake_collection!(bob, comm)
      conns = Enum.map([alice, bob, lucy, eve], &user_conn/1)
      # 27
      res = some_fake_resources!(3, users, [coll])

      each([json_conn() | conns], fn conn ->
        params = [
          resources_after: list_type(:cursor),
          resources_before: list_type(:cursor),
          resources_limit: :int
        ]

        query =
          collection_query(
            params: params,
            fields: [:resource_count, resources_subquery()]
          )

        child_page_test(%{
          query: query,
          vars: %{context_id: coll.id},
          connection: conn,
          parent_key: :collection,
          child_key: :resources,
          count_key: :resource_count,
          default_limit: 5,
          total_count: 27,
          parent_data: coll,
          child_data: res,
          assert_parent: &assert_collection/2,
          assert_child: &assert_resource/2,
          cursor_fn: &[&1.id],
          after: :resources_after,
          before: :resources_before,
          limit: :resources_limit
        })
      end)
    end
  end

  describe "collection.followers" do
    test "works for anyone for a public collection" do
      [alice, bob, eve] = some_fake_users!(3)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      coll = fake_collection!(bob, comm)
      {:ok, bob_follow} = Follows.one(context: coll.id, creator: bob.id)
      follows = some_randomer_follows!(26, coll) ++ [bob_follow]

      params = [
        followers_after: list_type(:cursor),
        followers_before: list_type(:cursor),
        followers_limit: :int
      ]

      query =
        collection_query(
          params: params,
          fields: [:follower_count, followers_subquery()]
        )

      conns = [user_conn(alice), user_conn(bob), user_conn(lucy), user_conn(eve), json_conn()]

      each(conns, fn conn ->
        child_page_test(%{
          query: query,
          vars: %{collection_id: coll.id},
          connection: conn,
          parent_key: :collection,
          child_key: :followers,
          count_key: :follower_count,
          default_limit: 5,
          total_count: 27,
          parent_data: coll,
          child_data: follows,
          assert_parent: &assert_collection/2,
          assert_child: &assert_follow/2,
          cursor_fn: &[&1.id],
          after: :followers_after,
          before: :followers_before,
          limit: :followers_limit
        })
      end)
    end
  end

  describe "collection.likers" do
    test "works for anyone for a public collection" do
      [alice, bob, eve] = some_fake_users!(3)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      coll = fake_collection!(bob, comm)
      likes = some_randomer_likes!(27, coll)

      params = [
        likers_after: list_type(:cursor),
        likers_before: list_type(:cursor),
        likers_limit: :int
      ]

      query = collection_query(params: params, fields: [:liker_count, likers_subquery()])
      conns = Enum.map([alice, bob, lucy, eve], &user_conn/1)

      each([json_conn() | conns], fn conn ->
        child_page_test(%{
          query: query,
          vars: %{collection_id: coll.id},
          connection: conn,
          parent_key: :collection,
          child_key: :likers,
          count_key: :liker_count,
          default_limit: 5,
          total_count: 27,
          parent_data: coll,
          child_data: likes,
          assert_parent: &assert_collection/2,
          assert_child: &assert_like/2,
          cursor_fn: &[&1.id],
          after: :likers_after,
          before: :likers_before,
          limit: :likers_limit
        })
      end)
    end
  end

  describe "collection.flags" do
    # this test could do better to verify against the actual data
    test "empty for a guest or non-flagging user" do
      [alice, bob, eve, mallory] = some_fake_users!(%{}, 4)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      coll = fake_collection!(bob, comm)
      flag!(eve, coll)
      flag!(lucy, coll)
      q = collection_query(fields: [flags: page_fields(flag_fields())])
      vars = %{collection_id: coll.id}
      conns = [user_conn(mallory), json_conn()]

      for conn <- conns do
        coll2 = assert_collection(coll, grumble_post_key(q, conn, :collection, vars))
        assert_page(coll2.flags, 0, 0, false, false, &[&1.id])
      end
    end

    # TODO: alice and bob should also see 2
    # this test could do better to verify against the actual data
    test "not empty for a flagging user, collection owner, community owner or admin" do
      [alice, bob, eve] = some_fake_users!(%{}, 3)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      coll = fake_collection!(bob, comm)
      flag!(eve, coll)
      flag!(lucy, coll)
      q = collection_query(fields: [flags: page_fields(flag_fields())])
      vars = %{collection_id: coll.id}

      coll2 = assert_collection(coll, grumble_post_key(q, user_conn(eve), :collection, vars))
      _page = assert_page(coll2.flags, 1, 1, false, false, &[&1.id])

      for conn <- [user_conn(lucy)] do
        coll2 = assert_collection(coll, grumble_post_key(q, conn, :collection, vars))
        assert_page(coll2.flags, 2, 2, false, false, &[&1.id])
      end
    end
  end

  describe "collection.threads" do
    test "works for anyone when there are no threads" do
      [alice, bob, eve] = some_fake_users!(3)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      coll = fake_collection!(bob, comm)
      q = collection_query(fields: [threads_subquery(fields: [comments_subquery()])])
      vars = %{collection_id: coll.id}

      for conn <- [json_conn(), user_conn(eve), user_conn(bob), user_conn(alice), user_conn(lucy)] do
        coll2 = assert_collection(coll, grumble_post_key(q, conn, :collection, vars))
        assert %{threads: threads} = coll2
        assert_page(coll2.threads, 0, 0, false, false, & &1.id)
      end
    end

    test "works for anyone when there are threads" do
      [alice, bob] = some_fake_users!(2)
      lucy = fake_admin!()
      comm = fake_community!(alice)
      coll = fake_collection!(bob, comm)
      randomers = some_fake_users!(5)
      many_randomers = repeat_for_count(randomers, 25)
      # 25
      threads_and_initials =
        flat_pam_some(randomers, 5, fn user ->
          thread = fake_thread!(user, coll)
          comment = fake_comment!(user, thread)
          {thread, comment}
        end)

      threads_and_replies =
        zip(many_randomers, threads_and_initials, fn user, {thread, initial} ->
          reply = fake_reply!(user, thread, initial)
          {thread, reply}
        end)

      # final_replies =
      _ =
        zip(many_randomers, threads_and_replies, fn user, {thread, comment} ->
          fake_reply!(user, thread, comment)
        end)

      {_threads, _initials} = unpiz(threads_and_initials)
      # replies = Enum.map(threads_and_replies, &elem(&1, 1))
      # comments = final_replies ++ replies ++ initials
      q =
        collection_query(
          fields: [threads_subquery(fields: [comments_subquery(args: [limit: 1])])]
        )

      vars = %{collection_id: coll.id}

      for conn <- [json_conn(), user_conn(bob), user_conn(alice), user_conn(lucy)] do
        coll2 = assert_collection(coll, grumble_post_key(q, conn, :collection, vars))
        assert %{threads: threads} = coll2
        _threads = assert_page(threads, 5, 25, false, true, Threads.test_cursor(:followers))
        # initials2 = Enum.flat_map(threads.edges, fn thread ->
        #   assert_page(thread["comments"], 1, 3, nil, true, &(&1["id"])).edges
        # end)
        # assert Enum.count(initials2) == 10
        # each(Enum.reverse(initials), initials2, &assert_comment/2)
      end
    end
  end

  describe "collection.outbox" do
    @tag :skip
    test "placeholder" do
    end
  end

  describe "collection.icon" do
    test "works" do
      user = fake_user!()
      comm = fake_community!(user)
      coll = fake_collection!(user, comm)

      assert {:ok, upload} =
               CommonsPub.Uploads.upload(
                 CommonsPub.Uploads.IconUploader,
                 user,
                 %{upload: %{path: "test/fixtures/images/150.png", filename: "150.png"}},
                 %{}
               )

      assert {:ok, coll} = CommonsPub.Collections.update(user, coll, %{icon_id: upload.id})

      conn = user_conn(user)

      q =
        collection_query(
          fields: [icon: [:id, :url, :media_type, upload: [:path, :size], mirror: [:url]]]
        )

      assert resp = grumble_post_key(q, conn, :collection, %{collection_id: coll.id})
      assert resp["icon"]["id"] == coll.icon_id
      assert_url(resp["icon"]["url"])
      assert resp["icon"]["upload"]
    end
  end
end
