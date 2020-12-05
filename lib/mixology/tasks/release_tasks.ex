# SPDX-License-Identifier: AGPL-3.0-only

defmodule CommonsPub.ReleaseTasks do
  require Logger

  @start_apps [:commons_pub]
  @repos CommonsPub.Config.get(:ecto_repos, [])
  alias CommonsPub.{Communities, Repo, Users}
  alias CommonsPub.Users.User

  def create_db() do
    start_apps()

    create_repos()

    stop_services()
  end

  def create_repos() do
    Enum.each(@repos, &create_repo/1)
  end

  defp create_repo(repo) do
    try do
      case repo.__adapter__.storage_up(repo.config) do
        :ok ->
          Logger.info("The database for #{inspect(repo, pretty: true)} has been created")

        {:error, term} when is_binary(term) ->
          raise "The database for #{inspect(repo, pretty: true)} couldn't be created: #{term}"
      end
    rescue
      e ->
        Logger.warn("The database for #{inspect(repo, pretty: true)} could not be created")
        IO.inspect(e)
        :ok
    end
  end

  def migrate_db() do
    start_apps()
    start_repos()

    migrate_repos()

    stop_services()
  end

  def migrate_repos() do
    Enum.each(@repos, &migrate_repo/1)
  end

  defp migrate_repo(repo) do
    app = Keyword.get(repo.config, :otp_app)
    migrations_path = priv_path_for(repo, "migrations")
    IO.puts("Running migrations for #{app} from path #{migrations_path}")
    Ecto.Migrator.run(repo, migrations_path, :up, all: true)
  end

  def startup_migrations() do
    if is_nil(System.get_env("DISABLE_DB_AUTOMIGRATION")) do
      try do
        start_repos()
        create_repos()
        migrate_repos()
        stop_repos()
      rescue
        e ->
          Logger.warn("Could not run migrations on startup: ")
          IO.inspect(e)

          stop_repos()
          :ok
      end
    end
  end

  def rollback_db() do
    start_apps()
    start_repos()

    rollback_repos()

    stop_services()
  end

  def rollback_repos() do
    Enum.each(@repos, &rollback_repo/1)
  end

  def rollback_repos(step) do
    Enum.each(@repos, &rollback_repo(&1, step))
  end

  defp rollback_repo(repo) do
    rollback_repo(repo, 1)
  end

  defp rollback_repo(repo, step) do
    app = Keyword.get(repo.config, :otp_app)
    Logger.info("Running rollback for #{app}")
    migrations_path = priv_path_for(repo, "migrations")
    Ecto.Migrator.run(repo, migrations_path, :down, step: step)
  end

  def empty_db() do
    start_apps()
    start_repos()

    empty_repos()

    stop_services()
  end

  def empty_repos() do
    Enum.each(@repos, &empty_repo/1)
  end

  defp empty_repo(repo) do
    app = Keyword.get(repo.config, :otp_app)
    Logger.info("Running rollback for #{app}")
    migrations_path = priv_path_for(repo, "migrations")
    Ecto.Migrator.run(repo, migrations_path, :down, all: true)
  end

  def seed_db() do
    start_apps()

    start_repos()

    Enum.each(@repos, &migrate_repo/1)

    Enum.each(@repos, &seed_repo/1)

    stop_services()
  end

  defp seed_repo(repo) do
    # Run the seed script if it exists
    seed_script = priv_path_for(repo, "seeds.exs")

    if File.exists?(seed_script) do
      Logger.info("Running seed script..")
      Code.eval_file(seed_script)
    end
  end

  def drop_db() do
    start_apps()

    drop_repos()

    stop_services()
  end

  def drop_repos() do
    Enum.each(@repos, &drop_repo/1)
  end

  defp drop_repo(repo) do
    case repo.__adapter__.storage_down(repo.config) do
      :ok ->
        Logger.info("The database for #{inspect(repo, pretty: true)} has been dropped")

      {:error, :already_down} ->
        Logger.warn("The database for #{inspect(repo, pretty: true)} has already been dropped")

      {:error, term} when is_binary(term) ->
        raise "The database for #{inspect(repo, pretty: true)} couldn't be dropped: #{term}"
    end
  end

  defp start_apps() do
    Logger.debug("Starting dependencies..")
    # Start apps necessary for executing migrations
    Enum.each(@start_apps, &Application.ensure_all_started/1)
  end

  def start_repos() do
    # Start the Repo(s) for app
    Logger.debug("Starting repos..")

    # Switch pool_size to 2 for ecto > 3.0
    Enum.each(@repos, & &1.start_link(pool_size: 2))
  end

  def stop_repos() do
    # Stop the Repo(s) for app
    Logger.debug("Stopping repos..")

    Enum.each(@repos, & &1.stop())
  end

  def check_schema_config do
    pointable_schemas = CommonsPub.Meta.TableService.list_pointable_schemas()
    configured_types = CommonsPub.Config.get([CommonsPub.Instance, :types_all])
    IO.inspect(types_missing_from_config: pointable_schemas -- configured_types)
    IO.inspect(types_in_config_not_pointable_in_db: configured_types -- pointable_schemas)
    :ok
  end

  defp stop_services() do
    Logger.info("Success!")
    :init.stop()
  end

  defp priv_path_for(repo, filename) do
    app = Keyword.get(repo.config, :otp_app)

    repo_underscore =
      repo
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    priv_dir = "#{:code.priv_dir(app)}"

    Path.join([priv_dir, repo_underscore, filename])
  end

  def compile_dir(dir) when is_binary(dir) do
    dir
    |> File.ls!()
    |> Enum.map(&Path.join(dir, &1))
    |> Kernel.ParallelCompiler.compile()
  end

  def soft_delete_community(id) do
    Repo.transact_with(fn ->
      {:ok, community} = Communities.one(id: id)
      Communities.soft_delete(%User{}, community)
    end)
  end

  def user_set_email_confirmed(username) do
    Repo.transact_with(fn ->
      u = CommonsPub.Users.get!(username)
      Users.confirm_email(u)
    end)
  end

  def make_instance_admin(username) do
    Repo.transact_with(fn ->
      u = CommonsPub.Users.get!(username)
      Users.make_instance_admin(u)
    end)
  end

  def unmake_instance_admin(username) do
    Repo.transact_with(fn ->
      u = CommonsPub.Users.get!(username)
      Users.unmake_instance_admin(u)
    end)
  end

  @doc "Removes the pointer IDs and pointer of a table - deprecated, see Pointers lib instead"
  def remove_meta_table(table) do
    import Ecto.Query

    tt = Repo.one(from(x in Pointers.Table, where: x.table == ^table))

    if(!is_nil(tt) and !is_nil(tt.id)) do
      {_rows_deleted, _} =
        Repo.delete_all(from(x in Pointers.Pointer, where: x.table_id == ^tt.id))
    end

    {_rows_deleted, _} = Repo.delete_all(from(x in Pointers.Table, where: x.table == ^table))
  end

  @deleted_user %{
    id: Users.deleted_user_id(),
    peer_id: nil,
    preferred_username: "deleted",
    name: "(deleted user)",
    summary: "This user has deleted their account.",
    location: "A black hole.",
    website: "https://moodle.net/"
  }

  def create_deleted_user(), do: Users.register(@deleted_user)
end
