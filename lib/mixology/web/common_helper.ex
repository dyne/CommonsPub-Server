defmodule CommonsPub.Utils.Web.CommonHelper do
  import Phoenix.LiveView
  require Logger

  alias CommonsPub.Common

  alias CommonsPub.Users.Web.AccountHelper
  alias CommonsPub.Communities.Web.CommunitiesHelper

  alias CommonsPub.Web.GraphQL.LikesResolver

  def strlen(x) when is_nil(x), do: 0
  def strlen(%{} = obj) when obj == %{}, do: 0
  def strlen(%{}), do: 1
  def strlen(x) when is_binary(x), do: String.length(x)
  def strlen(x) when is_list(x), do: length(x)
  def strlen(x) when x > 0, do: 1
  # let's say that 0 is nothing
  def strlen(x) when x == 0, do: 0

  @doc "Returns a value, or a fallback if not present"
  def e(key, fallback) do
    if(strlen(key) > 0) do
      key
    else
      fallback
    end
  end

  @doc "Returns a value from a map, or a fallback if not present"
  def e(map, key, fallback) do
    if(is_map(map)) do
      # attempt using key as atom or string
      map_get(map, key, fallback)
    else
      fallback
    end
  end

  @doc "Returns a value from a nested map, or a fallback if not present"
  def e(map, key1, key2, fallback) do
    e(e(map, key1, %{}), key2, fallback)
  end

  def e(map, key1, key2, key3, fallback) do
    e(e(map, key1, key2, %{}), key3, fallback)
  end

  def e(map, key1, key2, key3, key4, fallback) do
    e(e(map, key1, key2, key3, %{}), key4, fallback)
  end

  def is_numeric(str) do
    case Float.parse(str) do
      {_num, ""} -> true
      _ -> false
    end
  end

  def to_number(str) do
    case Float.parse(str) do
      {num, ""} -> num
      _ -> 0
    end
  end

  def map_get(%Ecto.Association.NotLoaded{} = map, key, fallback) when is_atom(key) do
    Logger.error("Cannot get key `#{key}` from an unloaded map: #{inspect(map, pretty: true)}")
    fallback
  end

  def map_get(map, %Ecto.Association.NotLoaded{} = key, fallback) do
    Logger.warn("Cannot get from an unloaded key, trying to preload...")
    map_get(map, CommonsPub.Repo.maybe_preload(map, key), fallback)
  end

  @doc """
  Attempt geting a value out of a map by atom key, or try with string key, or return a fallback
  """
  def map_get(map, key, fallback) when is_atom(key) do
    Map.get(map, key, map_get(map, Atom.to_string(key), fallback))
  end

  @doc """
  Attempt geting a value out of a map by string key, or try with atom key (if it's an existing atom), or return a fallback
  """
  def map_get(map, key, fallback) when is_binary(key) do
    Map.get(
      map,
      key,
      Map.get(
        map,
        Recase.to_camel(key),
        Map.get(
          map,
          Common.maybe_str_to_atom(key),
          Map.get(
            map,
            Common.maybe_str_to_atom(Recase.to_camel(key)),
            fallback
          )
        )
      )
    )
  end

  def map_get(map, key, fallback) do
    Map.get(map, key, fallback)
  end

  def input_to_atoms(data) do
    data |> Map.new(fn {k, v} -> {Common.maybe_str_to_atom(k), v} end)
  end

  def random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.url_encode64() |> binary_part(0, length)
  end

  def r(html), do: Phoenix.HTML.raw(html)

  def markdown(html), do: r(markdown_to_html(html))

  def markdown_to_html(nil) do
    nil
  end

  def markdown_to_html(content) do
    content
    |> Earmark.as_html!()
    |> external_links()
  end

  # open outside links in a new tab
  def external_links(content) do
    Regex.replace(~r/(<a href=\"http.+\")>/U, content, "\\1 target=\"_blank\">")
  end

  def date_from_now(date) do
    with {:ok, from_now} <-
           Timex.shift(date, minutes: -3)
           |> Timex.format("{relative}", :relative) do
      from_now
    else
      _ ->
        ""
    end
  end

  @doc """
  This initializes the socket assigns
  """
  def init_assigns(
        _params,
        %{
          "auth_token" => auth_token,
          "current_user" => current_user,
          "_csrf_token" => csrf_token
        } = _session,
        %Phoenix.LiveView.Socket{} = socket
      ) do
    # Logger.info(session_preloaded: session)
    socket
    |> assign(:auth_token, fn -> auth_token end)
    |> assign(:current_user, fn -> current_user end)
    |> assign(:csrf_token, fn -> csrf_token end)
    |> assign(:static_changed, static_changed?(socket))
    |> assign(:search, "")
    |> assign(:app_name, CommonsPub.Config.get(:app_name))
  end

  def init_assigns(
        _params,
        %{
          "auth_token" => auth_token,
          "_csrf_token" => csrf_token
        } = session,
        %Phoenix.LiveView.Socket{} = socket
      ) do
    # Logger.info(session_load: session)

    current_user = AccountHelper.current_user(session["auth_token"])

    communities_follows =
      if(current_user) do
        CommunitiesHelper.user_communities_follows(current_user, current_user)
      end

    my_communities =
      if(communities_follows) do
        CommunitiesHelper.user_communities(current_user, current_user)
      end

    socket
    |> assign(:csrf_token, csrf_token)
    |> assign(:static_changed, static_changed?(socket))
    |> assign(:auth_token, auth_token)
    |> assign(:show_title, false)
    |> assign(:toggle_post, false)
    |> assign(:toggle_community, false)
    |> assign(:toggle_collection, false)
    |> assign(:toggle_category, false)
    |> assign(:toggle_link, false)
    |> assign(:toggle_ad, false)
    |> assign(:current_context, nil)
    |> assign(:current_user, current_user)
    |> assign(:my_communities, my_communities)
    |> assign(:my_communities_page_info, communities_follows.page_info)
    |> assign(:search, "")
    |> assign(:app_name, CommonsPub.Config.get(:app_name))
  end

  def init_assigns(
        _params,
        %{
          "_csrf_token" => csrf_token
        } = _session,
        %Phoenix.LiveView.Socket{} = socket
      ) do
    socket
    |> assign(:csrf_token, csrf_token)
    |> assign(:static_changed, static_changed?(socket))
    |> assign(:current_user, nil)
    |> assign(:search, "")
    |> assign(:app_name, CommonsPub.Config.get(:app_name))
  end

  def init_assigns(_params, _session, %Phoenix.LiveView.Socket{} = socket) do
    socket
    |> assign(:current_user, nil)
    |> assign(:search, "")
    |> assign(:static_changed, static_changed?(socket))
    |> assign(:app_name, CommonsPub.Config.get(:app_name))
  end

  @doc """
  Subscribe to feed(s) or thread(s) for realtime updates
  """
  def pubsub_subscribe(ids, socket) when is_list(ids) do
    Enum.each(ids, &pubsub_subscribe(&1, socket))
  end

  def pubsub_subscribe(id, socket) when not is_nil(id) do
    IO.inspect(pubsubscribed: id)

    if Phoenix.LiveView.connected?(socket),
      do: Phoenix.PubSub.subscribe(CommonsPub.PubSub, id)
  end

  def pubsub_subscribe(_, _) do
    false
  end

  def paginate_next(fetch_function, %{assigns: assigns} = socket) do
    {:noreply, socket |> assign(page: assigns.page + 1) |> fetch_function.(assigns)}
  end

  def prepare_common(object) do
    link = e(content_url(object), e(object, :canonical_url, "#no-link"))
    icon = icon(object)

    object
    |> Map.merge(%{link: link})
    |> Map.merge(%{icon: icon})
  end

  def image(thing) do
    # gravatar style and size for fallback images
    image(thing, "retro", 50)
  end

  def icon(thing) do
    # gravatar style and size for fallback icons
    icon(thing, "retro", 50)
  end

  def image(parent, style, size) do
    parent =
      if(is_map(parent) and Map.has_key?(parent, :__struct__)) do
        CommonsPub.Repo.maybe_preload(parent, image: [:content_upload, :content_mirror])
      end

    image_url(parent, :image, style, size)
  end

  def icon(parent, style, size) do
    parent =
      if(is_map(parent) and Map.has_key?(parent, :__struct__)) do
        CommonsPub.Repo.maybe_preload(parent, icon: [:content_upload, :content_mirror])
      end

    image_url(parent, :icon, style, size)
  end

  defp image_url(parent, field_name, style, size) do
    if(is_map(parent) and Map.has_key?(parent, :__struct__)) do
      # IO.inspect(image_field: field_name)
      # parent = CommonsPub.Repo.maybe_preload(parent, field_name: [:content_upload, :content_mirror])
      # IO.inspect(image_parent: parent)

      # img = CommonsPub.Repo.maybe_preload(Map.get(parent, field_name), :content_upload)

      img = e(parent, field_name, :content_upload, :path, nil)

      if(!is_nil(img)) do
        # use uploaded image
        CommonsPub.Uploads.prepend_url(img)
      else
        # otherwise try external image
        # img = CommonsPub.Repo.maybe_preload(Map.get(parent, field_name), :content_mirror)
        img = e(parent, field_name, :content_mirror, :url, nil)

        if(!is_nil(img)) do
          img
        else
          # or a gravatar
          image_gravatar(e(parent, :id, nil), style, size)
        end
      end
    else
      image_gravatar(field_name, style, size)
    end
  end

  def image_gravatar(seed, style, size) do
    CommonsPub.Users.Gravatar.url(to_string(seed), style, size)
  end

  def content_url(parent) do
    parent =
      if(Map.has_key?(parent, :__struct__)) do
        CommonsPub.Repo.maybe_preload(parent, content: [:content_upload, :content_mirror])
      end

    url = e(parent, :content, :content_upload, :path, nil)

    if(!is_nil(url)) do
      # use uploaded file
      CommonsPub.Uploads.prepend_url(url)
    else
      # otherwise try external link
      # img = Repo.preload(Map.get(parent, field_name), :content_mirror)
      url = e(parent, :content, :content_mirror, :url, nil)

      if(!is_nil(url)) do
        url
      else
        ""
      end
    end
  end

  def is_liked(current_user, context_id)
      when not is_nil(current_user) and not is_nil(context_id) do
    my_like =
      LikesResolver.fetch_my_like_edge(
        %{
          context: %{current_user: current_user}
        },
        context_id
      )

    # IO.inspect(my_like: my_like)
    is_liked(my_like)
  end

  def is_liked(_, _) do
    false
  end

  defp is_liked(%{data: data}) when data == %{} do
    false
  end

  defp is_liked(%{data: _}) do
    true
  end

  defp is_liked(_) do
    false
  end

  def object_url(%{
        username: username
      })
      when not is_nil(username) do
    "/" <> username
  end

  def object_url(%CommonsPub.Communities.Community{
        character: %{preferred_username: preferred_username}
      })
      when not is_nil(preferred_username) do
    "/&" <> preferred_username
  end

  def object_url(%CommonsPub.Users.User{
        character: %{preferred_username: preferred_username}
      })
      when not is_nil(preferred_username) do
    "/@" <> preferred_username
  end

  def object_url(%CommonsPub.Collections.Collection{
        character: %{preferred_username: preferred_username}
      })
      when not is_nil(preferred_username) do
    "/+" <> preferred_username
  end

  def object_url(%CommonsPub.Resources.Resource{
        id: id
      })
      when not is_nil(id) do
    "/+++" <> id
  end

  def object_url(%CommonsPub.Tag.Category{
        id: id
      })
      when not is_nil(id) do
    "/++" <> id
  end

  def object_url(%CommonsPub.Tag.Taggable{
        id: id
      })
      when not is_nil(id) do
    "/++" <> id
  end

  def object_url(%Geolocation{
        id: id
      })
      when not is_nil(id) do
    "/@@" <> id
  end

  def object_url(%ValueFlows.Planning.Intent{
        id: id
      })
      when not is_nil(id) do
    "/+++" <> id
  end

  def object_url(%{
        character: %{preferred_username: preferred_username}
      })
      when not is_nil(preferred_username) do
    "/+++" <> preferred_username
  end

  def object_url(%{thread_id: thread_id, id: comment_id, reply_to_id: is_reply})
      when not is_nil(thread_id) and not is_nil(is_reply) do
    "/!" <> thread_id <> "/discuss/" <> comment_id <> "#reply"
  end

  def object_url(%{thread_id: thread_id}) when not is_nil(thread_id) do
    "/!" <> thread_id
  end

  def object_url(%{canonical_url: canonical_url}) when not is_nil(canonical_url) do
    canonical_url
  end

  def object_url(%{character: %{canonical_url: canonical_url}})
      when not is_nil(canonical_url) do
    canonical_url
  end

  def object_url({:error, %{status: 404}}) do
    "/404"
  end

  def object_url(%{__struct__: module_name} = activity) do
    IO.inspect(type_unknown_by_object_url: module_name)
    "/+++" <> Map.get(activity, :id) <> "#type_unknown_by_object_url/" <> to_string(module_name)
  end

  def object_url(%{id: id} = activity) do
    IO.inspect(unrecognised_by_object_url: activity)
    "/+++" <> id <> "#type_unknown_by_object_url"
  end

  def object_url(id) when is_binary(id) do
    CommonsPub.Meta.Pointers.get(id) |> object_url()
  end

  def object_url(activity) do
    IO.inspect(unsupported_by_object_url: activity)
    "/404#unsupported_by_object_url"
  end

  def e_actor_field(obj, field, fallback) do
    e(
      obj,
      field,
      e(
        obj,
        :character,
        field,
        fallback
      )
    )
  end
end
