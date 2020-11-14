# SPDX-License-Identifier: AGPL-3.0-only
defmodule Organisation.Organisations do
  alias CommonsPub.{
    # Activities,
    # Actors,
    # Common,
    # Feeds,
    # Follows,
    Repo
  }

  alias CommonsPub.GraphQL.{Fields, Page}
  alias CommonsPub.Contexts
  alias Organisation
  alias Organisation.Queries
  # alias CommonsPub.Feeds.FeedActivities
  alias CommonsPub.Users.User
  # alias CommonsPub.Workers.APPublishWorker
  alias CommonsPub.Characters
  alias CommonsPub.Profiles

  @facet_name "Organisation"

  def cursor(), do: &[&1.id]
  def test_cursor(), do: &[&1["id"]]

  @doc """
  Retrieves a single organisation by arbitrary filters.
  Used by:
  * GraphQL Item queries
  * ActivityPub integration
  * Various parts of the codebase that need to query for organisations (inc. tests)
  """
  def one(filters), do: Repo.single(Queries.query(Organisation, filters))

  @doc """
  Retrieves a list of organisations by arbitrary filters.
  Used by:
  * Various parts of the codebase that need to query for organisations (inc. tests)
  """
  def many(filters \\ []), do: {:ok, Repo.all(Queries.query(Organisation, filters))}

  def fields(group_fn, filters \\ [])
      when is_function(group_fn, 1) do
    {:ok, fields} = many(filters)
    {:ok, Fields.new(fields, group_fn)}
  end

  @doc """
  Retrieves an Page of organisations according to various filters

  Used by:
  * GraphQL resolver single-parent resolution
  """
  def page(cursor_fn, page_opts, base_filters \\ [], data_filters \\ [], count_filters \\ [])

  def page(cursor_fn, %{} = page_opts, base_filters, data_filters, count_filters) do
    base_q = Queries.query(Organisation, base_filters)
    data_q = Queries.filter(base_q, data_filters)
    count_q = Queries.filter(base_q, count_filters)

    with {:ok, [data, counts]} <- Repo.transact_many(all: data_q, count: count_q) do
      {:ok, Page.new(data, counts, cursor_fn, page_opts)}
    end
  end

  @doc """
  Retrieves an Pages of organisations according to various filters

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
      Organisation,
      cursor_fn,
      group_fn,
      page_opts,
      base_filters,
      data_filters,
      count_filters
    )
  end

  ## mutations

  @spec create(User.t(), context :: any, attrs :: map) ::
          {:ok, Organisation.t()} | {:error, Changeset.t()}
  def create(%User{} = creator, context, attrs) when is_map(attrs) do
    Repo.transact_with(fn ->
      attrs = Map.put(attrs, :facet, @facet_name)

      #  {:ok, character} <- Characters.thing_link(organisation, character)
      with {:ok, organisation} <- insert_organisation(creator, attrs, context),
           {:ok, attrs} <- attrs_with_organisation(attrs, organisation),
           {:ok, profile} <- Profiles.create(creator, attrs),
           {:ok, character} <- Characters.create(creator, attrs, organisation) do
        {:ok, %{organisation | character: character, profile: profile}}
      end
    end)
  end

  @spec create(User.t(), attrs :: map) :: {:ok, Organisation.t()} | {:error, Changeset.t()}
  def create(%User{} = creator, attrs) when is_map(attrs) do
    Repo.transact_with(fn ->
      attrs = Map.put(attrs, :facet, @facet_name)

      # {:ok, character} <- Characters.thing_link(organisation, character)
      with {:ok, organisation} <- insert_organisation(creator, attrs),
           {:ok, attrs} <- attrs_with_organisation(attrs, organisation),
           {:ok, profile} <- Profiles.create(creator, attrs),
           {:ok, character} <- Characters.create(creator, attrs, organisation) do
        {:ok, %{organisation | character: character, profile: profile}}
      end
    end)
  end

  defp attrs_with_organisation(attrs, organisation) do
    attrs = Map.put(attrs, :id, organisation.id)
    # IO.inspect(attrs)
    {:ok, attrs}
  end

  defp insert_organisation(creator, attrs, context) do
    cs = Organisation.create_changeset(creator, attrs, context)
    with {:ok, organisation} <- Repo.insert(cs), do: {:ok, organisation}
  end

  defp insert_organisation(creator, attrs) do
    # IO.inspect(attrs)
    cs = Organisation.create_changeset(creator, attrs)
    with {:ok, organisation} <- Repo.insert(cs), do: {:ok, organisation}
  end

  # TODO: take the user who is performing the update
  @spec update(User.t(), Organisation.t(), attrs :: map) ::
          {:ok, Organisation.t()} | {:error, Changeset.t()}
  def update(%User{} = user, %Organisation{} = organisation, attrs) do
    Repo.transact_with(fn ->
      with {:ok, organisation} <- Repo.update(Organisation.update_changeset(organisation, attrs)),
           # update linked character too
           {:ok, profile} <- Profiles.update(user, organisation.profile, attrs),
           {:ok, character} <- Characters.update(user, organisation.character, attrs) do
        {:ok, %{organisation | character: character, profile: profile}}
      end
    end)
  end
end
