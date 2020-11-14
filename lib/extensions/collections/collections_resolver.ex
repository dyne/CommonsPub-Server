# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.CollectionsResolver do
  alias CommonsPub.{
    Activities,
    Collections,
    Communities,
    GraphQL,
    Repo
    # Resources
  }

  alias CommonsPub.GraphQL.{
    FetchFields,
    FetchPage,
    ResolveField,
    ResolveFields,
    ResolvePage,
    ResolvePages,
    ResolveRootPage
  }

  alias CommonsPub.Communities.Community
  alias CommonsPub.Collections.Collection
  # alias CommonsPub.Resources.Resource
  alias CommonsPub.Web.GraphQL.UploadResolver

  ## resolvers

  def collection(%{collection_id: id}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_collection,
      context: id,
      info: info
    })
  end

  def collection(%{username: name}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_collection_by_username,
      context: name,
      info: info
    })
  end

  def collections(page_opts, info) do
    ResolveRootPage.run(%ResolveRootPage{
      module: __MODULE__,
      fetcher: :fetch_collections,
      page_opts: page_opts,
      info: info,
      # popularity
      cursor_validators: [&(is_integer(&1) and &1 >= 0), &Ecto.ULID.cast/1]
    })
  end

  ## fetchers

  def fetch_collection(info, id) do
    Collections.one(
      user: GraphQL.current_user(info),
      id: id,
      join: :character,
      preload: :character
    )
  end

  def fetch_collection_by_username(info, name) do
    Collections.one([:default, username: name, user: GraphQL.current_user(info)])
  end

  def fetch_collections(page_opts, info) do
    FetchPage.run(%FetchPage{
      queries: Collections.Queries,
      query: Collection,
      cursor_fn: Collections.cursor(:followers),
      page_opts: page_opts,
      base_filters: [deleted: false, user: GraphQL.current_user(info)],
      data_filters: [join: :character, preload: :character, page: [desc: [followers: page_opts]]]
    })
  end

  def collection_count_edge(%{id: id}, _, info) do
    ResolveFields.run(%ResolveFields{
      module: __MODULE__,
      fetcher: :fetch_collection_count_edge,
      context: id,
      info: info,
      default: 0
    })
  end

  def fetch_collection_count_edge(_, ids) do
    FetchFields.run(%FetchFields{
      queries: Collections.Queries,
      query: Collection,
      group_fn: &elem(&1, 0),
      map_fn: &elem(&1, 1),
      filters: [community: ids, group_count: :context_id]
    })
  end

  def collections_edge(%{id: id}, %{} = page_opts, info) do
    ResolvePages.run(%ResolvePages{
      module: __MODULE__,
      fetcher: :fetch_collections_edge,
      context: id,
      page_opts: page_opts,
      info: info
    })
  end

  # def collections_edge(%Community{collections: cs}, _, _info) when is_list(cs), do: {:ok, cs}
  # def collections_edge(%Community{id: id}, %{}=page_opts, info) do
  #   opts = %{default_limit: 10}
  #   Flow.pages(__MODULE__, :fetch_collections_edge, page_opts, id, info, opts)
  # end

  # def fetch_collections_edge({page_opts, info}, ids) do
  #   user = GraphQL.current_user(info)
  #   FetchPages.run(
  #     %FetchPages{
  #       queries: Collections.Queries,
  #       query: Collection,
  #       cursor_fn: Collections.cursor(:followers),
  #       group_fn: &(&1.context_id),
  #       page_opts: page_opts,
  #       base_filters: [community: ids, user: user],
  #       data_filters: [:default, page: [desc: [followers: page_opts]]],
  #       count_filters: [group_count: :context_id],
  #     }
  #   )
  # end

  def fetch_collections_edge(page_opts, info, ids) do
    user = GraphQL.current_user(info)

    FetchPage.run(%FetchPage{
      queries: Collections.Queries,
      query: Collection,
      cursor_fn: Collections.cursor(:followers),
      page_opts: page_opts,
      base_filters: [context: ids, user: user],
      data_filters: [:default, page: [desc: [followers: page_opts]]]
    })
  end

  def last_activity_edge(_, _, _info) do
    {:ok, DateTime.utc_now()}
  end

  def outbox_edge(%Collection{character: %{outbox_id: id}}, page_opts, info) do
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
    tables = Collections.default_outbox_query_contexts()

    FetchPage.run(%FetchPage{
      queries: Activities.Queries,
      query: Activities.Activity,
      page_opts: page_opts,
      base_filters: [deleted: false, feed_timeline: id, table: tables],
      data_filters: [page: [desc: [created: page_opts]], preload: :context]
    })
  end

  ## finally the mutations...

  def create_collection(%{collection: attrs, context_id: context_id}, info)
      when is_nil(context_id) or context_id == "" do
    create_collection(%{collection: attrs}, info)
  end

  def create_collection(%{collection: attrs, context_id: context_id} = params, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, pointer} = CommonsPub.Meta.Pointers.one(id: context_id),
           #  :ok <- validate_context(pointer),
           context = CommonsPub.Meta.Pointers.follow!(pointer),
           {:ok, uploads} <- UploadResolver.upload(user, params, info) do
        attrs =
          attrs
          |> Map.put(:is_public, true)
          |> Map.merge(uploads)

        Collections.create(user, context, attrs)
      end
    end)
  end

  # Create a collection without context
  def create_collection(%{collection: attrs} = params, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, uploads} <- UploadResolver.upload(user, params, info) do
        attrs =
          attrs
          |> Map.put(:is_public, true)
          |> Map.merge(uploads)

        Collections.create(user, attrs)
      end
    end)
  end

  def update_collection(%{collection: changes, collection_id: id} = params, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, collection} <- collection(%{collection_id: id}, info) do
        collection = Repo.preload(collection, :community)

        permitted? =
          user.local_user.is_instance_admin or
            collection.creator_id == user.id

        if permitted? do
          with {:ok, uploads} <- UploadResolver.upload(user, params, info) do
            Collections.update(user, collection, Map.merge(changes, uploads))
          end
        else
          GraphQL.not_permitted("update")
        end
      end
    end)
  end
end
