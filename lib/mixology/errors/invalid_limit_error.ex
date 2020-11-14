# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Common.InvalidLimitError do
  @enforce_keys [:message, :code, :status]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          message: binary,
          code: binary,
          status: integer
        }

  @doc "Create a new InvalidLimitError"
  @spec new() :: t
  def new() do
    %__MODULE__{
      message:
        "The provided limit was invalid. It must be a positive integer no greater than 100",
      code: "invalid_limit",
      status: 400
    }
  end
end
