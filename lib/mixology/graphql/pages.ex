# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.GraphQL.Pages do
  @enforce_keys ~w(data counts cursor_fn page_opts)a
  defstruct @enforce_keys

  alias CommonsPub.GraphQL.{Page, Pages}

  @type data :: %{term => term}
  @type counts :: %{term => non_neg_integer}
  @type t :: %Pages{data: data, counts: counts, cursor_fn: (term -> term)}

  @doc """
  Create a new pages from a data map, counts map, cursor function and page opts
  """
  def new(data, counts, cursor_fn, page_opts)
      when is_function(cursor_fn, 1) do
    %Pages{data: data, counts: counts, cursor_fn: cursor_fn, page_opts: page_opts}
  end

  @doc """
  Create a new Pages from some data rows, count rows and a
  grouping key. Groups the data by the grouping key on insertion and
  turns the counts into a map ready for lookup on a per-row basis.

  Note: if the grouping key is not present in the returned data rows,
  this function will crash. Our intuition is that this would mean an
  error in the calling code, so we would rather raise it early.
  """
  def new(data_rows, count_rows, group_fn, cursor_fn, %{} = page_opts)
      when is_list(data_rows) and is_list(count_rows) and
             is_function(group_fn, 1) and is_function(cursor_fn, 1) do
    data = Enum.group_by(data_rows, group_fn)
    counts = Map.new(count_rows)
    %Pages{data: data, counts: counts, cursor_fn: cursor_fn, page_opts: page_opts}
  end

  @doc "Returns a Page for the given key, defaulting to an empty one"
  def get(
        %Pages{
          data: data,
          counts: counts,
          cursor_fn: cursor_fn,
          page_opts: page_opts
        },
        key
      ) do
    data = Map.get(data, key, [])
    count = Map.get(counts, key, 0)
    {:ok, Page.new(data, count, cursor_fn, page_opts)}
  end

  @doc """
  Returns a post-batch callback (i.e. the third argument to batch/3)
  for a key which calls get() with the callback param and the key
  """
  def getter(key) do
    fn edge_lists -> get(edge_lists, key) end
  end
end
