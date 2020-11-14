# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.GraphQL.FetchPages do
  @enforce_keys [:group_fn, :page_opts]
  defstruct [
    :queries,
    :query,
    :group_fn,
    :page_opts,
    :data_query,
    :count_query,
    cursor_fn: &__MODULE__.default_cursor/1,
    base_filters: [],
    data_filters: [],
    count_filters: [],
    map_fn: nil,
    map_counts_fn: nil
  ]

  alias CommonsPub.Repo
  alias CommonsPub.GraphQL.{Pages, FetchPages}

  @doc false
  def default_cursor(x), do: [x.id]

  @type t :: %FetchPages{
          queries: atom,
          query: atom,
          cursor_fn: (term -> [term]),
          group_fn: (term -> term),
          page_opts: map,
          data_query: Ecto.Queryable.t() | nil,
          count_query: Ecto.Queryable.t() | nil,
          base_filters: list,
          data_filters: list,
          count_filters: list,
          map_fn: (term -> term) | nil,
          map_counts_fn: (term -> term) | nil
        }

  def run(%FetchPages{
        cursor_fn: cursor_fn,
        group_fn: group_fn,
        page_opts: page_opts,
        data_query: data_query,
        count_query: count_query,
        map_fn: map_fn,
        map_counts_fn: map_counts_fn
      }) do
    {:ok, [data, counts]} = Repo.transact_many(all: data_query, all: count_query)
    data = group_data(data, group_fn, map_fn)
    counts = group_counts(counts, map_counts_fn)
    Pages.new(data, counts, cursor_fn, page_opts)
  end

  defp group_data(data, group_fn, nil), do: Enum.group_by(data, group_fn)
  defp group_data(data, group_fn, map_fn), do: Enum.group_by(data, group_fn, map_fn)

  defp group_counts(counts, nil), do: Map.new(counts)
  defp group_counts(counts, map_fn), do: Map.new(counts, map_fn)
end
