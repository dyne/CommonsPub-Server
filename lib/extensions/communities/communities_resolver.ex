# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.CommunitiesResolver do
  @moduledoc """
  Performs the GraphQL Community queries.
  """
  alias CommonsPub.{Activities, Communities, GraphQL, Repo}
  alias CommonsPub.Communities.Community

  alias CommonsPub.GraphQL.{
    FetchFields,
    Page,
    FetchPage,
    # FetchPages,
    ResolveField,
    ResolveFields,
    ResolvePage,
    ResolvePages,
    ResolveRootPage
  }

  alias CommonsPub.Web.GraphQL.UploadResolver

  def community(%{community_id: id}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_community,
      context: id,
      info: info
    })
  end

  def community(%{username: name}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_community_by_username,
      context: name,
      info: info
    })
  end

  def fetch_community(info, id) do
    Communities.one([:default, id: id, user: GraphQL.current_user(info)])
  end

  def fetch_community_by_username(info, name) do
    Communities.one([:default, username: name, user: GraphQL.current_user(info)])
  end

  def communities(%{} = page_opts, info) do
    ResolveRootPage.run(%ResolveRootPage{
      module: __MODULE__,
      fetcher: :fetch_communities,
      page_opts: page_opts,
      info: info,
      # followers
      cursor_validators: [&(is_integer(&1) and &1 >= 0), &Ecto.ULID.cast/1]
    })
  end

  def fetch_communities(page_opts, info) do
    FetchPage.run(%FetchPage{
      queries: Communities.Queries,
      query: Community,
      cursor_fn: Communities.cursor(:followers),
      page_opts: page_opts,
      base_filters: [user: GraphQL.current_user(info)],
      data_filters: [:default, page: [desc: [followers: page_opts]]]
    })
  end

  def communities_edge(%{id: id}, %{} = page_opts, info) do
    ResolvePages.run(%ResolvePages{
      module: __MODULE__,
      fetcher: :fetch_communities_edge,
      context: id,
      page_opts: page_opts,
      info: info
    })
  end

  def fetch_communities_edge(page_opts, info, ids) do
    user = GraphQL.current_user(info)

    FetchPage.run(%FetchPage{
      queries: Communities.Queries,
      query: Community,
      cursor_fn: Communities.cursor(:followers),
      page_opts: page_opts,
      base_filters: [context: ids, user: user],
      data_filters: [:default, page: [desc: [followers: page_opts]]]
    })
  end

  def inbox_edge(_community, _, _info) do
    {:ok, Page.new([], [], & &1.id, %{})}
  end

  def outbox_edge(%Community{character: %{outbox_id: id}}, page_opts, info) do
    with :ok <- GraphQL.not_in_list_or_empty_page(info) do
      ResolvePage.run(%ResolvePage{
        module: __MODULE__,
        fetcher: :fetch_outbox_edge,
        context: id,
        page_opts: page_opts,
        info: info
      })
    end
  end

  def fetch_outbox_edge(page_opts, _info, id) do
    tables = Communities.default_outbox_query_contexts()

    FetchPage.run(%FetchPage{
      queries: Activities.Queries,
      query: Activities.Activity,
      page_opts: page_opts,
      base_filters: [deleted: false, feed_timeline: id, table: tables],
      data_filters: [page: [desc: [created: page_opts]], preload: :context]
    })
  end

  def last_activity_edge(_, _, _info), do: {:ok, DateTime.utc_now()}

  def context_community_edge(%{context_id: id}, _, info) do
    ResolveFields.run(%ResolveFields{
      module: __MODULE__,
      fetcher: :fetch_parent_community_edge,
      context: id,
      info: info
    })
  end

  def fetch_parent_community_edge(_, ids) do
    FetchFields.run(%FetchFields{
      queries: Communities.Queries,
      query: Community,
      group_fn: & &1.id,
      filters: [:default, id: ids]
    })
  end

  ### mutations

  def create_community(%{community: attrs, context_id: context_id}, info)
      when is_nil(context_id) or context_id == "" do
    create_community(%{community: attrs}, info)
  end

  def create_community(%{community: attrs, context_id: context_id} = params, info) do
    with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
         {:ok, pointer} = CommonsPub.Meta.Pointers.one(id: context_id),
         #  :ok <- validate_context(pointer),
         context = CommonsPub.Meta.Pointers.follow!(pointer),
         {:ok, uploads} <- UploadResolver.upload(user, params, info) do
      Communities.create(user, context, Map.merge(attrs, uploads))
    end
  end

  def create_community(%{community: attrs} = params, info) do
    with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
         {:ok, uploads} <- UploadResolver.upload(user, params, info) do
      Communities.create(user, Map.merge(attrs, uploads))
    end
  end

  def update_community(%{community: changes, community_id: id} = params, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, community} <- community(%{community_id: id}, info) do
        cond do
          user.local_user.is_instance_admin or community.creator_id == user.id ->
            with {:ok, uploads} <- UploadResolver.upload(user, params, info),
                 do: Communities.update(user, community, Map.merge(changes, uploads))

          is_nil(community.published_at) ->
            GraphQL.not_found()

          true ->
            GraphQL.not_permitted()
        end
      end
    end)
  end

  # def delete(%{community_id: id}, info) do
  #   Repo.transact_with(fn ->
  #     with {:ok, user} <- GraphQL.current_user(info),
  #          {:ok, actor} <- Users.fetch_actor(user),
  #          {:ok, community} <- Communities.fetch(id) do
  #       if community.creator_id == actor.id do
  # 	  with {:ok, _} <- Communities.soft_delete(community), do: {:ok, true}
  #       else
  #         GraphQL.not_permitted()
  #       end
  #     end
  #   end)
  #   |> GraphQL.response(info)
  # end
end
