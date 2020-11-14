# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Common.NotInTransactionError do
  @enforce_keys [:cause]
  defstruct @enforce_keys

  @type t :: %__MODULE__{cause: term()}

  @spec new(term()) :: t()
  def new(cause), do: %__MODULE__{cause: cause}
end
