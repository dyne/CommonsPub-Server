# # SPDX-License-Identifier: AGPL-3.0-only
# defmodule CommonsPub.Meta.Migration do
#   import Ecto.Migration
#   import Ecto.Query, only: [from: 2]
#   alias CommonsPub.Meta.Table

#   @moduledoc """
#   Helpers for doing migrations to Meta related tables.

#   *Warning*: Do not use at runtime.
#   """

#   @doc """
#   Create a table in mn_tables, with relevant rows and triggers.
#   """
#   @spec create_meta_table!(atom()) :: Table.t()
#   def create_meta_table!(table) do
#     {:ok, table_row} = insert_meta_table(table)

#     :ok =
#       execute("""
#       create trigger "pointers_trigger_#{table}"
#       before insert on "#{table}"
#       for each row
#       execute procedure pointers_trigger()
#       """)

#     table_row
#   end

#   @doc """
#   Drop a table from mn_tables, deleting rows for a table and drop related triggers.
#   """
#   @spec drop_meta_table!(atom()) :: integer()
#   def drop_meta_table!(table) do
#     rows_deleted = remove_meta_table(table)

#     :ok =
#       execute("""
#       drop trigger if exists "pointers_trigger_#{table}" on "#{table}";
#       """)

#     rows_deleted
#   end

#   @doc """
#   Insert a table into the pointers_table.
#   """
#   @spec insert_meta_table(atom()) :: {:ok, Table.t()} | {:error, term()}
#   def insert_meta_table(table) do
#     repo().insert(%Table{table: table})
#   end

#   @doc """
#   Remove associated meta table from pointers_table, returns the number of rows deleted.
#   """
#   @spec remove_meta_table(atom()) :: integer()
#   def remove_meta_table(table) do
#     {rows_deleted, _} =
#       from(x in CommonsPub.Meta.Table, where: x.table == ^table) |> repo().delete_all

#     rows_deleted
#   end
# end
