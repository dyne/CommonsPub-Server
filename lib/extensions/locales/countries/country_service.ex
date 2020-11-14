# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Locales.Country.Service do
  @moduledoc """
  An ets-based cache that allows lookup up Country objects by:

  * Database ID (string)

  On startup:
  * The database is queried for a list of countries
  * The data is inserted into an ets table owned by the process

  During operation, lookup requests will hit ets directly - this
  service exists solely to own the table and fit into the OTP
  supervision hierarchy neatly.
  """

  require Logger

  alias CommonsPub.Locales.{Country}

  alias CommonsPub.Repo
  import Ecto.Query, only: [select: 3]

  use GenServer

  @init_query_name __MODULE__
  @service_name __MODULE__
  @table_name __MODULE__.Cache

  # public api

  @doc "Starts up the service registering it locally under this module's name"
  @spec start_link() :: GenServer.on_start()
  def start_link(),
    do: GenServer.start_link(__MODULE__, name: @service_name)

  @doc "Lists all countries we know."
  @spec list_all() :: [Country.t()]
  def list_all() do
    case :ets.lookup(@table_name, :ALL) do
      [{_, r}] -> r
      _ -> []
    end
  end

  @doc "Look up a Country by iso2 code"
  @spec lookup(id :: binary()) :: {:ok, Country.t()} | {:error, Country.Error.NotFound.t()}
  def lookup(key) when is_binary(key),
    do: lookup_result(key, :ets.lookup(@table_name, key))

  defp lookup_result(_, []), do: {:error, Country.Error.NotFound.new()}
  defp lookup_result(_, [{_, v}]), do: {:ok, v}

  @spec lookup!(id :: binary) :: Country.t()
  @doc "Look up a Country by id code, throw Country.Error.NotFound if not found"
  def lookup!(key) do
    case lookup(key) do
      {:ok, v} -> v
      {:error, reason} -> throw(reason)
    end
  end

  # @spec lookup_id(id :: binary) :: {:ok, binary} | {:error, Country.Error.NotFound.t()}
  # @doc "Look up a country id by id code"
  # def lookup_id(key) do
  #   with {:ok, val} <- lookup(key), do: {:ok, val.id}
  # end

  # @spec lookup_id!(id :: binary) :: binary
  # @doc "Look up a country id by id code, throw Country.Error.NotFound if not found"
  # def lookup_id!(key) do
  #   case lookup_id(key) do
  #     {:ok, v} -> v
  #     {:error, reason} -> throw(reason)
  #   end
  # end

  # callbacks

  @doc false
  def init(_) do
    try do
      q()
      |> Repo.all(telemetry_event: @init_query_name)
      |> populate_countries()

      {:ok, []}
    rescue
      e ->
        Logger.info("TableService could not init because: #{inspect(e, pretty: true)}")
        {:ok, []}
    end
  end

  defp populate_countries(entries) do
    :ets.new(@table_name, [:named_table])
    # to enable list queries
    all = {:ALL, entries}

    indexed =
      Enum.flat_map(entries, fn country ->
        [{country.id, country}]
      end)

    true = :ets.insert(@table_name, [all | indexed])
  end

  import Ecto.Query, only: [from: 2]

  defp q() do
    from(c in Country, order_by: [asc: c.id])
  end
end
