defmodule CommonsPub.GraphQL.ResolvePage do
  @moduledoc """
  Encapsulates the flow of resolving a page in the presence of a
  single parent. We also currently use this as a stopgap while we
  finish implementing some things, trading speed for correctness.
  """

  @enforce_keys [:module, :fetcher, :context, :page_opts, :info]
  defstruct [
    :module,
    :fetcher,
    :context,
    :page_opts,
    :info,
    cursor_validators: [&Ecto.ULID.cast/1],
    paging_opts: %{default_limit: 10}
  ]

  alias CommonsPub.GraphQL
  alias CommonsPub.GraphQL.ResolvePage

  def run(%ResolvePage{
        module: module,
        fetcher: fetcher,
        context: context,
        page_opts: page_opts,
        paging_opts: opts,
        info: info,
        cursor_validators: validators
      }) do
    with {:ok, page_opts} <- GraphQL.full_page_opts(page_opts, validators, opts) do
      info2 = Map.take(info, [:context])

      case apply(module, fetcher, [page_opts, info2, context]) do
        {:ok, good} -> {:ok, good}
        {:error, bad} -> {:error, bad}
        good -> {:ok, good}
      end
    end
  end
end
