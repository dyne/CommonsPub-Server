# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.CommonResolver do
  alias Ecto.ULID
  alias CommonsPub.GraphQL

  alias CommonsPub.GraphQL.{
    Fields,
    # Pages,
    # FetchFields,
    # FetchPage,
    ResolveFields,
    ResolvePages
  }

  # alias CommonsPub.Likes.Like
  # alias CommonsPub.Follows.Follow
  # alias CommonsPub.Flags.Flag
  # alias CommonsPub.Threads.Comment
  alias CommonsPub.Meta.Pointers
  # alias CommonsPub.Common

  def resolve_context_type(%CommonsPub.Communities.Community{}, _), do: :community
  def resolve_context_type(%CommonsPub.Collections.Collection{}, _), do: :collection
  def resolve_context_type(%Organisation{}, _), do: :organisation
  def resolve_context_type(%{}, _), do: :community

  def created_at_edge(%{id: id}, _, _), do: ULID.timestamp(id)

  def context_edge(%{context_id: id}, _, info) do
    ResolveFields.run(%ResolveFields{
      module: __MODULE__,
      fetcher: :fetch_context_edge,
      context: id,
      info: info
    })
  end
  def context_edge(_, _, _info) do
    {:ok, nil}
  end

  def fetch_context_edge(_, ids) do
    {:ok, ptrs} = Pointers.many(id: List.flatten(ids))
    Fields.new(Pointers.follow!(ptrs), &Map.get(&1, :id))
  end

  def context_edges(%{context_ids: ids}, %{} = page_opts, info) do
    ResolvePages.run(%ResolvePages{
      module: __MODULE__,
      fetcher: :fetch_context_edges,
      context: ids,
      page_opts: page_opts,
      info: info
    })
  end

  def fetch_context_edges(_page_opts, _info, pointers)
      when is_list(pointers) and length(pointers) > 0 and is_struct(hd(pointers)) do
    # means we're already being passed pointers? instead of ids
    follow_context_edges(pointers)
  end

  def fetch_context_edges(_page_opts, _info, ids) do
    flattened_ids = List.flatten(ids)
    {:ok, pointers} = Pointers.many(id: flattened_ids)
    follow_context_edges(pointers)
  end

  def follow_context_edges(pointers) do
    contexts = Pointers.follow!(pointers)
    {:ok, contexts}
  end

  # def loaded_context(%Community{}=community), do: Repo.preload(community, :character)
  # def loaded_context(%Collection{}=collection), do: Repo.preload(collection, :character)
  # def loaded_context(%User{}=user), do: Repo.preload(user, :character)
  # def loaded_context(other), do: other

  # def tag(%{tag_id: id}, info) do
  #   {:ok, Simulation.tag()}
  #   |> GraphQL.response(info)
  # end
  # def tag_category(%{tag_category_id: id}, info) do
  #   {:ok, Simulation.tag_category()}
  #   |> GraphQL.response(info)
  # end
  # def tag_category(_, _, info) do
  #   {:ok, Simulation.tag_category()}
  #   |> GraphQL.response(info)
  # end
  # def tagging(%{tagging_id: id}, info) do
  #   {:ok, Simulation.tagging()}
  #   |> GraphQL.response(info)
  # end
  # def taggings(_, _, info) do
  #   {:ok, Simulation.long_edge_list(&Simulation.tagging/0)}
  #   |> GraphQL.response(info)
  # end

  def is_public_edge(parent, _, _), do: {:ok, not is_nil(parent.published_at)}
  def is_local_edge(%{is_local: is_local}, _, _), do: {:ok, is_local}
  def is_disabled_edge(parent, _, _), do: {:ok, not is_nil(parent.disabled_at)}
  def is_hidden_edge(parent, _, _), do: {:ok, not is_nil(parent.hidden_at)}
  def is_deleted_edge(parent, _, _), do: {:ok, not is_nil(parent.deleted_at)}

  # def followed(%Follow{}=follow,_,info)

  def delete(%{context_id: id}, info) do
    with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
         {:ok, deleted} <- CommonsPub.Common.Deletion.trigger_soft_delete(id, user) do
      {:ok, deleted}
    else
      e ->
        IO.inspect(cannot_delete: e)
        GraphQL.not_permitted("delete")
    end
  end

  # def tag(_, _, info) do
  #   {:ok, Simulation.tag()}
  #   |> GraphQL.response(info)
  # end

  # def create_tagging(_, info) do
  #   {:ok, Simulation.tagging()}
  #   |> GraphQL.response(info)
  # end

  # def tags(parent, _, info) do
  #   {:ok, Simulation.long_edge_list(&Simulation.tagging/0)}
  #   |> GraphQL.response(info)
  # end
end
