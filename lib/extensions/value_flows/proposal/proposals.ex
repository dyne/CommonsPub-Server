# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Proposal.Proposals do
  import CommonsPub.Common, only: [maybe_put: 3, attr_get_id: 2]

  alias CommonsPub.{Activities, Common, Feeds, Repo}
  alias CommonsPub.GraphQL.{Fields, Page}
  alias CommonsPub.Contexts
  alias CommonsPub.Feeds.FeedActivities
  alias CommonsPub.Users.User

  alias ValueFlows.Proposal
  alias ValueFlows.Proposal

  alias ValueFlows.Proposal.{
    ProposedTo,
    ProposedToQueries,
    ProposedIntentQueries,
    ProposedIntent,
    Queries
  }

  alias ValueFlows.Planning.Intent


  def cursor(), do: &[&1.id]
  def test_cursor(), do: &[&1["id"]]

  @doc """
  Retrieves a single one by arbitrary filters.
  Used by:
  * GraphQL Item queries
  * ActivityPub integration
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def one(filters), do: Repo.single(Queries.query(Proposal, filters))

  @spec one_proposed_intent(filters :: [any]) :: {:ok, ProposedIntent.t()} | {:error, term}
  def one_proposed_intent(filters),
    do: Repo.single(ProposedIntentQueries.query(ProposedIntent, filters))

  @spec one_proposed_to(filters :: [any]) :: {:ok, ProposedTo.t()} | {:error, term}
  def one_proposed_to(filters),
    do: Repo.single(ProposedToQueries.query(ProposedTo, filters))

  @doc """
  Retrieves a list of them by arbitrary filters.
  Used by:
  * Various parts of the codebase that need to query for this (inc. tests)
  """
  def many(filters \\ []), do: {:ok, Repo.all(Queries.query(Proposal, filters))}

  @spec many_proposed_intents(filters :: [any]) :: {:ok, [ProposedIntent.t()]} | {:error, term}
  def many_proposed_intents(filters \\ []),
    do: {:ok, Repo.all(ProposedIntentQueries.query(ProposedIntent, filters))}

  @spec many_proposed_to(filters :: [any]) :: {:ok, [ProposedTo]} | {:error, term}
  def many_proposed_to(filters \\ []),
    do: {:ok, Repo.all(ProposedToQueries.query(ProposedTo, filters))}

  def fields(group_fn, filters \\ [])
      when is_function(group_fn, 1) do
    {:ok, fields} = many(filters)
    {:ok, Fields.new(fields, group_fn)}
  end

  @doc """
  Retrieves an Page of proposals according to various filters

  Used by:
  * GraphQL resolver single-parent resolution
  """
  def page(cursor_fn, page_opts, base_filters \\ [], data_filters \\ [], count_filters \\ [])

  def page(cursor_fn, %{} = page_opts, base_filters, data_filters, count_filters) do
    base_q = Queries.query(Proposal, base_filters)
    data_q = Queries.filter(base_q, data_filters)
    count_q = Queries.filter(base_q, count_filters)

    with {:ok, [data, counts]} <- Repo.transact_many(all: data_q, count: count_q) do
      {:ok, Page.new(data, counts, cursor_fn, page_opts)}
    end
  end

  @doc """
  Retrieves an Pages of proposals according to various filters

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
      Proposal,
      cursor_fn,
      group_fn,
      page_opts,
      base_filters,
      data_filters,
      count_filters
    )
  end

  def preload_all(proposal) do
    Repo.preload(proposal, [
      :creator,
      :eligible_location,
      # pointers, not supported
      :context,
    ])
  end

  ## mutations

  @spec create(User.t(), attrs :: map) :: {:ok, Proposal.t()} | {:error, Changeset.t()}
  def create(%User{} = creator, attrs) when is_map(attrs) do
    attrs = prepare_attrs(attrs)

    Repo.transact_with(fn ->
      with {:ok, proposal} <- Repo.insert(Proposal.create_changeset(creator, attrs)),
           act_attrs = %{verb: "created", is_local: true},
           # FIXME
           {:ok, activity} <- Activities.create(creator, proposal, act_attrs),
           :ok <- index(proposal),
           :ok <- publish(creator, proposal, activity, :created) do
        {:ok, preload_all(proposal)}
      end
    end)
  end

  defp publish(creator, proposal, activity, :created) do
    feeds = [
      CommonsPub.Feeds.outbox_id(creator),
      Feeds.instance_outbox_id()
    ]

    with :ok <- FeedActivities.publish(activity, feeds) do
      ap_publish("create", proposal.id, creator.id)
    end
  end

  defp publish(proposal, :updated) do
    # TODO: wrong if edited by admin
    ap_publish("update", proposal.id, proposal.creator_id)
  end

  defp publish(proposal, :deleted) do
    # TODO: wrong if edited by admin
    ap_publish("delete", proposal.id, proposal.creator_id)
  end

  # FIXME
  defp ap_publish(verb, context_id, user_id) do
    CommonsPub.Workers.APPublishWorker.enqueue(verb, %{
      "context_id" => context_id,
      "user_id" => user_id
    })

    :ok
  end

  # TODO: take the user who is performing the update
  @spec update(%Proposal{}, attrs :: map) :: {:ok, Proposal.t()} | {:error, Changeset.t()}
  def update(%Proposal{} = proposal, attrs) do
    attrs = prepare_attrs(attrs)

    Repo.transact_with(fn ->
      with {:ok, proposal} <- Repo.update(Proposal.update_changeset(proposal, attrs)),
           :ok <- publish(proposal, :updated) do
        {:ok, proposal}
      end
    end)
  end

  def soft_delete(%Proposal{} = proposal) do
    Repo.transact_with(fn ->
      with {:ok, proposal} <- Common.Deletion.soft_delete(proposal),
           :ok <- publish(proposal, :deleted) do
        {:ok, proposal}
      end
    end)
  end

  @spec propose_intent(Proposal.t(), Intent.t(), map) ::
          {:ok, ProposedIntent.t()} | {:error, term}
  def propose_intent(%Proposal{} = proposal, %Intent{} = intent, attrs) do
    Repo.insert(ProposedIntent.changeset(proposal, intent, attrs))
  end

  @spec delete_proposed_intent(ProposedIntent.t()) :: {:ok, ProposedIntent.t()} | {:error, term}
  def delete_proposed_intent(%ProposedIntent{} = proposed_intent) do
    Common.Deletion.soft_delete(proposed_intent)
  end

  # if you like it then you should put a ring on it
  @spec propose_to(any, Proposal.t()) :: {:ok, ProposedTo.t()} | {:error, term}
  def propose_to(proposed_to, %Proposal{} = proposed) do
    Repo.insert(ProposedTo.changeset(proposed_to, proposed))
  end

  @spec delete_proposed_to(ProposedTo.t()) :: {:ok, ProposedTo.t()} | {:error, term}
  def delete_proposed_to(proposed_to), do: Common.Deletion.soft_delete(proposed_to)

  def indexing_object_format(obj) do
    # icon = CommonsPub.Uploads.remote_url_from_id(obj.icon_id)
    # image = CommonsPub.Uploads.remote_url_from_id(obj.image_id)

    %{
      "index_type" => "Proposal",
      "id" => obj.id,
      # "canonicalUrl" => obj.canonical_url,
      # "icon" => icon,
      "name" => obj.name,
      "summary" => Map.get(obj, :note),
      "published_at" => obj.published_at,
      "creator" => CommonsPub.Search.Indexer.format_creator(obj)
      # "index_instance" => URI.parse(obj.canonical_url).host, # home instance of object
    }
  end

  defp index(obj) do
    object = indexing_object_format(obj)

    CommonsPub.Search.Indexer.maybe_index_object(object)

    :ok
  end

  def ap_publish_activity(activity_name, proposal) do
    ValueFlows.Util.Federation.ap_publish_activity(activity_name, :proposal, proposal, 3, [:published_in])
  end

  defp prepare_attrs(attrs) do
    attrs
    |> maybe_put(:context_id,
      attrs |> Map.get(:in_scope_of) |> CommonsPub.Common.maybe(&List.first/1)
    )
    |> maybe_put(:eligible_location_id, attr_get_id(attrs, :eligible_location))
  end
end
