# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Contexts do
  @doc "Helpers for working with contexts, and writing contexts that deal with graphql"

  alias CommonsPub.GraphQL.{Page, Pages}
  alias CommonsPub.Repo
  require Logger

  def run_context_function(
        object,
        fun,
        args \\ [],
        fallback_fun \\ &run_context_function_error/2
      )

  def run_context_function(object_type, fun, args, fallback_fun)
      when is_atom(object_type) and is_atom(fun) and is_list(args) and is_function(fallback_fun) do

    object_context_module =
      if Kernel.function_exported?(object_type, :context_module, 0) do
        apply(object_type, :context_module, [])
      else
        # fallback to directly using the module provided
        object_type
      end

    arity = length(args)

    if(Kernel.function_exported?(object_context_module, fun, arity)) do
      # IO.inspect(function_exists_in: object_context_module)

      try do
        apply(object_context_module, fun, args)
      rescue
        e in FunctionClauseError ->
          fallback_fun.(
            "#{Exception.format_banner(:error, e)}",
            args
          )
      end
    else
      fallback_fun.(
        "No function defined at #{object_context_module}.#{fun}/#{arity} (if you're providing a schema module as object_type, you may be missing a context_module/0 function that points to the related context module)",
        args
      )
    end
  end

  def run_context_function(%{__struct__: object_type} = _object, fun, args, fallback_fun) do
    run_context_function(object_type, fun, args, fallback_fun)
  end

  def run_context_function(object_type, fun, args, fallback_fun) when not is_list(args) do
    run_context_function(object_type, fun, [args], fallback_fun)
  end

  def run_context_function_error(error, args) do
    Logger.error("Error running context function: #{error}")
    IO.inspect(run_context_function: args)

    {:error, error}
  end

  def contexts_fetch!(ids) do
    with {:ok, ptrs} <-
           CommonsPub.Meta.Pointers.many(id: List.flatten(ids)) do
      CommonsPub.Meta.Pointers.follow!(ptrs)
    end
  end

  def context_fetch(id) do
    with {:ok, pointer} <- CommonsPub.Meta.Pointers.one(id: id) do
      CommonsPub.Meta.Pointers.follow!(pointer)
    end
  end

  def prepare_context(%{context: %{id: context_id}} = thing) when not is_nil(context_id) do
    # Pointer already loaded?
    context_follow(thing)
  end

  def prepare_context(%{context_id: context_id} = thing) when not is_nil(context_id) do
    CommonsPub.Repo.maybe_do_preload(thing, :context) |> context_follow()
  end

  def prepare_context(thing) do
    thing
  end

  defp context_follow(%{context: %Pointers.Pointer{} = pointer} = thing) do
    context = CommonsPub.Meta.Pointers.follow!(pointer)

    add_context_type(
      thing
      |> Map.merge(%{context: context})
    )
  end

  defp context_follow(%{context: %{id: context_id}} = thing) when not is_nil(context_id) do
    # IO.inspect("we already have a loaded object")
    add_context_type(thing)
  end

  defp context_follow(%{context_id: context_id} = thing) when not is_nil(context_id) do
    {:ok, pointer} = CommonsPub.Meta.Pointers.one(id: context_id)

    context_follow(
      thing
      |> Map.merge(%{context: pointer})
    )
  end

  defp context_follow(%{context_id: nil} = thing) do
    add_context_type(thing)
  end

  defp context_follow(thing) do
    thing
  end

  defp add_context_type(%{context_type: context_type} = thing) when not is_nil(context_type) do
    thing
  end

  defp add_context_type(%{context: context} = thing) do
    type = context_type(context)

    thing
    |> Map.merge(%{context_type: type})
  end

  defp add_context_type(thing) do
    thing
    |> Map.merge(%{context_type: nil})
  end

  def context_type(%{__struct__: name}) do
    name
    |> Module.split()
    |> Enum.at(-1)
    |> String.downcase()
  end

  def context_type(_) do
    nil
  end

  def page(
        queries,
        schema,
        cursor_fn,
        %{} = page_opts,
        base_filters,
        data_filters,
        count_filters
      )
      when is_atom(queries) and
             is_atom(schema) and
             is_function(cursor_fn, 1) and
             is_list(base_filters) and
             is_list(data_filters) and
             is_list(count_filters) do
    # queries_args = [schema, page_opts, base_filters, data_filters, count_filters]
    base_q = apply(queries, :query, [schema, base_filters])
    data_q = apply(queries, :filter, [base_q, data_filters])
    count_q = apply(queries, :filter, [base_q, count_filters])

    with {:ok, [data, counts]} <- Repo.transact_many(all: data_q, count: count_q) do
      {:ok, Page.new(data, counts, cursor_fn, page_opts)}
    end
  end

  def page_all(
        queries,
        schema,
        cursor_fn,
        %{} = page_opts,
        base_filters,
        data_filters,
        count_filters
      )
      when is_atom(queries) and
             is_atom(schema) and
             is_function(cursor_fn, 1) and
             is_list(base_filters) and
             is_list(data_filters) and
             is_list(count_filters) do
    queries_args = [schema, page_opts, base_filters, data_filters, count_filters]
    {data_q, count_q} = apply(queries, :queries, queries_args)

    with {:ok, [data, counts]} <- Repo.transact_many(all: data_q, all: count_q) do
      {:ok, Page.new(data, counts, cursor_fn, page_opts)}
    end
  end

  def pages(
        queries,
        schema,
        cursor_fn,
        group_fn,
        page_opts,
        base_filters,
        data_filters,
        count_filters
      )
      when is_atom(queries) and
             is_atom(schema) and
             is_function(cursor_fn, 1) and
             is_function(group_fn, 1) and
             is_list(base_filters) and
             is_list(data_filters) and
             is_list(count_filters) do
    queries_args = [schema, page_opts, base_filters, data_filters, count_filters]
    {data_q, count_q} = apply(queries, :queries, queries_args)

    with {:ok, [data, counts]} <- Repo.transact_many(all: data_q, all: count_q) do
      {:ok, Pages.new(data, counts, cursor_fn, group_fn, page_opts)}
    end
  end

  # FIXME: make these config-driven and generic:
  # TODO: make them support no context or any context

  def context_feeds(obj) do
    # remove nils
    Enum.filter(context_feeds_list(obj), & &1)
  end

  defp context_feeds_list(%{context: %{character: %{inbox_id: inbox, outbox_id: outbox}}}),
    do: [inbox, outbox]

  defp context_feeds_list(%CommonsPub.Resources.Resource{} = r) do
    r = Repo.preload(r, collection: [:character, community: :character])

    [
      CommonsPub.Feeds.outbox_id(r.collection),
      CommonsPub.Feeds.outbox_id(Map.get(r.collection, :community))
    ]
  end

  defp context_feeds_list(%CommonsPub.Collections.Collection{} = c) do
    c = Repo.preload(c, [:character, context: :character])

    [
      CommonsPub.Feeds.outbox_id(c),
      CommonsPub.Feeds.outbox_id(Map.get(Map.get(c, :context, %{}), :character))
    ]
  end

  defp context_feeds_list(%CommonsPub.Communities.Community{} = c) do
    c = Repo.preload(c, :character, context: :character)

    [
      CommonsPub.Feeds.outbox_id(c),
      CommonsPub.Feeds.outbox_id(Map.get(Map.get(c, :context, %{}), :character))
    ]
  end

  defp context_feeds_list(%CommonsPub.Users.User{} = u) do
    u = Repo.preload(u, :character)
    [CommonsPub.Feeds.outbox_id(u), CommonsPub.Feeds.inbox_id(u)]
  end

  defp context_feeds_list(%{inbox_id: inbox, outbox_id: outbox}), do: [inbox, outbox]

  defp context_feeds_list(%{character: %{inbox_id: inbox, outbox_id: outbox}}),
    do: [inbox, outbox]

  defp context_feeds_list(_), do: []
end
