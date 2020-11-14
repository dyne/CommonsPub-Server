# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.Test.GraphQLAssertions do
  alias CommonsPub.Web.Test.ConnHelpers
  alias CommonsPub.Activities.Activity
  alias CommonsPub.Collections.Collection
  alias CommonsPub.Communities.Community
  # alias CommonsPub.Blocks.Block
  alias CommonsPub.Features.Feature
  alias CommonsPub.Flags.Flag
  alias CommonsPub.Follows.Follow
  alias CommonsPub.Likes.Like
  alias CommonsPub.Resources.Resource
  alias CommonsPub.Threads.{Comment, Thread}
  alias CommonsPub.Users.User

  alias Ecto.ULID
  import ExUnit.Assertions
  import Zest

  def assert_binary(val), do: assert(is_binary(val)) && val

  def assert_boolean(val), do: assert(is_boolean(val)) && val

  def assert_int(val), do: assert(is_integer(val)) && val

  def assert_non_neg(val), do: assert_int(val) && assert(val >= 0) && val

  def assert_pos(val), do: assert_int(val) && assert(val > 0) && val

  def assert_float(val), do: assert(is_float(val)) && val

  def assert_email(val), do: assert_binary(val)

  def assert_url(url) do
    uri = URI.parse(url)
    assert uri.scheme
    assert uri.host
    url
  end

  def assert_username(val), do: assert_binary(val)
  def assert_display_username(val), do: assert_binary(val)

  def assert_cursor(x) when is_binary(x) or is_integer(x), do: x

  def assert_cursors(x) when is_list(x), do: Enum.all?(x, &assert_cursor/1) && x

  def assert_ulid(ulid) do
    assert is_binary(ulid)
    assert {:ok, val} = Ecto.ULID.cast(ulid)
    val
  end

  def assert_uuid(uuid) do
    assert is_binary(uuid)
    assert {:ok, val} = Ecto.UUID.cast(uuid)
    val
  end

  def assert_datetime(%DateTime{} = time), do: time

  def assert_datetime(time) do
    assert is_binary(time)
    assert {:ok, val, 0} = DateTime.from_iso8601(time)
    val
  end

  def assert_datetime(%DateTime{} = dt, %DateTime{} = du) do
    assert :eq == DateTime.compare(dt, du)
    du
  end

  def assert_datetime(%DateTime{} = dt, other) when is_binary(other) do
    dt = String.replace(DateTime.to_iso8601(dt), "T", " ")
    assert dt == other
    dt
  end

  def assert_created_at(%{id: id}, %{created_at: created}) do
    scope assert: :created_at do
      assert {:ok, ts} = ULID.timestamp(id)
      assert_datetime(ts, created)
    end
  end

  def assert_updated_at(%{updated_at: left}, %{updated_at: right}) do
    scope assert: :created_at do
      assert_datetime(left, right)
    end
  end

  def assert_list() do
    fn l -> assert(is_list(l)) && l end
  end

  def assert_list(of) when is_function(of, 1) do
    fn l -> assert(is_list(l)) && Enum.map(l, of) end
  end

  def assert_list(of, size) when is_function(of, 1) and is_integer(size) and size >= 0 do
    fn l -> assert(is_list(l)) && assert(Enum.count(l) == size) && Enum.map(l, of) end
  end

  def assert_optional(map_fn) do
    fn o -> if is_nil(o), do: nil, else: map_fn.(o) end
  end

  def assert_eq(val1) do
    fn val2 -> assert(val1 == val2) && val2 end
  end

  def assert_field(object, key, test) when is_map(object) and is_function(test, 1) do
    scope assert_field: key do
      assert %{^key => value} = object
      Map.put(object, key, test.(value))
    end
  end

  def assert_optional_field(object, key, test) when is_map(object) and is_function(test, 1) do
    scope assert_field: key do
      case object do
        %{^key => value} -> Map.put(object, key, test.(value))
        _ -> object
      end
    end
  end

  def assert_object(struct = %{__struct__: _}, name, required, optional \\ []) do
    assert_object(Map.from_struct(struct), name, required, optional)
  end

  def assert_object(%{} = object, name, required, optional)
      when is_atom(name) and is_list(required) and is_list(optional) do
    object = ConnHelpers.uncamel_map(object)

    scope [{name, object}] do
      object =
        Enum.reduce(required, object, fn {key, test}, acc ->
          assert_field(acc, key, test)
        end)

      Enum.reduce(optional, object, fn {key, test}, acc ->
        assert_optional_field(acc, key, test)
      end)
    end
  end

  def assert_maps_eq(left, right, name) do
    assert_maps_eq(left, right, name, Map.keys(left), [])
  end

  def assert_maps_eq(left, right, name, required) do
    assert_maps_eq(left, right, name, required, [])
  end

  def assert_maps_eq(%{} = left, %{} = right, name, required, optional)
      when is_list(required) and is_list(optional) do
    scope [{name, {left, right}}] do
      each(required, fn key ->
        assert %{^key => left_val} = left
        assert %{^key => right_val} = right
        assert left_val == right_val
      end)

      each(optional, fn key ->
        case left do
          %{^key => left_val} ->
            assert %{^key => right_val} = right
            assert left_val == right_val

          _ ->
            nil
        end
      end)

      right
    end
  end

  def assert_location(loc) do
    assert_object(loc, :assert_location,
      column: &assert_non_neg/1,
      line: &assert_pos/1
    )
  end

  def assert_not_logged_in(errs, path) do
    assert [err] = errs

    assert_object(err, :assert_not_logged_in,
      code: assert_eq("needs_login"),
      message: assert_eq("You need to log in first."),
      path: assert_eq(path),
      locations: assert_list(&assert_location/1, 1)
    )
  end

  def assert_not_permitted(errs, path, verb \\ "do") do
    assert [err] = errs

    assert_object(err, :assert_not_permitted,
      code: assert_eq("unauthorized"),
      message: assert_eq("You do not have permission to #{verb} this."),
      path: assert_eq(path),
      locations: assert_list(&assert_location/1, 1)
    )
  end

  def assert_not_found(errs, path) do
    assert [err] = errs

    assert_object(err, :assert_not_found,
      code: assert_eq("not_found"),
      message: assert_eq("Not found"),
      path: assert_eq(path),
      locations: assert_list(&assert_location/1, 1)
    )
  end

  def assert_invalid_credential(errs, path) do
    assert [err] = errs

    assert_object(err, :assert_invalid_credential,
      code: assert_eq("invalid_credential"),
      message: assert_eq("We couldn't find an account with these details"),
      path: assert_eq(path),
      locations: assert_list(&assert_location/1, 1)
    )
  end

  def assert_page_info(page_info) do
    assert_object(page_info, :assert_page_info,
      start_cursor: assert_optional(&assert_cursors/1),
      end_cursor: assert_optional(&assert_cursors/1),
      has_previous_page: assert_optional(&assert_boolean/1),
      has_next_page: assert_optional(&assert_boolean/1)
    )
  end

  def assert_page() do
    fn page ->
      page =
        assert_object(page, :assert_page,
          edges: assert_list(),
          total_count: &assert_non_neg/1,
          page_info: &assert_page_info/1
        )

      if page.edges == [] do
        assert is_nil(page.page_info.start_cursor)
        assert is_nil(page.page_info.end_cursor)
      end

      page
    end
  end

  def assert_page(of) when is_function(of, 1) do
    fn page ->
      page =
        assert_object(page, :assert_page,
          edges: assert_list(of),
          total_count: &assert_non_neg/1,
          page_info: &assert_page_info/1
        )

      if page.edges == [] do
        assert is_nil(page.page_info.start_cursor)
        assert is_nil(page.page_info.end_cursor)
      end

      page
    end
  end

  # def assert_pages_eq(page, page2) do
  #   assert page.edges
  #   assert page.page_info.has_previous_page == prev?
  #   assert page.page_info.has_next_page == next?
  #   page
  # end

  def assert_page(page, returned_count, total_count, prev?, next?, cursor_fn) do
    page =
      assert_object(page, :assert_page,
        edges: assert_list(& &1, returned_count),
        total_count: assert_eq(total_count),
        page_info: &assert_page_info/1
      )

    if page.edges == [] do
      assert is_nil(page.page_info.start_cursor)
      assert is_nil(page.page_info.end_cursor)
    else
      assert page.page_info.start_cursor == cursor_fn.(List.first(page.edges))
      assert page.page_info.end_cursor == cursor_fn.(List.last(page.edges))
    end

    assert page.page_info.has_previous_page == prev?
    assert page.page_info.has_next_page == next?
    page
  end

  def assert_language(lang) do
    assert_object(lang, :assert_language, [])
    # id: &assert_binary/1,
    # iso_code2: &assert_binary/1,
    # iso_code3: &assert_binary/1,
    # english_name: &assert_binary/1,
    # local_name: &assert_binary/1
    # created_at: &assert_datetime/1,
    # updated_at: &assert_datetime/1
  end

  def assert_country(country), do: assert_language(country)

  def assert_auth_payload(ap) do
    assert_object(ap, :assert_auth_payload,
      token: &assert_uuid/1,
      me: &assert_me/1,
      typename: assert_eq("AuthPayload")
    )
  end

  def assert_me(me) do
    assert_object(me, :assert_me,
      email: &assert_email/1,
      wants_email_digest: &assert_boolean/1,
      wants_notifications: &assert_boolean/1,
      is_confirmed: &assert_boolean/1,
      is_instance_admin: &assert_boolean/1,
      user: &assert_user/1,
      typename: assert_eq("Me")
    )
  end

  def assert_me(user, %{} = me) do
    assert_mes_eq(user, assert_me(me))
  end

  def assert_mes_eq(%User{} = user, %{} = me) do
    assert_maps_eq(user.local_user, me, :assert_me, [
      :email,
      :wants_email_digest,
      :wants_notifications
    ])

    assert_user(user, me.user)
    me
  end

  def assert_me_created(%{} = user, %{} = me) do
    user = assert_user_created(user)
    me = assert_me(me)

    assert_maps_eq(user, me, :assert_me_created, [
      :email,
      :wants_email_digest,
      :wants_notifications
    ])

    %{me | user: assert_user_created(user, me.user)}
  end

  def assert_me_updated(%{} = user, %{} = me) do
    user = assert_user_updated(user)
    me = assert_me(me)
    assert_maps_eq(user, me, :assert_me_updated, [], [:wants_email_digest, :wants_notifications])
    %{me | user: assert_user_updated(user, me.user)}
  end

  def assert_user(user) do
    assert_object(
      user,
      :assert_user,
      [
        id: &assert_ulid/1,
        canonical_url: assert_optional(&assert_url/1),
        preferred_username: &assert_username/1,
        display_username: &assert_display_username/1,
        name: &assert_binary/1,
        summary: &assert_binary/1,
        location: &assert_binary/1,
        website: &assert_url/1,
        is_local: &assert_boolean/1,
        is_disabled: &assert_boolean/1,
        is_public: &assert_boolean/1,
        created_at: &assert_datetime/1,
        updated_at: &assert_datetime/1,
        typename: assert_eq("User")
      ],
      follow_count: &assert_non_neg/1,
      follower_count: &assert_non_neg/1,
      like_count: &assert_non_neg/1,
      liker_count: &assert_non_neg/1,
      follows: assert_page(&assert_follow/1),
      followers: assert_page(&assert_follow/1),
      collection_follows: assert_page(&assert_follow/1),
      community_follows: assert_page(&assert_follow/1),
      user_follows: assert_page(&assert_follow/1),
      likes: assert_page(&assert_like/1),
      likers: assert_page(&assert_like/1),
      my_like: assert_optional(&assert_like/1),
      my_follow: assert_optional(&assert_follow/1),
      my_flag: assert_optional(&assert_flag/1)
    )
  end

  def assert_user(%User{} = user, %{id: _} = user2) do
    assert_users_eq(user, user2)
  end

  def assert_user(%User{} = user, %{} = user2) do
    assert_users_eq(user, assert_user(user2))
  end

  def assert_users_eq(%User{} = user, %{} = user2) do
    assert_maps_eq(user.character, user2, :assert_user, [:canonical_url, :preferred_username])
    assert_maps_eq(user, user2, :assert_user, [:id, :name, :summary, :location, :website])
    assert_created_at(user, user2)
    assert_updated_at(user, user2)
    assert user2.is_public == true
    assert user2.is_disabled == false
    assert user2.is_local == true
    user2
  end

  def assert_user_created(%{} = user) do
    assert_object(user, :assert_user_created, [preferred_username: &assert_username/1],
      name: &assert_binary/1,
      summary: &assert_binary/1,
      location: &assert_binary/1,
      website: &assert_url/1
    )
  end

  def assert_user_created(%{} = user, %{} = user2) do
    user = assert_user_created(user)
    user2 = assert_user(user2)
    assert_maps_eq(user, user2, [:preferred_username], [:name, :summary, :location, :website])
    user2
  end

  def assert_user_updated(%{} = user) do
    assert_object(user, :assert_user_updated, [],
      wants_email_digest: &assert_boolean/1,
      wants_notifications: &assert_boolean/1,
      name: &assert_binary/1,
      summary: &assert_binary/1,
      location: &assert_binary/1,
      website: &assert_url/1
    )
  end

  def assert_user_updated(%{} = user, %{} = user2) do
    user = assert_user_updated(user)
    user2 = assert_user(user2)
    assert_maps_eq(user, user2, [], [:name, :summary, :location, :website])
    user2
  end

  def assert_community(comm) do
    assert_object(
      comm,
      :assert_community,
      [
        id: &assert_ulid/1,
        canonical_url: assert_optional(&assert_url/1),
        preferred_username: &assert_username/1,
        display_username: &assert_display_username/1,
        name: &assert_binary/1,
        summary: &assert_binary/1,
        is_local: &assert_boolean/1,
        is_disabled: &assert_boolean/1,
        is_public: &assert_boolean/1,
        created_at: &assert_datetime/1,
        updated_at: &assert_datetime/1,
        typename: assert_eq("Community")
      ],
      collection_count: &assert_non_neg/1,
      collections: assert_page(&assert_collection/1),
      followers: assert_page(&assert_follow/1),
      likers: assert_page(&assert_like/1),
      liker_count: &assert_non_neg/1,
      my_like: assert_optional(&assert_like/1),
      my_follow: assert_optional(&assert_follow/1),
      my_flag: assert_optional(&assert_flag/1),
      flags: assert_page(&assert_flag/1)
    )
  end

  def assert_community(%Community{} = comm, %{} = comm2) do
    assert_communities_eq(comm, assert_community(comm2))
  end

  def assert_communities_eq(%Community{} = comm, %{} = comm2) do
    assert_maps_eq(comm.character, comm2, :assert_community, [:canonical_url, :preferred_username])

    assert_maps_eq(comm, comm2, :assert_community, [:id, :name, :summary])
    assert comm2.is_public == not is_nil(comm.published_at)
    assert comm2.is_disabled == not is_nil(comm.disabled_at)
    assert comm2.is_local == is_nil(comm.character.peer_id)
    comm2
  end

  def assert_community_created(%{} = comm) do
    assert_object(comm, :assert_community_created, [preferred_username: &assert_username/1],
      name: &assert_binary/1,
      summary: &assert_binary/1
    )
  end

  def assert_community_created(%{} = comm, %{} = comm2) do
    comm = assert_community_created(comm)
    comm2 = assert_community(comm2)
    assert_maps_eq(comm, comm2, [:preferred_username], [:name, :summary])
    comm2
  end

  def assert_community_updated(%{} = comm) do
    assert_object(comm, :assert_community_updated, [],
      name: &assert_binary/1,
      summary: &assert_binary/1
    )
  end

  def assert_community_updated(%{} = comm, %{} = comm2) do
    comm = assert_community_updated(comm)
    comm2 = assert_community(comm2)
    assert_maps_eq(comm, comm2, [:name, :summary])
    comm2
  end

  def assert_collection(coll) do
    assert_object(
      coll,
      :assert_collection,
      [
        id: &assert_ulid/1,
        canonical_url: assert_optional(&assert_url/1),
        preferred_username: &assert_username/1,
        display_username: &assert_display_username/1,
        name: &assert_binary/1,
        summary: &assert_binary/1,
        is_local: &assert_boolean/1,
        is_disabled: &assert_boolean/1,
        is_public: &assert_boolean/1,
        created_at: &assert_datetime/1,
        updated_at: &assert_datetime/1,
        typename: assert_eq("Collection")
      ],
      community: &assert_community/1,
      my_like: assert_optional(&assert_like/1),
      my_follow: assert_optional(&assert_follow/1),
      my_flag: assert_optional(&assert_flag/1),
      flags: assert_page(&assert_flag/1),
      # follower_count: &assert_non_neg/1,
      followers: assert_page(&assert_follow/1),
      liker_count: &assert_non_neg/1,
      likers: assert_page(&assert_like/1),
      resource_count: &assert_non_neg/1,
      resources: assert_page(&assert_resource/1)
    )
  end

  def assert_collection(%Collection{} = coll, %{id: _} = coll2) do
    assert_collections_eq(coll, coll2)
  end

  def assert_collection(%Collection{} = coll, %{} = coll2) do
    assert_collections_eq(coll, assert_collection(coll2))
  end

  def assert_collections_eq(%Collection{} = coll, %{} = coll2) do
    assert_maps_eq(coll.character, coll2, :assert_collection, [
      :canonical_url,
      :preferred_username
    ])

    assert_maps_eq(coll, coll2, :assert_collection, [:id, :name, :summary])
    # follower_count
    [:liker_count, :resource_count]
    coll2
  end

  def assert_collection_created(%{} = coll) do
    assert_object(coll, :assert_collection_created, [preferred_username: &assert_username/1],
      name: &assert_binary/1,
      summary: &assert_binary/1
    )
  end

  def assert_collection_created(%{} = coll, %{} = coll2) do
    coll = assert_collection_created(coll)
    coll2 = assert_collection(coll2)
    assert_maps_eq(coll, coll2, [:preferred_username], [:name, :summary])
    coll2
  end

  def assert_collection_updated(%{} = coll) do
    assert_object(coll, :assert_collection_updated, [],
      name: &assert_binary/1,
      summary: &assert_binary/1
    )
  end

  def assert_collection_updated(%{} = coll, %{} = coll2) do
    coll = assert_collection_updated(coll)
    coll2 = assert_collection(coll2)
    assert_maps_eq(coll, coll2, [:name, :summary])
    coll2
  end

  def assert_resource(resource) do
    assert_object(resource, :assert_resource,
      id: &assert_ulid/1,
      canonical_url: assert_optional(&assert_url/1),
      name: &assert_binary/1,
      summary: &assert_binary/1,
      license: &assert_binary/1,
      is_local: &assert_boolean/1,
      is_disabled: &assert_boolean/1,
      is_public: &assert_boolean/1,
      created_at: &assert_datetime/1,
      updated_at: &assert_datetime/1,
      typename: assert_eq("Resource")
    )
  end

  def assert_resource(%Resource{} = res, %{id: _} = res2) do
    assert_resources_eq(res, res2)
  end

  def assert_resource(%Resource{} = res, %{} = res2) do
    assert_resources_eq(res, assert_resource(res2))
  end

  def assert_resources_eq(%Resource{} = res, %{} = res2) do
    assert_maps_eq(
      res,
      res2,
      :assert_resource,
      [:id, :canonical_url, :name, :summary, :license],
      [:follower_count, :liker_count, :resource_count]
    )

    assert not is_nil(res.published_at) == res2.is_public
    assert not is_nil(res.disabled_at) == res2.is_disabled
    assert_created_at(res, res2)
    res2
  end

  def assert_resource_input(%{} = res, %{} = res2) do
    res2 = assert_resource(res2)
    assert_maps_eq(res, res2, [:name, :summary, :license])
    res2
  end

  def assert_copied_resource(%Resource{} = res, %{} = res2) do
    assert_resource_input(res, res2)
  end

  def assert_thread(thread) do
    assert_object(
      thread,
      :assert_thread,
      [
        id: &assert_ulid/1,
        canonical_url: assert_optional(&assert_url/1),
        name: &assert_binary/1,
        summary: &assert_binary/1,
        license: &assert_binary/1,
        is_local: &assert_boolean/1,
        is_hidden: &assert_boolean/1,
        is_public: &assert_boolean/1,
        created_at: &assert_datetime/1,
        updated_at: &assert_datetime/1,
        typename: assert_eq("Thread")
      ],
      follower_count: &assert_non_neg/1
    )
  end

  def assert_thread(%Thread{} = thread, %{id: _} = thread2) do
    assert_threads_eq(thread, thread2)
  end

  def assert_thread(%Thread{} = thread, %{} = thread2) do
    assert_threads_eq(thread, assert_thread(thread2))
  end

  def assert_threads_eq(%Thread{} = thread, %{} = thread2) do
    assert_maps_eq(thread, thread2, :assert_thread, [:id, :canonical_url, :is_local], [
      :follower_count
    ])

    assert not is_nil(thread.published_at) == thread2.is_public
    assert not is_nil(thread.hidden_at) == thread2.is_hidden
    assert_created_at(thread, thread2)
    thread2
  end

  def assert_comment(comment) do
    assert_object(
      comment,
      :assert_comment,
      [
        id: &assert_ulid/1,
        canonical_url: assert_optional(&assert_url/1),
        content: &assert_binary/1,
        is_local: &assert_boolean/1,
        is_hidden: &assert_boolean/1,
        is_public: &assert_boolean/1,
        created_at: &assert_datetime/1,
        updated_at: &assert_datetime/1,
        typename: assert_eq("Comment")
      ],
      liker_count: &assert_non_neg/1
    )
  end

  def assert_comment(%Comment{} = comment, %{id: _} = comment2) do
    assert_comments_eq(comment, comment2)
  end

  def assert_comment(%Comment{} = comment, %{} = comment2) do
    assert_comments_eq(comment, assert_comment(comment2))
  end

  def assert_comments_eq(%Comment{} = comment, %{} = comment2) do
    assert_maps_eq(
      comment,
      comment2,
      :assert_comment,
      [:id, :canonical_url, :content, :is_local],
      [:liker_count]
    )

    assert not is_nil(comment.published_at) == comment2.is_public
    assert not is_nil(comment.hidden_at) == comment2.is_hidden
    assert_created_at(comment, comment2)
    comment2
  end

  def assert_feature(feature) do
    assert_object(feature, :assert_feature,
      id: &assert_ulid/1,
      canonical_url: assert_optional(&assert_url/1),
      is_local: &assert_boolean/1,
      created_at: &assert_datetime/1,
      typename: assert_eq("Feature")
    )
  end

  def assert_feature(%Feature{} = feature, %{} = feature2) do
    assert_features_eq(feature, assert_feature(feature2))
  end

  def assert_feature(%Feature{} = feature, %{id: _} = feature2) do
    assert_features_eq(feature, feature2)
  end

  def assert_features_eq(%Feature{} = feature, %{} = feature2) do
    assert_maps_eq(feature, feature2, :assert_feature, [:id, :canonical_url, :is_local])
    assert_created_at(feature, feature2)
    feature2
  end

  def assert_flag(flag) do
    assert_object(flag, :assert_flag,
      id: &assert_ulid/1,
      canonical_url: assert_optional(&assert_url/1),
      message: &assert_binary/1,
      is_local: &assert_boolean/1,
      created_at: &assert_datetime/1,
      updated_at: &assert_datetime/1,
      typename: assert_eq("Flag")
    )
  end

  def assert_flag(%Flag{} = flag, %{id: _} = flag2) do
    assert_flags_eq(flag, flag2)
  end

  def assert_flag(%Flag{} = flag, %{} = flag2) do
    assert_flags_eq(flag, assert_flag(flag2))
  end

  def assert_flags_eq(%Flag{} = flag, %{} = flag2) do
    assert_maps_eq(flag, flag2, :assert_flag, [:id, :canonical_url, :message, :is_local])
    assert_created_at(flag, flag2)
    flag2
  end

  def assert_follow(follow) do
    assert_object(
      follow,
      :assert_follow,
      [
        id: &assert_ulid/1,
        canonical_url: assert_optional(&assert_url/1),
        is_local: &assert_boolean/1,
        is_public: &assert_boolean/1,
        created_at: &assert_datetime/1,
        updated_at: &assert_datetime/1,
        typename: assert_eq("Follow")
      ],
      context: &assert_follow_context/1
    )
  end

  def assert_follow(%Follow{} = follow, %{id: _} = follow2) do
    assert_follows_eq(follow, follow2)
  end

  def assert_follow(%Follow{} = follow, %{} = follow2) do
    assert_follows_eq(follow, assert_follow(follow2))
  end

  def assert_follows_eq(%Follow{} = follow, %{} = follow2) do
    assert_maps_eq(follow, follow2, :assert_follow, [:id, :canonical_url, :is_local])
    assert_created_at(follow, follow2)
    assert not is_nil(follow.published_at) == follow2.is_public
    follow2
  end

  def assert_like(like) do
    assert_object(like, :assert_like,
      id: &assert_ulid/1,
      canonical_url: assert_optional(&assert_url/1),
      is_local: &assert_boolean/1,
      is_public: &assert_boolean/1,
      created_at: &assert_datetime/1,
      updated_at: &assert_datetime/1,
      typename: assert_eq("Like")
    )
  end

  def assert_like(%Like{} = like, %{id: _} = like2) do
    assert_likes_eq(like, like2)
  end

  def assert_like(%Like{} = like, %{} = like2) do
    assert_likes_eq(like, assert_like(like2))
  end

  def assert_likes_eq(%Like{} = like, %{} = like2) do
    assert_maps_eq(like, like2, :assert_like, [:id, :canonical_url, :is_local])
    assert_created_at(like, like2)
    assert not is_nil(like.published_at) == like2.is_public
    like2
  end

  def assert_activity(activity) do
    assert_object(activity, :assert_activity,
      id: &assert_ulid/1,
      canonical_url: assert_optional(&assert_url/1),
      verb: &assert_binary/1,
      is_local: &assert_boolean/1,
      is_public: &assert_boolean/1,
      created_at: &assert_datetime/1,
      typename: assert_eq("Activity")
    )
  end

  def assert_activity(%Activity{} = activity, %{id: _} = activity2) do
    assert_activities_eq(activity, activity2)
  end

  def assert_activity(%Activity{} = activity, %{} = activity2) do
    assert_activities_eq(activity, assert_activity(activity2))
  end

  def assert_activities_eq(%Activity{} = activity, %{} = activity2) do
    assert_maps_eq(activity, activity2, :assert_activity, [:id, :canonical_url, :verb, :is_local])
    assert not is_nil(activity.published_at) == activity2.is_public
    assert_created_at(activity, activity2)
    activity2
  end

  def typeof(%{typename: typename}), do: typename
  def typeof(%{"__typename" => typename}), do: typename

  def assert_flag_context(thing), do: assert_flag_context(thing, typeof(thing))

  def assert_flag_context(thing, type) do
    case type do
      "Collection" -> assert_collection(thing)
      "Comment" -> assert_comment(thing)
      "Community" -> assert_community(thing)
      "Resource" -> assert_resource(thing)
      "User" -> assert_user(thing)
    end
  end

  def assert_like_context(thing), do: assert_like_context(thing, typeof(thing))

  def assert_like_context(thing, type) do
    case type do
      "Collection" -> assert_collection(thing)
      "Comment" -> assert_comment(thing)
      "Resource" -> assert_resource(thing)
      "User" -> assert_user(thing)
    end
  end

  def assert_follow_context(thing), do: assert_follow_context(thing, typeof(thing))

  def assert_follow_context(thing, type) do
    case type do
      "Collection" -> assert_collection(thing)
      "Community" -> assert_community(thing)
      "Thread" -> assert_thread(thing)
      "User" -> assert_user(thing)
    end
  end

  def assert_tagging_context(thing), do: assert_tagging_context(thing, typeof(thing))

  def assert_tagging_context(thing, type) do
    case type do
      "Collection" -> assert_collection(thing)
      "Comment" -> assert_comment(thing)
      "Community" -> assert_community(thing)
      "Resource" -> assert_resource(thing)
      "Thread" -> assert_thread(thing)
      "User" -> assert_user(thing)
    end
  end

  def assert_activity_context(thing), do: assert_activity_context(thing, typeof(thing))

  def assert_activity_context(thing, type) do
    case type do
      "Collection" -> assert_collection(thing)
      "Comment" -> assert_comment(thing)
      "Community" -> assert_community(thing)
      "Resource" -> assert_resource(thing)
    end
  end

  def assert_thread_context(thing), do: assert_thread_context(thing, typeof(thing))

  def assert_thread_context(thing, type) do
    case type do
      "Collection" -> assert_collection(thing)
      "Community" -> assert_community(thing)
      "Flag" -> assert_flag(thing)
      "Resource" -> assert_resource(thing)
    end
  end

  # def assert_tag_category(cat) do
  #   assert %{"id: id, "canonicalUrl: url} = cat
  #   assert is_binary(id)
  #   assert is_binary(url) or is_nil(url)
  #   assert %{"id: id, "name: name} = cat
  #   assert is_binary(id)
  #   assert is_binary(name)
  #   assert %{"isLocal: local, "isPublic: public} = cat
  #   assert is_boolean(local)
  #   assert is_boolean(public)
  #   assert %{"createdAt: created} = cat
  #   assert is_binary(created)
  #   assert %{"__typename: "TagCategory"} = cat
  # end

  # def assert_tag(tag) do
  #   assert %{"id: id, "canonicalUrl: url} = tag
  #   assert is_binary(id)
  #   assert is_binary(url) or is_nil(url)
  #   assert %{"id: id, "name: name} = tag
  #   assert is_binary(id)
  #   assert is_binary(name)
  #   assert %{"isLocal: local, "isPublic: public} = tag
  #   assert is_boolean(local)
  #   assert is_boolean(public)
  #   assert %{"createdAt: created} = tag
  #   assert is_binary(created)
  #   assert %{"__typename: "Tag"} = tag
  # end

  # def assert_tagging(tag) do
  #   assert %{"id: id, "canonicalUrl: url} = tag
  #   assert is_binary(id)
  #   assert is_binary(url) or is_nil(url)
  #   assert %{"isLocal: local, "isPublic: public} = tag
  #   assert is_boolean(local)
  #   assert is_boolean(public)
  #   assert %{"createdAt: created} = tag
  #   assert is_binary(created)
  #   assert %{"__typename: "Tagging"} = tag
  # end

  # def assert_block(block) do
  # end

  # def assert_block_context(thing), do: assert_block_context(thing, typeof(thing))

  # def assert_block_context(thing, type) do
  # end
end
