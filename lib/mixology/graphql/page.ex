# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.GraphQL.Page do
  @enforce_keys ~w(page_info total_count edges)a
  defstruct @enforce_keys

  alias CommonsPub.GraphQL.{Page, PageInfo}

  @type t :: %Page{
          page_info: PageInfo.t(),
          total_count: non_neg_integer,
          edges: [term]
        }

  def new(edges, total_count, cursor_fn, page_opts)
      when is_list(edges) and is_integer(total_count) and
             total_count >= 0 and is_function(cursor_fn, 1) do
    {page_info, edges} = paginate(edges, page_opts, cursor_fn)
    %Page{page_info: page_info, total_count: total_count, edges: edges}
  end

  # there are no results
  defp paginate([], _opts, _cursor_fn), do: {PageInfo.new(nil, nil, false, false), []}

  # there were results and we must check for the previous page marker
  defp paginate([e | es] = edges, %{after: a, limit: limit}, cursor_fn) do
    if cursor_fn.(e) == a,
      do: paginate_after(true, es, limit, cursor_fn),
      else: paginate_after(nil, Enum.take(edges, limit + 1), limit, cursor_fn)
  end

  # there were results and we must check for the next page marker
  defp paginate(edges, %{before: b, limit: limit}, cursor_fn) do
    if cursor_fn.(List.last(edges)) == b,
      do: paginate_before(true, :lists.droplast(edges), limit, cursor_fn),
      else: paginate_before(nil, Enum.slice(edges, -(limit - 1)..-1), limit, cursor_fn)
  end

  # there is no previous page
  defp paginate(edges, %{limit: limit}, cursor_fn) do
    paginate_after(false, edges, limit, cursor_fn)
  end

  # default limit
  defp paginate(edges, _, cursor_fn) do
    paginate_after(false, edges, 10, cursor_fn)
  end

  defp paginate_after(prev, edges, limit, cursor_fn) do
    if Enum.count(edges) > limit,
      do: pagination_result(prev, true, Enum.take(edges, limit), cursor_fn),
      else: pagination_result(prev, false, edges, cursor_fn)
  end

  defp paginate_before(next, edges, limit, cursor_fn) do
    if Enum.count(edges) > limit,
      do: pagination_result(true, next, Enum.take(edges, limit), cursor_fn),
      else: pagination_result(false, next, edges, cursor_fn)
  end

  defp pagination_result(prev, next, [], _) do
    {PageInfo.new(nil, nil, prev, next), []}
  end

  defp pagination_result(prev, next, edges, cursor_fn) do
    first = cursor_fn.(List.first(edges))
    last = cursor_fn.(List.last(edges))
    {PageInfo.new(first, last, prev, next), edges}
  end
end
