# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.GraphQL.ResolveField do
  @moduledoc """
  Encapsulates the flow for resolving a field in the absence of
  multiple parents.
  """

  @enforce_keys [:module, :fetcher, :context, :info]
  defstruct @enforce_keys

  alias CommonsPub.GraphQL.ResolveField

  def run(%ResolveField{
        module: module,
        fetcher: fetcher,
        context: context,
        info: info
      }) do
    # not strictly required - no batch
    info2 = Map.take(info, [:context])
    apply(module, fetcher, [info2, context])
  end
end
