# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.CommunitiesTest do
  use CommonsPub.Web.ConnCase, async: true
  import CommonsPub.Utils.Simulation
  import CommonsPub.Web.Test.GraphQLAssertions
  import CommonsPub.Web.Test.GraphQLFields
  import CommonsPub.Web.Test.Orderings
  import CommonsPub.Web.Test.ConnHelpers
  import CommonsPub.Web.Test.Automaton
  alias CommonsPub.Communities

  describe "communities" do
    test "works for a guest" do
      users = some_fake_users!(9)
      # 27
      communities = some_fake_communities!(3, users)

      root_page_test(%{
        query: communities_query(),
        connection: json_conn(),
        return_key: :communities,
        default_limit: 5,
        total_count: 27,
        data: order_follower_count(communities),
        assert_fn: &assert_community/2,
        cursor_fn: Communities.test_cursor(:followers),
        after: :communities_after,
        before: :communities_before,
        limit: :communities_limit
      })
    end
  end

  # describe "communities.last_activity" do
  #   @tag :skip
  #   test "placeholder" do
  #   end
  # end

  # describe "communities.my_like" do

  #   test "is nil for a guest or a non-liking user or instance admin" do
  #     [alice, bob] = some_fake_users!(2)
  #     lucy = fake_user!(%{is_instance_admin: true})
  #     comm = fake_community!(alice)
  #     vars = %{"communityId" => comm.id}
  #     q = community_query(fields: [my_like: like_fields()])
  #     for conn <- [json_conn(), user_conn(alice), user_conn(bob), user_conn(lucy)] do
  #       comm2 = grumble_post_key(q, conn, "community", vars)
  #       comm2 = assert_community(comm, comm2)
  #       assert comm2["myLike"] == nil
  #     end
  #   end

  #   test "works for a liking user or instance admin" do
  #     [alice, bob] = some_fake_users!(2)
  #     lucy = fake_user!(%{is_instance_admin: true})
  #     comm = fake_community!(alice)
  #     vars = %{"communityId" => comm.id}
  #     q = community_query(fields: [my_like: like_fields()])
  #     for user <- [alice, bob, lucy] do
  #       {:ok, like} = Likes.create(user, comm, %{is_local: true})
  #       comm2 = grumble_post_key(q, user_conn(user), "community", vars)
  #       comm2 = assert_community(comm, comm2)
  #       assert_like(like, comm2["myLike"])
  #     end
  #   end

  # end

  # describe "communities.my_follow" do

  #   test "is nil for a guest or a non-following user or instance admin" do
  #     [alice, bob] = some_fake_users!(2)
  #     lucy = fake_user!(%{is_instance_admin: true})
  #     comm = fake_community!(alice)
  #     vars = %{"communityId" => comm.id}
  #     q = community_query(fields: [my_follow: follow_fields()])
  #     for conn <- [json_conn(), user_conn(bob), user_conn(lucy)] do
  #       comm2 = assert_community(comm, grumble_post_key(q, conn, "community", vars))
  #       assert comm2["myFollow"] == nil
  #     end
  #   end

  #   test "works for a following user or instance admin" do
  #     [alice, bob] = some_fake_users!(2)
  #     lucy = fake_user!(%{is_instance_admin: true})
  #     comm = fake_community!(alice)
  #     vars = %{"communityId" => comm.id}
  #     q = community_query(fields: [my_follow: follow_fields()])
  #     comm2 = grumble_post_key(q, user_conn(alice), "community", vars)
  #     comm2 = assert_community(comm, comm2)
  #     assert_follow(comm2["myFollow"])

  #     for user <- [bob, lucy] do
  #       {:ok, follow} = Follows.create(user, comm, %{is_local: true})
  #       comm2 = assert_community(comm, grumble_post_key(q, user_conn(user), "community", vars))
  #       assert_follow(follow, comm2["myFollow"])
  #     end
  #   end

  # end

  # describe "communities.my_flag" do

  #   test "is nil for a guest or a non-flagging user or instance admin" do
  #     [alice, bob] = some_fake_users!(2)
  #     lucy = fake_user!(%{is_instance_admin: true})
  #     comm = fake_community!(alice)
  #     vars = %{"communityId" => comm.id}
  #     q = community_query(fields: [my_flag: flag_fields()])
  #     for conn <- [json_conn(), user_conn(alice), user_conn(bob), user_conn(lucy)] do
  #       comm2 = assert_community(comm, grumble_post_key(q, conn, "community", vars))
  #       assert comm2["myFlag"] == nil
  #     end
  #   end

  #   test "works for a flagging user or instance admin" do
  #     [alice, bob] = some_fake_users!(2)
  #     lucy = fake_user!(%{is_instance_admin: true})
  #     comm = fake_community!(alice)
  #     vars = %{"communityId" => comm.id}
  #     q = community_query(fields: [my_flag: flag_fields()])
  #     for user <- [alice, bob, lucy] do
  #       {:ok, flag} = Flags.create(user, comm, %{is_local: true, message: "bad"})
  #       comm2 = grumble_post_key(q, user_conn(user), "community", vars)
  #       comm2 = assert_community(comm, comm2)
  #       assert_flag(flag, comm2["myFlag"])
  #     end
  #   end

  # end

  # describe "communities.creator" do
  #   @tag :skip
  #   test "placeholder" do
  #   end
  # end

  # describe "communities.collections" do

  #   test "works for anyone for a public community" do
  #     [alice, bob, eve, _mallory] = users = some_fake_users!(4)
  #     lucy = fake_user!(%{is_instance_admin: true})
  #     comm = fake_community!(alice)
  #     colls = order_follower_count(some_fake_collections!(6, users, [comm])) # 24
  #     total = Enum.count(colls)
  #     q = community_query(fields: [collections: page_fields(collection_fields())])
  #     vars = %{"communityId" => comm.id}
  #     conns = [user_conn(alice), user_conn(bob), user_conn(lucy), user_conn(eve), json_conn()]
  #     for conn <- conns do
  #       comm2 = assert_community(comm, grumble_post_key(q, conn, "community", vars))
  #       assert %{"collections" => colls2, "collectionCount" => count} = comm2
  #       assert count == total
  #       edges = assert_page(colls2, 10, total, nil, true, &(&1["id"])) # should be false
  #       piz(colls, edges.edges, &assert_collection/2)
  #     end
  #   end

  # end

  # describe "communities.followers" do

  #   test "works for anyone for a public community" do
  #     [alice, bob] = some_fake_users!(2)
  #     lucy = fake_user!(%{is_instance_admin: true})
  #     comm = fake_community!(alice)
  #     some_randomer_follows!(23, comm)
  #     q = community_query(fields: [:follower_count, followers: page_fields(follow_fields())])
  #     vars = %{"communityId" => comm.id}
  #     conns = [user_conn(alice), user_conn(bob), user_conn(lucy), json_conn()]
  #     for conn <- conns do
  #       comm2 = assert_community(comm, grumble_post_key(q, conn, "community", vars))
  #       assert %{"followers" => follows, "followerCount" => count} = comm2
  #       assert count == 24
  #       edges = assert_page(follows, 10, 24, nil, true, &(&1["id"])) # should be false
  #       for edge <- edges.edges, do: assert_follow(edge)
  #     end
  #   end

  # end

  # describe "communities.likers" do

  #   test "works for anyone for a public community" do
  #     [alice, bob] = some_fake_users!(2)
  #     lucy = fake_user!(%{is_instance_admin: true})
  #     comm = fake_community!(alice)
  #     some_randomer_likes!(23, comm)
  #     q = community_query(fields: [:liker_count, likers: page_fields(like_fields())])
  #     vars = %{"communityId" => comm.id}
  #     conns = [user_conn(alice), user_conn(bob), user_conn(lucy), json_conn()]
  #     for conn <- conns do
  #       comm2 = grumble_post_key(q, conn, "community", vars)
  #       comm2 = assert_community(comm, comm2)
  #       assert %{"likers" => likes, "likerCount" => count} = comm2
  #       assert count == 23
  #       edges = assert_page(likes, 10, 23, nil, true, &(&1["id"])) # should be false
  #       for edge <- edges.edges, do: assert_like(edge)
  #     end
  #   end

  # end

  # describe "communities.flags" do

  #   test "empty for a guest or non-flagging user" do
  #     [alice, bob, eve] = some_fake_users!(3)
  #     lucy = fake_user!(%{is_instance_admin: true})
  #     comm = fake_community!(alice)
  #     flag!(bob, comm)
  #     flag!(lucy, comm)
  #     q = community_query(fields: [flags: page_fields(flag_fields())])
  #     vars = %{"communityId" => comm.id}
  #     conns = [user_conn(eve), json_conn()]
  #     for conn <- conns do
  #       comm2 = assert_community(comm, grumble_post_key(q, conn, "community", vars))
  #       assert %{"flags" => flags} = comm2
  #       assert_page(flags, 0, 0, false, false, &(&1["id"])) # should be false
  #     end
  #   end

  #   # TODO: alice should also see all
  #   test "not empty for a flagging user, community owner, community owner or admin" do
  #     [alice, bob] = some_fake_users!(2)
  #     lucy = fake_user!(%{is_instance_admin: true})
  #     comm = fake_community!(alice)
  #     flag!(bob, comm)
  #     some_randomer_flags!(23, comm)
  #     q = community_query(fields: [flags: page_fields(flag_fields())])
  #     vars = %{"communityId" => comm.id}

  #     comm2 = assert_community(grumble_post_key(q, user_conn(bob), "community", vars))
  #     assert %{"flags" => flags} = comm2
  #     edges = assert_page(flags, 1, 1, nil, false, &(&1["id"])) # should be false
  #     for edge <- edges.edges, do: assert_flag(edge)

  #     for conn <- [user_conn(lucy)] do
  #       comm2 = assert_community(grumble_post_key(q, conn, "community", vars))
  #       assert %{"flags" => flags} = comm2
  #       edges = assert_page(flags, 10, 24, nil, true, &(&1["id"])) # should be false
  #       for edge <- edges.edges, do: assert_flag(edge)
  #     end
  #   end

  # end

  # # TODO: the last comment view is clearly broken *sigh*

  # describe "communities.threads" do

  #   test "works for anyone when there are no threads" do
  #     [alice, bob] = some_fake_users!(2)
  #     lucy = fake_admin!()
  #     comm = fake_community!(alice)
  #     q = community_query(fields: [threads_subquery(fields: [comments_subquery()])])
  #     vars = %{"communityId" => comm.id}
  #     for conn <- [json_conn(), user_conn(bob), user_conn(alice), user_conn(lucy)] do
  #       comm2 = assert_community(comm, grumble_post_key(q, conn, "community", vars))
  #       assert %{"threads" => threads} = comm2
  #       assert_page(threads, 0, 0, false, false, &(&1.id))
  #     end
  #   end

  #   test "works for anyone when there are threads" do
  #     alice = fake_user!()
  #     lucy = fake_admin!()
  #     comm = fake_community!(alice)
  #     randomers = some_fake_users!(5)
  #     many_randomers = repeat_for_count(randomers, 25)
  #     threads_and_initials = flat_pam_some(randomers, 5, fn user -> # 25
  #       thread = fake_thread!(user, comm)
  #       comment = fake_comment!(user, thread)
  #       {thread, comment}
  #     end)
  #     threads_and_replies =
  #       zip(many_randomers, threads_and_initials, fn user, {thread, initial} ->
  #         reply = fake_reply!(user, thread, initial)
  #         {thread, reply}
  #       end)
  #     # final_replies =
  #     _ = zip(many_randomers, threads_and_replies, fn user, {thread, comment} ->
  #         fake_reply!(user, thread, comment)
  #       end)
  #     {_threads, initials} = unpiz(threads_and_initials)
  #     # replies = Enum.map(threads_and_replies, &elem(&1, 1))
  #     # comments = final_replies ++ replies ++ initials
  #     q = community_query(fields: [threads_subquery(fields: [comments_subquery(args: [limit: 1])])])
  #     vars = %{"communityId" => comm.id}
  #     for conn <- [json_conn(), user_conn(alice), user_conn(lucy)] do
  #       comm2 = assert_community(comm, grumble_post_key(q, conn, "community", vars))
  #       assert %{"threads" => threads} = comm2
  #       threads = assert_page(threads, 10, 25, nil, true, &(&1["id"])) # should be false
  #       # initials2 = Enum.flat_map(threads.edges, fn thread ->
  #       #   assert_page(thread["comments"], 1, 3, false, true, &(&1["id"])).edges
  #       # end)
  #       # assert Enum.count(initials2) == 10
  #       # each(Enum.reverse(initials), initials2, &assert_comment/2)
  #     end
  #   end

  # end

  # describe "communities.outbox" do

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

  # describe "communities.inbox" do
  #   @tag :skip
  #   test "placeholder" do
  #   end
  # end
end
