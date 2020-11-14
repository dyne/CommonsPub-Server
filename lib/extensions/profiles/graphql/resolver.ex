# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Profiles.GraphQL.Resolver do
  alias CommonsPub.{
    # Activities,
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
    # ResolvePage,
    # ResolvePages,
    ResolveRootPage
  }

  alias CommonsPub.Profiles

  alias CommonsPub.Resources.Resource
  # alias CommonsPub.Common.Enums
  alias Pointers

  ## resolvers

  def profile(%{profile: profile}, _, _info) do
    {:ok, profile}
  end

  def profile(%{profile_id: id}, _, info) do
    profile(%{profile_id: id}, info)
  end

  def profile(%{profile_id: id}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_profile,
      context: id,
      info: info
    })
  end

  def profile(%{id: id}, info) do
    profile(%{profile_id: id}, info)
  end

  # def profile(opts, _, info) do
  #   {:ok, nil}
  # end

  def profiles(page_opts, info) do
    ResolveRootPage.run(%ResolveRootPage{
      module: __MODULE__,
      fetcher: :fetch_profiles,
      page_opts: page_opts,
      info: info,
      # popularity
      cursor_validators: [&(is_integer(&1) and &1 >= 0), &Ecto.ULID.cast/1]
    })
  end

  ## fetchers

  def fetch_profile(info, id) do
    Profiles.one(
      user: GraphQL.current_user(info),
      id: id
      # preload: :actor
    )
  end

  def fetch_profiles(page_opts, info) do
    FetchPage.run(%FetchPage{
      queries: CommonsPub.Profiles.Queries,
      query: CommonsPub.Profiles.Profile,
      # cursor_fn: Profiles.cursor(:followers),
      page_opts: page_opts,
      base_filters: [user: GraphQL.current_user(info)]
      # data_filters: [page: [desc: [followers: page_opts]]],
    })
  end

  # def profileistic_edge(%CommonsPub.Profiles.Profile{profileistic_id: id}, _, info), do: CommonsPub.Web.GraphQL.CommonResolver.context_edge(%{context_id: id}, nil, info)

  # def resource_count_edge(%CommonsPub.Profiles.Profile{id: id}, _, info) do
  #   Flow.fields(__MODULE__, :fetch_resource_count_edge, id, info, default: 0)
  # end

  def fetch_resource_count_edge(_, ids) do
    FetchFields.run(%FetchFields{
      queries: Resources.Queries,
      query: Resource,
      group_fn: &elem(&1, 0),
      map_fn: &elem(&1, 1),
      filters: [profile_id: ids, group_count: :profile_id]
    })
  end

  ## finally the mutations...

  def create_profile(%{profile: attrs}, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info) do
        attrs = Map.merge(attrs, %{is_public: true})
        Profiles.create(user, attrs)
      end
    end)
  end

  def add_profile_to(%{context_id: id}, info) do
    Repo.transact_with(fn ->
      with {:ok, me} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, pointer} <- CommonsPub.Meta.Pointers.one(id: id) do
        Profiles.add_profile_to(me, pointer)
      end
    end)
  end

  def update_profile(%{profile: changes, profile_id: id}, info) do
    Repo.transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, profile} <- profile(%{profile_id: id}, info) do
        cond do
          user.local_user.is_instance_admin ->
            Profiles.update(user, profile, changes)

          profile.creator_id == user.id ->
            Profiles.update(user, profile, changes)

          true ->
            GraphQL.not_permitted("update")
        end
      end
    end)
  end

  # defp validate_profile_context(pointer) do
  #   if Pointers.table(pointer).schema in valid_contexts() do
  #     :ok
  #   else
  #     GraphQL.not_permitted()
  #   end
  # end

  # defp valid_contexts do
  #   Keyword.fetch!(CommonsPub.Config.get(Profiles), :valid_contexts)
  # end

  # def creator_edge(%{profile: %{creator_id: id}}, _, info) do
  #   CommonsPub.Characters.GraphQL.Resolver.creator_edge(%{creator_id: id}, nil, info)
  # end

  def creator_edge(%{profile: %{creator_id: id}}, _, info),
    do: CommonsPub.Web.GraphQL.UsersResolver.creator_edge(%{creator_id: id}, nil, info)

  def is_public_edge(%{profile: profile}, _, _), do: {:ok, not is_nil(profile.published_at)}
  def is_disabled_edge(%{profile: profile}, _, _), do: {:ok, not is_nil(profile.disabled_at)}
  def is_hidden_edge(%{profile: profile}, _, _), do: {:ok, not is_nil(profile.hidden_at)}
  def is_deleted_edge(%{profile: profile}, _, _), do: {:ok, not is_nil(profile.deleted_at)}

  def my_like_edge(%{profile_id: id}, page_opts, info),
    do: CommonsPub.Web.GraphQL.LikesResolver.my_like_edge(%{id: id}, page_opts, info)

  def likers_edge(%{profile_id: id}, page_opts, info),
    do: CommonsPub.Web.GraphQL.LikesResolver.likers_edge(%{id: id}, page_opts, info)

  def liker_count_edge(%{profile_id: id}, page_opts, info),
    do: CommonsPub.Web.GraphQL.LikesResolver.liker_count_edge(%{id: id}, page_opts, info)

  def my_flag_edge(%{profile_id: id}, page_opts, info),
    do: CommonsPub.Web.GraphQL.FlagsResolver.my_flag_edge(%{id: id}, page_opts, info)

  def flags_edge(%{profile_id: id}, page_opts, info),
    do: CommonsPub.Web.GraphQL.FlagsResolver.flags_edge(%{id: id}, page_opts, info)

  def icon_content_edge(%{profile: %{icon_id: id}}, _, info),
    do: CommonsPub.Web.GraphQL.UploadResolver.icon_content_edge(%{icon_id: id}, nil, info)

  def image_content_edge(%{profile: %{image_id: id}}, _, info),
    do: CommonsPub.Web.GraphQL.UploadResolver.image_content_edge(%{image_id: id}, nil, info)
end
