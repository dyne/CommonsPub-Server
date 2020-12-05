# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Repo do
  @moduledoc """
  CommonsPub main Ecto Repo
  """
  require Logger

  use Ecto.Repo,
    otp_app: :commons_pub,
    adapter: Ecto.Adapters.Postgres

  import Ecto.Query
  alias CommonsPub.Common.NotFoundError

  @doc """
  Dynamically loads the repository url from the
  DATABASE_URL environment variable.
  """
  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL"))}
  end

  @doc """
  Like Repo.one, but returns an ok/error tuple.
  """
  def single(q) do
    case one(q) do
      nil -> {:error, NotFoundError.new()}
      other -> {:ok, other}
    end
  end

  @doc "Like Repo.get, but returns an ok/error tuple"
  @spec fetch(atom, integer | binary) :: {:ok, atom} | {:error, NotFoundError.t()}
  def fetch(queryable, id) do
    case get(queryable, id) do
      nil -> {:error, NotFoundError.new()}
      thing -> {:ok, thing}
    end
  end

  @doc "Like Repo.get_by, but returns an ok/error tuple"
  def fetch_by(queryable, term) do
    case get_by(queryable, term) do
      nil -> {:error, NotFoundError.new()}
      thing -> {:ok, thing}
    end
  end

  def fetch_all(queryable, ids) when is_binary(ids) do
    queryable
    |> where([t], t.id in ^ids)
    |> all()
  end

  @doc """
  Run a transaction, similar to `Repo.transaction/1`, but it expects an ok or error
  tuple. If an error tuple is returned, the transaction is aborted.
  """
  @spec transact_with(fun :: (() -> {:ok, any} | {:error, any})) :: {:ok, any} | {:error, any}
  def transact_with(fun) do
    transaction(fn ->
      ret = fun.()

      case ret do
        :ok -> :ok
        {:ok, v} -> v
        # {:ok, v, v2} -> {:ok, v, v2}
        {:error, reason} -> rollback_error(reason)
        _ -> rollback_unexpected(ret)
      end
    end)
  end

  defp rollback_error(reason) do
    Logger.debug(transact_with_error: reason)
    rollback(reason)
  end

  defp rollback_unexpected(ret) do
    Logger.error(
      "Repo transaction expected one of `:ok` `{:ok, value}` `{:error, reason}` but got: #{
        inspect(ret)
      }"
    )

    rollback("transact_with_unexpected_case")
  end

  def transact_many([]), do: {:ok, []}

  def transact_many(queries) when is_list(queries) do
    transaction(fn -> Enum.map(queries, &transact/1) end)
  end

  defp transact({:all, q}), do: all(q)
  defp transact({:count, q}), do: aggregate(q, :count)
  defp transact({:one, q}), do: one(q)

  defp transact({:one!, q}) do
    {:ok, ret} = single(q)
    ret
  end

  def maybe_preload(obj, :context) do
    CommonsPub.Contexts.prepare_context(obj)
  end

  def maybe_preload(obj, preloads) do
    maybe_do_preload(obj, preloads)
  end

  def maybe_do_preload(%Ecto.Association.NotLoaded{}, _), do: nil

  def maybe_do_preload(obj, preloads) when is_struct(obj) do
    CommonsPub.Repo.preload(obj, preloads)
  rescue
    ArgumentError ->
      obj

    MatchError ->
      obj
  end

  def maybe_do_preload(obj, _), do: obj
end
