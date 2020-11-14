# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Meta.PointersQueries do
  alias CommonsPub.Meta.TableService
  import Ecto.Query
  alias Pointers.{Pointer}

  def query(Pointer) do
    from(p in Pointer, as: :pointer)
  end

  def query(q, filters), do: filter(query(q), filters)

  @doc "Filter the query according to arbitrary criteria"
  def filter(q, filter_or_filters)

  ## by many

  def filter(q, filters) when is_list(filters) do
    Enum.reduce(filters, q, &filter(&2, &1))
  end

  ## by fields

  def filter(q, {:id, id}) when is_binary(id) do
    where(q, [pointer: p], p.id == ^id)
  end

  def filter(q, {:id, ids}) when is_list(ids) do
    where(q, [pointer: p], p.id in ^ids)
  end

  def filter(q, {:table, id}) when is_binary(id), do: where(q, [pointer: p], p.table_id == ^id)

  def filter(q, {:table, name}) when is_atom(name),
    do: filter(q, {:table, TableService.lookup_id!(name)})

  def filter(q, {:table, tables}) when is_list(tables) do
    tables = TableService.lookup_ids!(tables)
    where(q, [pointer: p], p.table_id in ^tables)
  end
end
