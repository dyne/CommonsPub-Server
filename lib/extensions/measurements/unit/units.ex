# SPDX-License-Identifier: AGPL-3.0-only
defmodule Measurement.Unit.Units do
  alias CommonsPub.{
    # Activities,
    # Actors,
    Common,
    # Feeds,
    # Follows,
    Repo
  }

  alias CommonsPub.GraphQL.{Fields, Page}
  alias CommonsPub.Contexts
  alias Measurement.Unit
  alias Measurement.Unit.Queries
  # alias CommonsPub.Feeds.FeedActivities
  alias CommonsPub.Users.User

  def cursor(), do: &[&1.id]
  def test_cursor(), do: &[&1["id"]]

  @doc """
  Retrieves a single collection by arbitrary filters.
  Used by:
  * GraphQL Item queries
  * ActivityPub integration
  * Various parts of the codebase that need to query for collections (inc. tests)
  """
  def one(filters), do: Repo.single(Queries.query(Unit, filters))

  @doc """
  Retrieves a list of collections by arbitrary filters.
  Used by:
  * Various parts of the codebase that need to query for collections (inc. tests)
  """
  def many(filters \\ []), do: {:ok, Repo.all(Queries.query(Unit, filters))}

  def fields(group_fn, filters \\ [])
      when is_function(group_fn, 1) do
    {:ok, fields} = many(filters)
    {:ok, Fields.new(fields, group_fn)}
  end

  @doc """
  Retrieves an Page of units according to various filters

  Used by:
  * GraphQL resolver single-parent resolution
  """
  def page(cursor_fn, page_opts, base_filters \\ [], data_filters \\ [], count_filters \\ [])

  def page(cursor_fn, %{} = page_opts, base_filters, data_filters, count_filters) do
    base_q = Queries.query(Unit, base_filters)
    data_q = Queries.filter(base_q, data_filters)
    count_q = Queries.filter(base_q, count_filters)

    with {:ok, [data, counts]} <- Repo.transact_many(all: data_q, count: count_q) do
      {:ok, Page.new(data, counts, cursor_fn, page_opts)}
    end
  end

  @doc """
  Retrieves an Pages of units according to various filters

  Used by:
  * GraphQL resolver bulk resolution
  """
  def pages(
        cursor_fn,
        group_fn,
        page_opts,
        base_filters \\ [],
        data_filters \\ [],
        count_filters \\ []
      )

  def pages(cursor_fn, group_fn, page_opts, base_filters, data_filters, count_filters) do
    Contexts.pages(
      Queries,
      Unit,
      cursor_fn,
      group_fn,
      page_opts,
      base_filters,
      data_filters,
      count_filters
    )
  end

  ## mutations

  @spec create(User.t(), attrs :: map) :: {:ok, Unit.t()} | {:error, Changeset.t()}
  def create(%User{} = creator, attrs) when is_map(attrs) do
    Repo.transact_with(fn ->
      with {:ok, unit} <- insert_unit(creator, attrs) do
        # act_attrs = %{verb: "created", is_local: true},
        # {:ok, activity} <- Activities.create(creator, unit, act_attrs), #FIXME
        # :ok <- publish(creator, unit, activity, :created) do
        {:ok, unit}
      end
    end)
  end

  @spec create(User.t(), context :: any, attrs :: map) ::
          {:ok, Unit.t()} | {:error, Changeset.t()}
  def create(%User{} = creator, context, attrs) when is_map(attrs) do
    Repo.transact_with(fn ->
      with {:ok, unit} <- insert_unit(creator, context, attrs) do
        # act_attrs = %{verb: "created", is_local: true},
        # {:ok, activity} <- Activities.create(creator, unit, act_attrs), #FIXME
        # :ok <- publish(creator, context, unit, activity, :created) do
        {:ok, unit}
      end
    end)
  end

  defp insert_unit(creator, attrs) do
    Repo.insert(Measurement.Unit.create_changeset(creator, attrs))
  end

  defp insert_unit(creator, context, attrs) do
    Repo.insert(Measurement.Unit.create_changeset(creator, context, attrs))
  end

  # defp publish(creator, unit, activity, :created) do
  #   feeds = [
  #     CommonsPub.Feeds.outbox_id(creator),
  #     Feeds.instance_outbox_id()
  #   ]

  #   with :ok <- FeedActivities.publish(activity, feeds) do
  #     ap_publish(unit.id, creator.id)
  #   end
  # end

  # defp publish(creator, context, unit, activity, :created) do
  #   feeds = [
  #     context.outbox_id,
  #     CommonsPub.Feeds.outbox_id(creator),
  #     Feeds.instance_outbox_id()
  #   ]

  #   with :ok <- FeedActivities.publish(activity, feeds) do
  #     ap_publish(unit.id, creator.id)
  #   end
  # end

  # defp publish(unit, :updated) do
  #   # TODO: wrong if edited by admin
  #   ap_publish(unit.id, unit.creator_id)
  # end

  # defp publish(unit, :deleted) do
  #   # TODO: wrong if edited by admin
  #   ap_publish(unit.id, unit.creator_id)
  # end

  # defp ap_publish(context_id, user_id) do
  #   CommonsPub.FeedPublisher.publish(%{
  #     "context_id" => context_id,
  #     "user_id" => user_id
  #   })
  # end

  # defp ap_publish(_, _, _), do: :ok

  # TODO: take the user who is performing the update
  @spec update(%Unit{}, attrs :: map) :: {:ok, Measurement.Unit.t()} | {:error, Changeset.t()}
  def update(%Unit{} = unit, attrs) do
    Repo.update(Measurement.Unit.update_changeset(unit, attrs))
  end

  def soft_delete(%Unit{} = unit) do
    Repo.transact_with(fn ->
      with {:ok, unit} <- Common.Deletion.soft_delete(unit) do
        # :ok <- publish(unit, :deleted) do
        {:ok, unit}
      end
    end)
  end
end
