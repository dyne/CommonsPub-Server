# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.Test.GraphQLFields do
  import Grumble

  def page_info_fields do
    ~w(start_cursor end_cursor has_previous_page has_next_page __typename)a
  end

  def page_fields(edge_fields) do
    page_info = Grumble.field(:page_info, fields: page_info_fields())
    edges = Grumble.field(:edges, fields: edge_fields)
    [:total_count, page_info, edges]
  end

  def user_fields(extra \\ []) do
    extra ++
      ~w(id canonical_url preferred_username display_username name summary
         location website follower_count liker_count is_local is_public
         is_disabled created_at updated_at __typename)a
  end

  def auth_payload_fields(extra \\ []) do
    [:__typename, :token, me: me_fields(extra)]
  end

  def me_fields(extra \\ []) do
    [user: user_fields(extra)] ++
      ~w(email wants_email_digest wants_notifications is_confirmed
         is_instance_admin __typename)a
  end

  def thread_fields(extra \\ []) do
    extra ++
      ~w(id canonical_url is_local is_public is_hidden created_at
        follower_count updated_at __typename)a
  end

  def comment_fields(extra \\ []) do
    extra ++
      ~w(id canonical_url content is_local
         is_public is_hidden created_at updated_at __typename)a
  end

  def community_fields(extra \\ []) do
    extra ++
      ~w(id canonical_url preferred_username display_username
        name summary is_local is_public is_disabled
        created_at updated_at __typename)a
  end

  def collection_fields(extra \\ []) do
    extra ++
      ~w(id canonical_url preferred_username display_username name summary
        resource_count is_local is_public is_disabled created_at
        updated_at __typename)a
  end

  def resource_fields(extra \\ []) do
    extra ++
      ~w(id canonical_url name summary license subject level language is_local
         is_public is_disabled created_at updated_at __typename)a
  end

  def feature_fields(extra \\ []) do
    extra ++ ~w(id canonical_url is_local created_at __typename)a
  end

  def flag_fields(extra \\ []) do
    extra ++
      ~w(id canonical_url message is_resolved is_local created_at updated_at __typename)a
  end

  def like_fields(extra \\ []) do
    extra ++ ~w(id canonical_url is_local is_public created_at updated_at __typename)a
  end

  def follow_fields(extra \\ []) do
    extra ++ ~w(id canonical_url is_local is_public created_at updated_at __typename)a
  end

  def followed_collection_fields(extra \\ []) do
    extra ++ [follow: follow_fields(), collection: collection_fields()]
  end

  def followed_community_fields(extra \\ []) do
    extra ++ [follow: follow_fields(), community: community_fields()]
  end

  def activity_fields(extra \\ []) do
    extra ++ ~w(is canonical_url verb is_local is_public created_at __typename)a
  end

  def invite_fields(extra \\ []) do
    [] ++ extra
  end

  # def tag_category_basics() do
  #   """
  #   id canonicalUrl name
  #   isLocal isPublic createdAt __typename
  #   """
  # end

  # def tag_basics() do
  #   """
  #   id canonicalUrl name
  #   isLocal isPublic createdAt __typename
  #   """
  # end

  # def tagging_basics() do
  #   """
  #   id canonicalUrl
  #   isLocal isPublic createdAt __typename
  #   """
  # end

  # def language_fields(extra \\ []) do
  #   """
  #   id isoCode2 isoCode3 englishName localName createdAt updatedAt __typename
  #   """
  # end

  # def country_basics() do
  #   """
  #   id isoCode2 isoCode3 englishName localName createdAt updatedAt __typename
  #   """
  # end

  def gen_query(param_name, field_fn, options) do
    params = Keyword.get(options, :params, [])
    name = Keyword.get(options, :name, "test")
    id_type = Keyword.get(options, :id_type, :string)

    query(
      name: name,
      params: params,
      param: param(param_name, type!(id_type)),
      field: field_fn.(options)
    )
  end

  def gen_query(field_fn, options) do
    params = Keyword.get(options, :params, [])
    name = Keyword.get(options, :name, "test")
    query(name: name, params: params, field: field_fn.(options))
  end

  def gen_subquery(arg_name, field_name, fields_fn, options) do
    args = Keyword.get(options, :args, [])
    fields = Keyword.get(options, :fields, [])

    field(field_name,
      args: args,
      arg: arg(arg_name, var(arg_name)),
      fields: fields_fn.(fields)
    )
  end

  def gen_subquery(field_name, fields_fn, options) do
    args = Keyword.get(options, :args, [])
    fields = Keyword.get(options, :fields, [])

    field(field_name,
      args: args,
      fields: fields_fn.(fields)
    )
  end

  def page_subquery(arg_name, field_name, fields_fn, options) do
    args = Keyword.get(options, :args, [])
    fields = Keyword.get(options, :fields, [])

    field(field_name,
      args: args,
      arg: arg(arg_name, var(arg_name)),
      fields: page_fields(fields_fn.(fields))
    )
  end

  def page_subquery(field_name, fields_fn, options) do
    args = Keyword.get(options, :args, [])
    fields = Keyword.get(options, :fields, [])

    field(field_name,
      args: args,
      fields: page_fields(fields_fn.(fields))
    )
  end

  def gen_mutation(params, field_fn, options) do
    params2 = Keyword.get(options, :params, [])
    name = Keyword.get(options, :name, "test")
    mutation(name: name, params: params, params: params2, field: field_fn.(options))
  end

  def gen_mutation(params, field_fn, field1_options, field2_options) do
    params2 = Keyword.get(field1_options, :params, [])
    name = Keyword.get(field1_options, :name, "test")
    mutation(name: name, params: params, params: params2, field: field_fn.(field1_options, field2_options))
  end

  def gen_submutation(args, field_name, field_fn, options) do
    args2 = Keyword.get(options, :args, [])
    fields = Keyword.get(options, :fields, [])
    field(field_name, args: args, args: args2, fields: field_fn.(fields))
  end

  def gen_submutation(args, field_name, field_fn, field1_options, field2_options) do
    args2 = Keyword.get(field1_options, :args, [])
    fields1 = Keyword.get(field1_options, :fields, [])
    fields2 = Keyword.get(field2_options, :fields, [])
    field(field_name, args: args, args: args2, fields: field_fn.(fields1, fields2))
  end

  ### collections

  def collection_spread(fields \\ []) do
    object_spread(:collection, fields: collection_fields(fields))
  end

  @spec collection_query(any) :: none
  def collection_query(options \\ []) do
    gen_query(:collection_id, &collection_subquery/1, options)
  end

  def collection_subquery(options \\ []) do
    gen_subquery(:collection_id, :collection, &collection_fields/1, options)
  end

  def collections_query(options \\ []) do
    params =
      [
        collections_after: list_type(:cursor),
        collections_before: list_type(:cursor),
        collections_limit: :int
      ] ++ Keyword.get(options, :params, [])

    gen_query(&collections_subquery/1, [{:params, params} | options])
  end

  def collections_subquery(options \\ []) do
    args = [
      after: var(:collections_after),
      before: var(:collections_before),
      limit: var(:collections_limit)
    ]

    page_subquery(
      :collections,
      &[:follower_count | collection_fields(&1)],
      [{:args, args} | options]
    )
  end

  def create_collection_mutation(options \\ []) do
    [
      collection: type!(:collection_input),
      context_id: type!(:string),
      icon: type(:upload_input)
    ]
    |> gen_mutation(&create_collection_submutation/1, options)
  end

  def create_collection_submutation(options \\ []) do
    [collection: var(:collection), context_id: var(:context_id), icon: var(:icon)]
    |> gen_submutation(:create_collection, &collection_fields/1, options)
  end

  def update_collection_mutation(options \\ []) do
    [collection: type!(:collection_update_input), collection_id: type!(:string)]
    |> gen_mutation(&update_collection_submutation/1, options)
  end

  def update_collection_submutation(options \\ []) do
    [collection: var(:collection), collection_id: var(:collection_id)]
    |> gen_submutation(:update_collection, &collection_fields/1, options)
  end

  ### communities

  def community_spread(fields \\ []) do
    object_spread(:community, fields: community_fields(fields))
  end

  def community_query(options \\ []) do
    gen_query(:community_id, &community_subquery/1, options)
  end

  def community_subquery(options \\ []) do
    gen_subquery(:community_id, :community, &community_fields/1, options)
  end

  def communities_query(options \\ []) do
    params = [
      communities_after: list_type(:cursor),
      communities_before: list_type(:cursor),
      communities_limit: :int
    ]

    gen_query(&communities_subquery/1, [{:params, params} | options])
  end

  def communities_subquery(options \\ []) do
    args = [
      after: var(:communities_after),
      before: var(:communities_before),
      limit: var(:communities_limit)
    ]

    page_subquery(
      :communities,
      &[:follower_count | community_fields(&1)],
      [{:args, args} | options]
    )
  end

  def create_community_mutation(options \\ []) do
    [community: type!(:community_input)]
    |> gen_mutation(&create_community_submutation/1, options)
  end

  def create_community_submutation(options \\ []) do
    [community: var(:community)]
    |> gen_submutation(:create_community, &community_fields/1, options)
  end

  def update_community_mutation(options \\ []) do
    [community: type!(:community_update_input), community_id: type!(:string)]
    |> gen_mutation(&update_community_submutation/1, options)
  end

  def update_community_submutation(options \\ []) do
    [community: var(:community), community_id: var(:community_id)]
    |> gen_submutation(:update_community, &community_fields/1, options)
  end

  ### flags

  def flag_query(options \\ []) do
    gen_query(:flag_id, &flag_subquery/1, options)
  end

  def flag_subquery(options \\ []) do
    gen_subquery(:flag_id, :flag, &flag_fields/1, options)
  end

  def flags_query(options \\ []) do
    gen_query(:flags, &flags_subquery/1, options)
  end

  def flags_subquery(options \\ []) do
    args = [
      after: var(:flags_after),
      before: var(:flags_before),
      limit: var(:flags_limit)
    ]

    page_subquery(:flags, &flag_fields/1, [{:args, args} | options])
  end

  def create_flag_mutation(options \\ []) do
    [flag: type!(:flag_input)]
    |> gen_mutation(&create_flag_submutation/1, options)
  end

  def create_flag_submutation(options \\ []) do
    [flag: var(:flag)]
    |> gen_submutation(:create_flag, &flag_fields/1, options)
  end

  def update_flag_mutation(options \\ []) do
    [flag: type!(:flag_input), flag_id: type!(:string)]
    |> gen_mutation(&create_flag_submutation/1, options)
  end

  def update_flag_submutation(options \\ []) do
    [flag: var(:flag_input), flag_id: var(:flag_id)]
    |> gen_submutation(:update_flag, &flag_fields/1, options)
  end

  ### features

  def feature_query(options \\ []) do
    gen_query(:feature_id, &feature_subquery/1, options)
  end

  def feature_subquery(options \\ []) do
    gen_subquery(:feature_id, :feature, &feature_fields/1, options)
  end

  def features_query(options \\ []) do
    gen_query(:features, &features_subquery/1, options)
  end

  def features_subquery(options \\ []) do
    args = [
      after: var(:features_after),
      before: var(:features_before),
      limit: var(:features_limit)
    ]

    page_subquery(:features, &feature_fields/1, [{:args, args} | options])
  end

  ### follows

  def follow_query(options \\ []) do
    gen_query(:follow_id, &follow_subquery/1, options)
  end

  def follow_subquery(options \\ []) do
    gen_subquery(:follow_id, :follow, &follow_fields/1, options)
  end

  def followers_subquery(options \\ []) do
    args = [
      after: var(:followers_after),
      before: var(:followers_before),
      limit: var(:followers_limit)
    ]

    page_subquery(:followers, &follow_fields/1, [{:args, args} | options])
  end

  def follows_subquery(options \\ []) do
    args = [
      after: var(:follows_after),
      before: var(:follows_before),
      limit: var(:follows_limit)
    ]

    page_subquery(:follows, &follow_fields/1, [{:args, args} | options])
  end

  def collection_follows_subquery(options \\ []) do
    args = [
      after: var(:collection_follows_after),
      before: var(:collection_follows_before),
      limit: var(:collection_follows_limit)
    ]

    page_subquery(:collection_follows, &follow_fields/1, [{:args, args} | options])
  end

  def community_follows_subquery(options \\ []) do
    args = [
      after: var(:community_follows_after),
      before: var(:community_follows_before),
      limit: var(:community_follows_limit)
    ]

    page_subquery(:community_follows, &follow_fields/1, [{:args, args} | options])
  end

  def user_follows_subquery(options \\ []) do
    args = [
      after: var(:user_follows_after),
      before: var(:user_follows_before),
      limit: var(:user_follows_limit)
    ]

    page_subquery(:user_follows, &follow_fields/1, [{:args, args} | options])
  end

  def create_follow_mutation(options \\ []) do
    [context_id: type!(:string)]
    |> gen_mutation(&create_follow_submutation/1, options)
  end

  def create_follow_submutation(options \\ []) do
    [context_id: var(:context_id)]
    |> gen_submutation(:create_follow, &follow_fields/1, options)
  end

  def follow_remote_actor_mutation(options \\ []) do
    [url: type!(:string)]
    |> gen_mutation(&follow_remote_actor_submutation/1, options)
  end

  def follow_remote_actor_submutation(options \\ []) do
    [url: var(:url)]
    |> gen_submutation(:createFollowByURL, &follow_fields/1, options)
  end

  ### invites

  def invite_mutation(options \\ []) do
    [email: type!(:string)]
    |> gen_mutation(&invite_submutation/1, options)
  end

  def invite_submutation(options \\ []) do
    [email: var(:email)]
    |> gen_submutation(:send_invite, &invite_fields/1, options)
  end

  ### deactivates

  def deactivation_mutation(options \\ []) do
    [id: type!(:string)]
    |> gen_mutation(&deactivation_submutation/1, options)
  end

  def deactivation_submutation(options \\ []) do
    [id: var(:id)]
    |> gen_submutation(:deactivate_user, &user_fields/1, options)
  end

  ### likes

  def like_query(options \\ []) do
    gen_query(:like_id, &like_subquery/1, options)
  end

  def like_subquery(options \\ []) do
    gen_subquery(:like_id, :like, &like_fields/1, options)
  end

  def likers_subquery(options \\ []) do
    args = [
      after: var(:likers_after),
      before: var(:likers_before),
      limit: var(:likers_limit)
    ]

    page_subquery(:likers, &like_fields/1, [{:args, args} | options])
  end

  def likes_subquery(options \\ []) do
    args = [
      after: var(:likes_after),
      before: var(:likes_before),
      limit: var(:likes_limit)
    ]

    page_subquery(:likes, &like_fields/1, [{:args, args} | options])
  end

  def create_like_mutation(options \\ []) do
    [context_id: type!(:string)]
    |> gen_mutation(&create_like_submutation/1, options)
  end

  def create_like_submutation(options \\ []) do
    [context_id: var(:context_id)]
    |> gen_submutation(:create_like, &like_fields/1, options)
  end

  ### resources

  def resource_spread(fields \\ []) do
    object_spread(:resource, fields: resource_fields(fields))
  end

  def resource_query(options \\ []) do
    gen_query(:resource_id, &resource_subquery/1, options)
  end

  def resource_subquery(options \\ []) do
    gen_subquery(:resource_id, :resource, &resource_fields/1, options)
  end

  def resources_query(options \\ []) do
    gen_query(:resources, &resources_subquery/1, options)
  end

  def resources_subquery(options \\ []) do
    args = [
      after: var(:resources_after),
      before: var(:resources_before),
      limit: var(:resources_limit)
    ]

    page_subquery(:resources, &resource_fields/1, [{:args, args} | options])
  end

  def create_resource_mutation(options \\ []) do
    [
      context_id: type!(:string),
      resource: type!(:resource_input),
      content: type!(:upload_input),
      icon: type(:upload_input)
    ]
    |> gen_mutation(&create_resource_submutation/1, options)
  end

  def create_resource_submutation(options \\ []) do
    [
      context_id: var(:context_id),
      resource: var(:resource),
      content: var(:content),
      icon: var(:icon)
    ]
    |> gen_submutation(:create_resource, &resource_fields/1, options)
  end

  def update_resource_mutation(options \\ []) do
    [
      resource_id: type!(:string),
      resource: type!(:resource_input),
      content: type(:upload_input),
      icon: type(:upload_input)
    ]
    |> gen_mutation(&update_resource_submutation/1, options)
  end

  def update_resource_submutation(options \\ []) do
    [
      resource_id: var(:resource_id),
      resource: var(:resource),
      content: var(:content),
      icon: var(:icon)
    ]
    |> gen_submutation(:update_resource, &resource_fields/1, options)
  end

  def copy_resource_mutation(options \\ []) do
    [context_id: type!(:string), resource_id: type!(:string)]
    |> gen_mutation(&copy_resource_submutation/1, options)
  end

  def copy_resource_submutation(options \\ []) do
    [context_id: var(:context_id), resource_id: var(:resource_id)]
    |> gen_submutation(:copy_resource, &resource_fields/1, options)
  end

  ### threads

  def threads_subquery(options \\ []) do
    args = Keyword.get(options, :args, [])
    fields = Keyword.get(options, :fields, [])

    field(:threads,
      args: args,
      fields: page_fields(thread_fields(fields))
    )
  end

  ### comments

  def comments_subquery(options \\ []) do
    args = Keyword.get(options, :args, [])
    fields = Keyword.get(options, :fields, [])

    field(:comments,
      args: args,
      fields: page_fields(comment_fields(fields))
    )
  end

  ### users

  def user_spread(fields \\ []) do
    object_spread(:user, fields: user_fields(fields))
  end

  def me_query(fields \\ []) do
    query(name: :test, fields: [me: me_fields(fields)])
  end

  def username_available_query() do
    query(
      name: :test,
      params: [username: type!(:string)],
      fields: [field(:username_available, args: [username: var(:username)])]
    )
  end

  def user_query(options \\ []) do
    gen_query(:user_id, &user_subquery/1, options)
  end

  def user_subquery(options \\ []) do
    gen_subquery(:user_id, :user, &user_fields/1, options)
  end

  def users_query(options \\ []) do
    gen_query(&users_subquery/1, options)
  end

  def users_subquery(options \\ []) do
    page_subquery(:users, &user_fields/1, options)
  end

  def create_user_mutation(options \\ []) do
    [user: type!(:registration_input)]
    |> gen_mutation(&create_user_submutation/1, options)
  end

  def create_user_submutation(options \\ []) do
    [user: var(:user)]
    |> gen_submutation(:create_user, &me_fields/1, options)
  end

  def confirm_email_mutation(options \\ []) do
    [token: type!(:string)]
    |> gen_mutation(&confirm_email_submutation/1, options)
  end

  def confirm_email_submutation(options \\ []) do
    [token: var(:token)]
    |> gen_submutation(:confirm_email, &auth_payload_fields/1, options)
  end

  def create_session_mutation(options \\ []) do
    [email: type!(:string), password: type!(:string)]
    |> gen_mutation(&create_session_submutation/1, options)
  end

  def create_session_submutation(options \\ []) do
    [email: var(:email), password: var(:password)]
    |> gen_submutation(:create_session, &auth_payload_fields/1, options)
  end

  def reset_password_request_mutation(_options \\ []) do
    mutation(
      name: :test,
      params: [email: type!(:string)],
      fields: [field(:reset_password_request, args: [email: var(:email)])]
    )
  end

  def reset_password_mutation(options \\ []) do
    [token: type!(:string), password: type!(:string)]
    |> gen_mutation(&reset_password_submutation/1, options)
  end

  def reset_password_submutation(options \\ []) do
    [token: var(:token), password: var(:password)]
    |> gen_submutation(:reset_password, &auth_payload_fields/1, options)
  end

  def update_profile_mutation(options \\ []) do
    [profile: type!(:update_profile_input)]
    |> gen_mutation(&update_profile_submutation/1, options)
  end

  def update_profile_submutation(options \\ []) do
    [profile: var(:profile)]
    |> gen_submutation(:update_profile, &me_fields/1, options)
  end

  def delete_self_mutation(options \\ []) do
    [i_am_sure: type!(:boolean)]
    |> gen_mutation(&delete_self_submutation/1, options)
  end

  def delete_self_submutation(_options \\ []) do
    field(:delete_self, args: [i_am_sure: var(:i_am_sure)])
  end

  def delete_session_mutation(_options \\ []) do
    mutation(name: :test, fields: [:delete_session])
  end

  def feature_basics() do
    """
    id canonicalUrl isLocal createdAt __typename
    """
  end
end
