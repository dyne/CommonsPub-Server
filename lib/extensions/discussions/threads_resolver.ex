# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.ThreadsResolver do
  alias CommonsPub.{GraphQL, Repo, Threads}

  alias CommonsPub.GraphQL.{
    FetchPage,
    # FetchPages,
    ResolveField,
    ResolvePages
    # ResolveRootPage
  }

  alias CommonsPub.Threads.{Comments, Thread}

  def thread(%{thread_id: id}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_thread,
      context: id,
      info: info
    })
  end

  def fetch_thread(info, id) do
    Threads.one(id: id, user: GraphQL.current_user(info))
  end

  # edges

  def threads_edge(%{id: id}, %{} = page_opts, info) do
    ResolvePages.run(%ResolvePages{
      module: __MODULE__,
      fetcher: :fetch_threads_edge,
      context: id,
      page_opts: page_opts,
      info: info
    })
  end

  # def fetch_threads_edge({page_opts, info}, ids) do
  #   user = GraphQL.current_user(info)
  #   FetchPages.run(
  #     %FetchPages{
  #       queries: Threads.Queries,
  #       query: Thread,
  #       cursor_fn: Threads.cursor(:followers),
  #       group_fn: &(&1.context_id),
  #       page_opts: page_opts,
  #       base_filters: [user: user, context: ids],
  #       data_filters: [page: [desc: [followers: page_opts]]],
  #       count_filters: [group_count: :context_id],
  #     }
  #   )
  # end

  def fetch_threads_edge(page_opts, info, ids) do
    user = GraphQL.current_user(info)

    FetchPage.run(%FetchPage{
      queries: Threads.Queries,
      query: Thread,
      cursor_fn: Threads.cursor(:followers),
      page_opts: page_opts,
      base_filters: [user: user, context: ids],
      data_filters: [page: [desc: [followers: page_opts]]]
    })
  end

  def creator_threads_edge(%{creator: creator}, %{} = page_opts, info) do
    # IO.inspect(
    ResolvePages.run(%ResolvePages{
      module: __MODULE__,
      fetcher: :fetch_creator_threads_edge,
      context: creator,
      page_opts: page_opts,
      info: info
    })

    # )
  end

  def fetch_creator_threads_edge(page_opts, info, ids) do
    user = GraphQL.current_user(info)

    list_creator_threads(
      page_opts,
      [user: user, creator: ids],
      [page: [desc: [followers: page_opts]]],
      [:followers]
    )
  end

  def list_creator_threads(page_opts, base_filters, data_filters, _cursor_type) do
    # IO.inspect(
    FetchPage.run(%FetchPage{
      queries: Threads.Queries,
      query: Thread,
      # cursor_fn: Threads.cursor(cursor_type),
      page_opts: page_opts,
      base_filters: base_filters,
      data_filters: data_filters
    })

    # )
  end

  ## mutations

  def create_thread(%{comment: attrs, context_id: context_id}, info)
      when is_nil(context_id) or context_id == "" do
    create_thread(%{comment: attrs}, info)
  end

  @doc "Create a thread in a community or other context"
  def create_thread(%{context_id: context_id, comment: attrs}, info) do
    with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info) do
      attrs = Map.put(attrs, :is_local, true)

      Repo.transact_with(fn ->
        with {:ok, pointer} = CommonsPub.Meta.Pointers.one(id: context_id),
             :ok <- validate_thread_context(pointer),
             context = CommonsPub.Meta.Pointers.follow!(pointer),
             {:ok, thread} <- Threads.create(user, attrs, context) do
          Comments.create(user, thread, attrs)
        end
      end)
    end
  end

  @doc "Create a thread with no context, via GraphQL"
  def create_thread(%{comment: attrs}, info) do
    with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info) do
      attrs = Map.put(attrs, :is_local, true)

      Threads.create_with_comment(user, attrs)
    end
  end

  defp validate_thread_context(pointer) do
    schema = CommonsPub.Meta.Pointers.table!(pointer).schema

    if schema in valid_contexts() do
      :ok
    else
      IO.inspect(not_permitted_context: schema)
      IO.inspect(valid_contexts())
      GraphQL.not_permitted()
    end
  end

  defp valid_contexts() do
    CommonsPub.Config.get([Threads, :valid_contexts])
  end

  def last_activity_edge(_, _, _info), do: {:ok, DateTime.utc_now()}
end
