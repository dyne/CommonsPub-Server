# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Meta.PointerTypeError do
  @moduledoc "An error indicating that a pointer is not for the required table"
  @enforce_keys [:pointer]
  defstruct @enforce_keys

  alias Pointers.Pointer

  @type t :: %__MODULE__{pointer: Pointer.t()}

  @spec new(Pointer.t()) :: t()
  @doc "Create a new PointerTypeError with the given Pointer"
  def new(%Pointer{} = pointer), do: %__MODULE__{pointer: pointer}
end
