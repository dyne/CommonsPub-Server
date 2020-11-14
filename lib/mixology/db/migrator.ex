defmodule CommonsPub.Repo.Migrator do
@moduledoc """
TODO: add such a migrator to supervision tree
"""
  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], [])
  end

  def init(_) do

    # CommonsPub.ReleaseTasks.startup_migrations()
    # CommonsPub.ReleaseTasks.migrate_repos()

    {:ok, nil}
  end

end
