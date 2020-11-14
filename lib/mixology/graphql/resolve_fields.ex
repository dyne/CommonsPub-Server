# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.GraphQL.ResolveFields do
  @moduledoc """
  Encapsulates the flow for resolving a field for potentially multiple
  parents.
  """

  alias CommonsPub.GraphQL.{Fields, ResolveFields}
  import Absinthe.Resolution.Helpers, only: [batch: 3]

  @enforce_keys [:module, :fetcher, :context, :info]
  defstruct [
    :module,
    :fetcher,
    :context,
    :info,
    default: nil,
    getter_fn: &Fields.getter/2
  ]

  @type getter :: (%{term => term} -> term)

  @type t :: %ResolveFields{
          module: atom,
          fetcher: atom,
          context: term,
          info: map,
          default: term,
          getter_fn: (context :: term, default :: term -> getter)
        }

  def run(%ResolveFields{
        module: module,
        fetcher: fetcher,
        context: context,
        info: info,
        default: default,
        getter_fn: getter
      })
      when is_function(getter, 2) do
    batch({module, fetcher, Map.take(info, [:context])}, context, getter.(context, default))
  end

  def default_getter(context, default), do: Fields.getter(context, default)
end
