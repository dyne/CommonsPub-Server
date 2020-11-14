defmodule CommonsPub.Collections.Web.CollectionsHelper do
  # alias CommonsPub.{
  #   Repo
  # }

  alias CommonsPub.Web.GraphQL.{
    UsersResolver,
    CollectionsResolver
  }

  import CommonsPub.Utils.Web.CommonHelper
  alias CommonsPub.Profiles.Web.ProfilesHelper

  def collection_load(socket, page_params, nil) do
    collection_load(socket, page_params, %{
      icon: false,
      character: true,
      image: false,
      context: true,
      is_followed_by: nil
    })
  end

  def collection_load(socket, page_params, %CommonsPub.Users.User{} = current_user) do
    collection_load(socket, page_params, %{
      icon: false,
      character: true,
      image: false,
      context: true,
      is_followed_by: current_user
    })
  end

  def collection_load(_socket, page_params, %{} = preload) do
    username = e(page_params, "username", nil)

    {:ok, collection} =
      if(!is_nil(username)) do
        CollectionsResolver.collection(%{username: username}, %{})
      else
        {:ok, %{}}
      end

    ProfilesHelper.prepare(collection, preload, 150)
  end

  def user_collections(for_user, current_user) do
    user_collections(for_user, current_user, 10)
  end

  def user_collections(for_user, current_user, limit) do
    user_collections(for_user, current_user, limit, [])
  end

  def user_collections(for_user, current_user, limit, page_after) do
    collections_from_follows(user_collections_follows(for_user, current_user, limit, page_after))
  end

  def user_collections_follows(for_user, current_user) do
    user_collections_follows(for_user, current_user, 5)
  end

  def user_collections_follows(for_user, current_user, limit) do
    user_collections_follows(for_user, current_user, limit, [])
  end

  def user_collections_follows(for_user, current_user, limit, page_after) do
    {:ok, follows} =
      UsersResolver.collection_follows_edge(
        for_user,
        %{limit: limit, after: page_after},
        %{context: %{current_user: current_user}}
      )

    follows
  end

  def collections_from_follows(%{edges: edges}) when length(edges) > 0 do
    # FIXME: collections should be joined to edges rather than queried seperately

    ids = Enum.map(edges, & &1.context_id)

    collections = CommonsPub.Contexts.contexts_fetch!(ids)

    collections =
      if(collections) do
        Enum.map(
          collections,
          &ProfilesHelper.prepare(&1, %{icon: true, image: true, character: true})
        )
      end

    collections
  end

  def collections_from_follows(_) do
    []
  end
end
