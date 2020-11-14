# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Common.Metadata do
  defmacro __using__(_) do
    quote do
      Module.register_attribute(__MODULE__, :will_break_when, accumulate: true)
    end
  end
end
