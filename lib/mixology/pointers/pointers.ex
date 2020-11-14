# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Meta.Pointers do
  alias CommonsPub.Meta.{PointersQueries, TableService}
  alias CommonsPub.Repo
  alias Pointers.{Pointer}

  def get(id, filters \\ [])

  def get(id, filters) when is_binary(id) do
    if CommonsPub.Common.is_ulid(id) do
      with {:ok, pointer} <- one(id: id) do
        get(pointer, filters)
      end
    else
      {:error, CommonsPub.Common.NotFoundError.new()}
    end
  end

  def get(%Pointer{} = pointer, filters) do
    follow!(pointer, filters)
  end

  def get(%{} = thing, _) do
    thing
  end

  def one(filters), do: Repo.single(PointersQueries.query(Pointer, filters))

  def one!(filters), do: Repo.one!(PointersQueries.query(Pointer, filters))

  def many(filters \\ []), do: {:ok, Repo.all(PointersQueries.query(Pointer, filters))}

  # already have a pointer - just return it
  def maybe_forge!(%Pointer{} = pointer), do: pointer

  # for ActivityPub objects (like ActivityPub.Actor)
  def maybe_forge!(%{pointer_id: pointer_id} = _ap_object), do: one!(id: pointer_id)

  # forge a pointer
  def maybe_forge!(%{__struct__: _} = pointed), do: forge!(pointed)

  @doc """
  Retrieves the Table that a pointer points to
  Note: Throws a TableNotFoundError if the table cannot be found
  """
  @spec table!(Pointer.t()) :: Table.t()
  def table!(%Pointer{table_id: id}), do: TableService.lookup!(id)

  @doc """
  Forge a pointer from a structure that participates in the meta abstraction.

  Does not hit the database.

  Is safe so long as the provided struct participates in the meta abstraction.
  """
  @spec forge!(%{__struct__: atom, id: binary}) :: %Pointer{}
  def forge!(%{__struct__: table_id, id: id} = pointed) do
    # IO.inspect(forge: pointed)
    table = TableService.lookup!(table_id)
    %Pointer{id: id, table: table, table_id: table.id, pointed: pointed}
  end

  @doc """
  Forges a pointer to a participating meta entity.

  Does not hit the database, is safe so long as the entry we wish to
  synthesise a pointer for represents a legitimate entry in the database.
  """
  @spec forge!(table_id :: integer | atom, id :: binary) :: %Pointer{}
  def forge!(table_id, id) do
    table = TableService.lookup!(table_id)
    %Pointer{id: id, table: table, table_id: table.id}
  end

  def follow!(pointer_or_pointers, filters \\ []) do
    case preload!(pointer_or_pointers, [], filters) do
      %Pointer{} = pointer -> pointer.pointed
      pointers -> Enum.map(pointers, & &1.pointed)
    end
  end

  @spec preload!(Pointer.t() | [Pointer.t()]) :: Pointer.t() | [Pointer.t()]
  @spec preload!(Pointer.t() | [Pointer.t()], list) :: Pointer.t() | [Pointer.t()]

  @doc """
  Follows one or more pointers and adds the pointed records to the `pointed` attrs
  """
  def preload!(pointer_or_pointers, opts \\ [], filters \\ [])

  def preload!(%Pointer{id: id, table_id: table_id} = pointer, opts, filters) do
    # IO.inspect(pointer)

    if is_nil(pointer.pointed) or Keyword.get(opts, :force) do
      {:ok, [pointed]} = loader(table_id, [id: id], filters)
      %{pointer | pointed: pointed}
    else
      pointer
    end
  end

  def preload!(pointers, opts, filters) when is_list(pointers) do
    pointers
    |> preload_load(opts, filters)
    |> preload_collate(pointers)
  end

  def preload!(%{__struct__: _} = pointed, _, _), do: pointed

  defp preload_collate(loaded, pointers), do: Enum.map(pointers, &collate(loaded, &1))

  defp collate(_, nil), do: nil
  defp collate(loaded, %{} = p), do: %{p | pointed: Map.get(loaded, p.id, %{})}

  defp preload_load(pointers, opts, filters) do
    force = Keyword.get(opts, :force, false)

    pointers
    # find ids
    |> Enum.reduce(%{}, &preload_search(force, &1, &2))
    # query
    |> Enum.reduce(%{}, &preload_per_table(&1, &2, filters))
  end

  defp preload_search(false, %{pointed: pointed}, acc)
       when not is_nil(pointed),
       do: acc

  defp preload_search(_force, pointer, acc) do
    ids = [pointer.id | Map.get(acc, pointer.table_id, [])]
    Map.put(acc, pointer.table_id, ids)
  end

  defp preload_per_table({table_id, ids}, acc, filters) do
    {:ok, items} = loader(table_id, [id: ids], filters)
    Enum.reduce(items, acc, &Map.put(&2, &1.id, &1))
  end

  defp loader(schema, id_filters, override_filters) when not is_atom(schema) do
    loader(TableService.lookup_schema!(schema), id_filters, override_filters)
  end

  defp loader(schema, id_filters, override_filters) do
    module = apply(schema, :queries_module, [])
    filters = filters(schema, id_filters, override_filters)
    # IO.inspect(filters)
    {:ok, Repo.all(apply(module, :query, [schema, filters]))}
  end

  defp filters(schema, id_filters, []) do
    id_filters ++ apply(schema, :follow_filters, [])
  end

  defp filters(_schema, id_filters, override_filters) do
    id_filters ++ override_filters
  end
end
