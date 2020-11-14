# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Meta.Introspection do
  @moduledoc """
  Utilities for introspecting our use of Ecto within CommonsPub
  """

  @spec ecto_schema_modules() :: [atom()]
  @doc """
  Return a list of Ecto Schema modules in the CommonsPub OTP application
  Note: not all of these will represent database tables
  """
  def ecto_schema_modules(),
    do: Enum.filter(app_modules(), &is_ecto_schema_module?/1)

  @doc """
  Lists all modules in the CommonsPub OTP application
  """
  def app_modules(), do: Application.spec(:commons_pub, :modules)

  @spec ecto_schema_table(atom()) :: binary() | nil
  @doc """
  Queries an ecto schema module by name for the database table it represents
  """
  def ecto_schema_table(module) when is_atom(module),
    do: apply(module, :__schema__, [:source])

  @spec is_ecto_schema_module?(atom) :: boolean()
  @doc "true if the given atom names an Ecto Schema module"
  def is_ecto_schema_module?(module) do
    CommonsPub.Config.module_enabled?(module) and
      function_exported?(module, :__schema__, 1)
  end
end
