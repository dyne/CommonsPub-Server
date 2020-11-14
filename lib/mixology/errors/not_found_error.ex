# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Common.NotFoundError do
  @enforce_keys [:message, :code, :status]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          message: binary,
          code: binary,
          status: integer
        }

  @doc "Create a new NotFoundError"
  @spec new() :: t
  def new() do
    %__MODULE__{
      message: "Not found",
      code: "not_found",
      status: 404
    }
  end
end
