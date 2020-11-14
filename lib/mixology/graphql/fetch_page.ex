# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.GraphQL.FetchPage do
  @enforce_keys [:queries, :query, :page_opts]
  defstruct [
    :queries,
    :query,
    :page_opts,
    cursor_fn: &__MODULE__.default_cursor/1,
    base_filters: [],
    data_filters: [],
    count_filters: [],
    count_with: :count,
    map_fn: nil,
    map_count_fn: nil
  ]

  alias CommonsPub.Repo
  alias CommonsPub.GraphQL.{Page, FetchPage}


  @doc false
  def default_cursor(x), do: [x.id]

  @type t :: %FetchPage{
          queries: atom,
          query: atom,
          cursor_fn: (term -> [term]),
          page_opts: map,
          base_filters: list,
          data_filters: list,
          count_filters: list,
          count_with: :count | :all,
          map_fn: (term -> term) | nil,
          map_count_fn: (term -> term) | nil
        }

  def run(%FetchPage{
        queries: queries,
        query: query,
        cursor_fn: cursor_fn,
        page_opts: page_opts,
        base_filters: base_filters,
        data_filters: data_filters,
        count_filters: count_filters,
        count_with: count_with,
        map_fn: map_fn,
        map_count_fn: map_count_fn
      }) do
    base_q = apply(queries, :query, [query, base_filters])
    data_q = apply(queries, :filter, [base_q, data_filters])
    count_q = apply(queries, :filter, [base_q, count_filters])
    # IO.inspect(FetchPage_run_data: data_q, count_with: count_q)
    {:ok, [data, count]} = Repo.transact_many([{:all, data_q}, {count_with, count_q}])

    # IO.inspect(FetchPage_run_data: data, count: count)
    data = map_data(map_fn, data)
    count = map_count(map_count_fn, count)
    # IO.inspect(mapped_data: data, mapped_count: count)
    ret = Page.new(data, count, cursor_fn, page_opts)
    {:ok, ret}
  end

  defp map_data(nil, data), do: data
  defp map_data(fun, data) when is_function(fun, 1), do: Enum.map(data, fun)

  defp map_count(nil, data), do: data
  defp map_count(fun, data) when is_function(fun, 1), do: fun.(data)
end
