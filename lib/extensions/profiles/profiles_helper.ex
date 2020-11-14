defmodule CommonsPub.Profiles.Web.ProfilesHelper do
  # alias CommonsPub.{Repo}
  alias CommonsPub.Web.GraphQL.UsersResolver
  import CommonsPub.Utils.Web.CommonHelper

  def fetch_users_from_context(user) do
    # IO.inspect(user.context_id, label: "ContextId")
    {:ok, pointer} = CommonsPub.Meta.Pointers.one(id: user.context_id)
    # IO.inspect(pointer, label: "POINTER:")
    CommonsPub.Meta.Pointers.follow!(pointer) |> prepare(%{icon: true, character: true})
  end

  def fetch_users_from_creator(user) do
    # IO.inspect(user.context_id, label: "ContextId")
    {:ok, pointer} = CommonsPub.Meta.Pointers.one(id: user.creator_id)
    # IO.inspect(pointer, label: "POINTER:")
    CommonsPub.Meta.Pointers.follow!(pointer) |> prepare(%{icon: true, character: true})
  end

  def is_followed_by(current_user, profile_id) when not is_nil(current_user) do
    is_followed_by(
      CommonsPub.Web.GraphQL.FollowsResolver.fetch_my_follow_edge(current_user, nil, profile_id)
    )
  end

  def is_followed_by(_, _) do
    false
  end

  defp is_followed_by(%{data: data}) when data == %{} do
    false
  end

  defp is_followed_by(_map) do
    true
  end

  def unfollow(current_user, followed_id) do
    {:ok, follow} =
      CommonsPub.Follows.one(deleted: false, creator: current_user.id, context: followed_id)

    CommonsPub.Follows.soft_delete(current_user, follow)
  end

  def prepare(%{username: _username} = profile) do
    IO.inspect("profile already prepared")
    profile
  end

  def prepare(profile) do
    prepare_website(prepare_username(profile))
  end

  def prepare(profile, %{icon: _} = preload) do
    prepare(profile, preload, 50)
  end

  def prepare(profile, %{image: _} = preload) do
    prepare(profile, preload, 700)
  end

  def prepare(profile, %{is_followed_by: current_user} = preload) do
    followed_bool = is_followed_by(current_user, profile.id)

    prepare(
      profile
      |> Map.merge(%{is_followed: followed_bool}),
      Map.delete(preload, :is_followed_by)
    )
  end

  def prepare(profile, preload) do
    profile =
      if(Map.has_key?(profile, :__struct__)) do
        Enum.reduce(preload, profile, fn field, profile ->
          {preload, included} = field

          if(included) do
            Map.merge(profile, CommonsPub.Repo.maybe_preload(profile, preload))
          else
            profile
          end
        end)
      else
        profile
      end

    prepare(profile)
  end

  def prepare_username(profile) do
    profile
    |> Map.merge(%{
      username:
        map_get(profile, :username, nil) || CommonsPub.Characters.display_username(profile)
    })
    |> Map.merge(%{display_username: CommonsPub.Characters.display_username(profile, true)})
  end

  def prepare_website(profile) do
    if(Map.has_key?(profile, :website) and !is_nil(profile.website)) do
      url = CommonsPub.Utils.File.ensure_valid_url(profile.website)

      # IO.inspect(url)

      profile
      |> Map.merge(%{website: url, website_friendly: URI.parse(url).host})
    else
      profile
    end
  end

  def prepare(profile, %{icon: _} = preload, icon_size) do
    profile =
      if(Map.has_key?(profile, "icon_url")) do
        profile
      else
        profile
        |> Map.merge(%{icon_url: icon(profile, "retro", icon_size)})
      end

    prepare(
      profile,
      Map.delete(preload, :icon)
    )
  end

  def prepare(profile, %{image: _} = preload, image_size) do
    profile =
      if(Map.has_key?(profile, "image_url")) do
        profile
      else
        profile
        |> Map.merge(%{image_url: image(profile, "identicon", image_size)})
      end

    prepare(
      profile,
      Map.delete(preload, :image)
    )
  end

  def user_load(socket, params) do
    user_load(socket, params, %{image: true, icon: true, character: true}, 150)
  end

  def user_load(socket, page_params, preload) do
    user_load(socket, page_params, preload, 50)
  end

  def user_load(socket, page_params, preload, icon_width) do
    # IO.inspect(socket)

    username = e(page_params, "username", nil)

    # load requested user
    {:ok, user} =
      if(username == socket.assigns.current_user or is_nil(username)) do
        # fallback to current user
        if(!is_nil(socket.assigns.current_user)) do
          {:ok, socket.assigns.current_user}
        else
          {:ok, %{}}
        end
      else
        {:ok, user} =
          UsersResolver.user(%{username: username}, %{
            context: %{current_user: socket.assigns.current_user}
          })

        # is_followed_by(socket.assigns.current_user, user.id)

        {:ok, user}
      end

    prepare(user, preload, icon_width)
  end
end
