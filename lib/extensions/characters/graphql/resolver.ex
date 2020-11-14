# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Characters.GraphQL.Resolver do
  alias CommonsPub.{
    Activities,
    GraphQL,
    Repo,
    Resources
  }

  alias CommonsPub.GraphQL.{
    # Flow,
    FetchFields,
    FetchPage,
    # FetchPages,
    ResolveField,
    ResolvePage,
    # ResolvePages,
    ResolveRootPage
  }

  alias CommonsPub.Characters
  alias CommonsPub.Characters.Character

  alias CommonsPub.Resources.Resource
  # alias CommonsPub.Common.Enums
  alias Pointers

  ## resolvers

  # def character(%{character: character} = obj, _, _info) do
  #   {:ok, Repo.preload(character, :character)}
  # end

  def character(%{character_id: id}, _, info) do
    character(%{character_id: id}, info)
  end

  def character(%{character_id: id}, info) do
    # IO.inspect(id)
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_character,
      context: id,
      info: info
    })
  end

  def characters(page_opts, info) do
    ResolveRootPage.run(%ResolveRootPage{
      module: __MODULE__,
      fetcher: :fetch_characters,
      page_opts: page_opts,
      info: info,
      # popularity
      cursor_validators: [&(is_integer(&1) and &1 >= 0), &Ecto.ULID.cast/1]
    })
  end

  ## fetchers

  def fetch_character(info, id) do
    Characters.one(
      user: GraphQL.current_user(info),
      id: id,
      preload: :character
    )
  end

  def fetch_characters(page_opts, info) do
    FetchPage.run(%FetchPage{
      queries: CommonsPub.Characters.Queries,
      query: CommonsPub.Characters.Character,
      cursor_fn: Characters.cursor(:followers),
      page_opts: page_opts,
      base_filters: [user: GraphQL.current_user(info)],
      data_filters: [page: [desc: [followers: page_opts]]]
    })
  end

  # def characteristic_edge(%CommonsPub.Characters.Character{characteristic_id: id}, _, info), do: CommonsPub.Web.GraphQL.CommonResolver.context_edge(%{context_id: id}, nil, info)

  # def resource_count_edge(%CommonsPub.Characters.Character{id: id}, _, info) do
  #   Flow.fields(__MODULE__, :fetch_resource_count_edge, id, info, default: 0)
  # end

  def fetch_resource_count_edge(_, ids) do
    FetchFields.run(%FetchFields{
      queries: Resources.Queries,
      query: Resource,
      group_fn: &elem(&1, 0),
      map_fn: &elem(&1, 1),
      filters: [character_id: ids, group_count: :character_id]
    })
  end

  def last_activity_edge(_, _, _info) do
    {:ok, DateTime.utc_now()}
  end

  def outbox_edge(%{character: %{outbox_id: id}}, page_opts, info),
    do: outbox_edge(%{outbox_id: id}, page_opts, info)

  def outbox_edge(%{character: _character} = obj, page_opts, info) do
    outbox_edge(Characters.obj_character(obj), page_opts, info)
  end

  def outbox_edge(%{outbox_id: id}, page_opts, info) do
    with :ok <- GraphQL.not_in_list_or_empty_page(info) do
      ResolvePage.run(%ResolvePage{
        module: __MODULE__,
        fetcher: :fetch_outbox_edge,
        context: id,
        page_opts: page_opts,
        info: info
      })
    end
  end

  def fetch_outbox_edge(page_opts, _info, id) do
    tables = default_outbox_query_contexts()

    FetchPage.run(%FetchPage{
      queries: Activities.Queries,
      query: Activities.Activity,
      page_opts: page_opts,
      base_filters: [deleted: false, feed_timeline: id, table: tables],
      data_filters: [page: [desc: [created: page_opts]], preload: :context]
    })
  end

  defp default_outbox_query_contexts() do
    CommonsPub.Config.get!(CommonsPub.Characters)
    |> Keyword.fetch!(:default_outbox_query_contexts)
  end

  ## finally the mutations...

  def create_character(%{character: attrs}, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info) do
        attrs = Map.merge(attrs, %{is_public: true})
        Characters.create(user, attrs)
      end
    end)
  end

  def characterise(%{context_id: id}, info) do
    Repo.transact_with(fn ->
      with {:ok, me} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, pointer} <- CommonsPub.Meta.Pointers.one(id: id) do
        Characters.characterise(me, pointer)
      end
    end)
  end

  def update_character(%{character: changes, character_id: id}, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, character} <- character(%{character_id: id}, info) do
        cond do
          user.local_user.is_instance_admin ->
            Characters.update(user, character, changes)

          character.creator_id == user.id ->
            Characters.update(user, character, changes)

          true ->
            GraphQL.not_permitted("update")
        end
      end
    end)
  end

  # def delete(%{character_id: id}, info) do
  #   # Repo.transact_with(fn ->
  #   #   with {:ok, user} <- GraphQL.current_user(info),
  #   #        {:ok, character} <- Users.fetch_actor(user),
  #   #        {:ok, character} <- Characters.fetch(id) do
  #   #     character = Repo.preload(character, :community)
  #   # 	permitted =
  #   # 	  user.is_instance_admin or
  #   #       character.creator_id == character.id or
  #   #       character.community.creator_id == character.id
  #   # 	if permitted do
  #   # 	  with {:ok, _} <- Characters.soft_delete(character), do: {:ok, true}
  #   # 	else
  #   # 	  GraphQL.not_permitted()
  #   #     end
  #   #   end
  #   # end)
  #   # |> GraphQL.response(info)
  #   {:ok, true}
  #   |> GraphQL.response(info)
  # end

  # defp validate_character_context(pointer) do
  #   if Pointers.table!(pointer).schema in valid_contexts() do
  #     :ok
  #   else
  #     GraphQL.not_permitted()
  #   end
  # end

  # defp valid_contexts do
  #   Keyword.fetch!(CommonsPub.Config.get(Characters), :valid_contexts)
  # end

  # def creator_edge(%{character: %{creator_id: id}}, _, info) do
  #   CommonsPub.Characters.GraphQL.Resolver.creator_edge(%{creator_id: id}, nil, info)
  # end

  @doc "Returns the canonical url for a character"
  def canonical_url_edge(obj, _, _),
    do: {:ok, CommonsPub.ActivityPub.Utils.get_actor_canonical_url(obj)}

  @doc "Is this character local to this instance?"
  def is_local_edge(obj, _, _), do: {:ok, CommonsPub.ActivityPub.Utils.check_local(obj)}

  @doc "Returns the preferred_username "
  def preferred_username_edge(obj, _, _),
    do: {:ok, CommonsPub.ActivityPub.Utils.get_actor_username(obj)}

  def display_username_edge(obj, _, _) do
    {:ok, Characters.display_username(obj)}
  end

  def creator_edge(%{character: %{creator_id: id}}, _, info),
    do: CommonsPub.Web.GraphQL.UsersResolver.creator_edge(%{creator_id: id}, nil, info)

  def context_edge(%{character: %{context_id: id}}, _, info),
    do: CommonsPub.Web.GraphQL.CommonResolver.context_edge(%{context_id: id}, nil, info)

  def is_public_edge(%{character: character}, _, _), do: {:ok, not is_nil(character.published_at)}

  def is_disabled_edge(%{character: character}, _, _),
    do: {:ok, not is_nil(character.disabled_at)}

  def is_hidden_edge(%{character: character}, _, _), do: {:ok, not is_nil(character.hidden_at)}
  def is_deleted_edge(%{character: character}, _, _), do: {:ok, not is_nil(character.deleted_at)}

  def follower_count_edge(%{character_id: id}, page_opts, info),
    do: CommonsPub.Web.GraphQL.FollowsResolver.follower_count_edge(%{id: id}, page_opts, info)

  def my_follow_edge(%{character_id: id}, page_opts, info),
    do: CommonsPub.Web.GraphQL.FollowsResolver.my_follow_edge(%{id: id}, page_opts, info)

  def followers_edge(%{character_id: id}, page_opts, info),
    do: CommonsPub.Web.GraphQL.FollowsResolver.followers_edge(%{id: id}, page_opts, info)

  def my_like_edge(%{character_id: id}, page_opts, info),
    do: CommonsPub.Web.GraphQL.LikesResolver.my_like_edge(%{id: id}, page_opts, info)

  def likers_edge(%{character_id: id}, page_opts, info),
    do: CommonsPub.Web.GraphQL.LikesResolver.likers_edge(%{id: id}, page_opts, info)

  def liker_count_edge(%{character_id: id}, page_opts, info),
    do: CommonsPub.Web.GraphQL.LikesResolver.liker_count_edge(%{id: id}, page_opts, info)

  def my_flag_edge(%{character_id: id}, page_opts, info),
    do: CommonsPub.Web.GraphQL.FlagsResolver.my_flag_edge(%{id: id}, page_opts, info)

  def flags_edge(%{character_id: id}, page_opts, info),
    do: CommonsPub.Web.GraphQL.FlagsResolver.flags_edge(%{id: id}, page_opts, info)

  def icon_content_edge(%{character: %{icon_id: id}}, _, info),
    do: CommonsPub.Web.GraphQL.UploadResolver.icon_content_edge(%{icon_id: id}, nil, info)

  def image_content_edge(%{character: %{image_id: id}}, _, info),
    do: CommonsPub.Web.GraphQL.UploadResolver.image_content_edge(%{image_id: id}, nil, info)

  def threads_edge(%{character_id: id}, %{} = page_opts, info),
    do: CommonsPub.Web.GraphQL.ThreadsResolver.threads_edge(%{id: id}, page_opts, info)
end
