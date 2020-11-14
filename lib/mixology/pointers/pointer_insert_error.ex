# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Meta.PointerInsertError do
  @moduledoc "An error indicating that inserting a pointer failed"
  @enforce_keys [:changeset]
  defstruct @enforce_keys

  alias Ecto.Changeset

  @type t :: %__MODULE__{changeset: Changeset.t()}

  @spec new(Changeset.t()) :: t()
  @doc "Create a new PointerInsertError with the given Pointer changeset"
  def new(%Changeset{} = changeset), do: %__MODULE__{changeset: changeset}
end
