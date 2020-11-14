# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Characters do
  alias CommonsPub.GraphQL.{Fields, Page}
  alias CommonsPub.Contexts

  alias CommonsPub.{Common, Feeds, Follows, Repo}
  # alias CommonsPub.Feeds.FeedActivities
  alias CommonsPub.Users.User

  # alias CommonsPub.Workers.APPublishWorker

  alias CommonsPub.Characters.NameReservation

  alias Pointers.Pointer
  alias Pointers

  alias CommonsPub.Characters.Character
  alias CommonsPub.Characters.Queries

  alias CommonsPub.{
    Activities,
    Blocks,
    Common,
    Collections,
    Features,
    Feeds,
    Flags,
    Follows,
    Likes,
    Repo,
    Resources,
    Threads
  }

  import Ecto.Query, only: [from: 2]

  @replacement_regex ~r/[^a-zA-Z0-9-]/
  # @wordsplit_regex ~r/[\t\n \_\|\(\)\#\@\.\,\;\[\]\/\\\}\{\=\*\&\<\>\:]/

  @doc "true if the provided preferred_username is available to register"
  @spec is_username_available?(username :: binary) :: boolean()
  def is_username_available?(username) when is_binary(username) do
    # FIXME: is_nil(Repo.get(NameReservation, username))
    !Repo.exists?(from(nr in NameReservation, where: nr.name == ^username))
  end

  def cursor(:followers), do: &[&1.follower_count, &1.id]
  def test_cursor(:followers), do: &[&1["followerCount"], &1["id"]]

  @doc """
  Retrieves a single character by arbitrary filters.
  Used by:
  * GraphQL Item queries
  * ActivityPub integration
  * Various parts of the codebase that need to query for characters (inc. tests)
  """
  def one(filters), do: Repo.single(Queries.query(CommonsPub.Characters.Character, filters))

  @doc """
  Retrieves a list of characters by arbitrary filters.
  Used by:
  * Various parts of the codebase that need to query for characters (inc. tests)
  """
  def many(filters \\ []),
    do: {:ok, Repo.all(Queries.query(CommonsPub.Characters.Character, filters))}

  def fields(group_fn, filters \\ [])
      when is_function(group_fn, 1) do
    {:ok, fields} = many(filters)
    {:ok, Fields.new(fields, group_fn)}
  end

  @doc """
  Retrieves an Page of characters according to various filters

  Used by:
  * GraphQL resolver single-parent resolution
  """
  def page(cursor_fn, page_opts, base_filters \\ [], data_filters \\ [], count_filters \\ [])

  def page(cursor_fn, %{} = page_opts, base_filters, data_filters, count_filters) do
    base_q = Queries.query(CommonsPub.Characters.Character, base_filters)
    data_q = Queries.filter(base_q, data_filters)
    count_q = Queries.filter(base_q, count_filters)

    with {:ok, [data, counts]} <- Repo.transact_many(all: data_q, count: count_q) do
      {:ok, Page.new(data, counts, cursor_fn, page_opts)}
    end
  end

  @doc """
  Retrieves an Pages of characters according to various filters

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
      CommonsPub.Characters.Character,
      cursor_fn,
      group_fn,
      page_opts,
      base_filters,
      data_filters,
      count_filters
    )
  end

  ## mutations

  def create(attrs) do
    create(nil, attrs)
  end

  def create(creator, attrs, %{id: id}) when is_map(attrs) and is_binary(id) do
    create(creator, Map.put(attrs, :id, id))
  end

  def create(creator, attrs, id) when is_map(attrs) and is_binary(id) do
    create(creator, Map.put(attrs, :id, id))
  end

  def create(creator, attrs, _) when is_map(attrs) do
    create(creator, attrs)
  end

  def create(creator, %{profile: %{name: name}} = attrs) when is_map(attrs) do
    create(creator, Map.put(Map.delete(attrs, :profile), :name, name))
  end

  def create(creator, %{id: id, character: attrs}) when is_map(attrs) do
    create(creator, Map.put(attrs, :id, id))
  end

  @doc """
  Create a reference to a remote character
  """
  def create(creator, %{peer_id: peer_id} = attrs) when is_map(attrs) and not is_nil(peer_id) do
    do_create(creator, attrs)
  end

  @doc """
  Create a local character
  """
  def create(creator, attrs) when is_map(attrs) do
    attrs = prepare_username(attrs)

    do_create(creator, attrs)
  end

  defp do_create(creator, attrs) when is_map(attrs) do
    # IO.inspect(character_create: attrs)

    Repo.transact_with(fn ->
      # with {:ok, actor} <- Actors.create(attrs),
      with :ok <- maybe_reserve_username(attrs),
           {:ok, character_attrs} <- create_boxes(attrs),
           {:ok, character} <- insert_character(creator, character_attrs) do
        #  act_attrs = %{verb: "created", is_local: true},
        #  {:ok, activity} <- Activities.create(creator, character, act_attrs),
        #  :ok <- publish(creator, character, activity, :created),
        #  {:ok, _follow} <- Follows.create(creator, character, %{is_local: true}) do

        maybe_follow(creator, character)

        {:ok, character}
      end
    end)
  end

  def maybe_reserve_username(attrs) do
    if !Map.get(attrs, :peer_id) or is_nil(attrs.peer_id) do
      case reserve_username(attrs.preferred_username) do
        {:ok, _} -> :ok
        _ -> {:error, "Username already taken"}
      end
    else
      :ok
    end
  end

  @doc "Inserts a username reservation if it has not already been reserved"
  def reserve_username(username) when is_binary(username) do
    Repo.insert(NameReservation.changeset(username))
  end

  def maybe_follow(%{id: user_id} = creator, %{id: character_id} = character)
      when user_id != character_id do
    # lets not follow ourself lol
    Follows.create(creator, character, %{is_local: true})
  end

  def maybe_follow(_, _) do
    nil
  end

  # @doc """
  # creates a new character from the given attrs with an automatically generated username
  # """
  # @spec auto_create(attrs :: map) :: {:ok, Character.t()} | {:error, Changeset.t()}
  # def auto_create(attrs) when is_map(attrs) do
  #   attrs
  #   |> Map.update(:preferred_username, nil, &sanitise_username/1)
  #   |> create()
  # end

  defp create_boxes(%{peer_id: peer_id} = attrs) when not is_nil(peer_id),
    do: create_remote_boxes(attrs)

  defp create_boxes(attrs), do: create_local_boxes(attrs)

  defp create_local_boxes(attrs) do
    with {:ok, inbox} <- Feeds.create(),
         {:ok, outbox} <- Feeds.create() do
      extra = %{inbox_id: inbox.id, outbox_id: outbox.id}
      {:ok, Map.merge(attrs, extra)}
    end
  end

  defp create_remote_boxes(attrs) do
    with {:ok, outbox} <- Feeds.create() do
      {:ok, Map.put(attrs, :outbox_id, outbox.id)}
    end
  end

  # defp insert_character(creator, attrs) do
  #   cs = Character.create_changeset(creator, attrs)
  #   IO.inspect(cs)
  #   with {:ok, character} <- Repo.insert(cs), do: {:ok, character}
  # end

  defp insert_character(creator, attrs) do
    cs = Character.create_changeset(creator, attrs)
    # IO.inspect(cs)
    with {:ok, character} <- Repo.insert(cs), do: {:ok, character}
  end

  # defp insert_character_with_characteristic(creator, characteristic, character, attrs) do
  #   cs = CommonsPub.Characters.create_changeset(creator, characteristic, character, nil, attrs)
  #   with {:ok, character} <- Repo.insert(cs), do: {:ok, %{ character | character: character, characteristic: characteristic }}
  # end

  # defp insert_character_with_context(creator, context, character, attrs) do
  #   cs = CommonsPub.Characters.create_changeset(creator, character, context, attrs)
  #   with {:ok, character} <- Repo.insert(cs), do: {:ok, %{ character | character: character, context: context }}
  # end

  # defp insert_character(creator, characteristic, context, character, attrs) do
  #   cs = CommonsPub.Characters.create_changeset(creator, characteristic, character, context, attrs)
  #   with {:ok, character} <- Repo.insert(cs), do: {:ok, %{ character | character: character, context: context, characteristic: characteristic }}
  # end

  @doc "Takes a Pointer to something and creates a character based on it"
  def characterise(user, %Pointer{} = pointer) do
    thing = CommonsPub.Meta.Pointers.follow!(pointer)

    if(is_nil(thing.character_id)) do
      characterise(user, thing)
    else
      {:ok, %{thing.character | characteristic: thing}}
    end
  end

  @doc "Takes anything and creates a character based on it"
  def characterise(user, %{} = thing) do
    # IO.inspect(thing)
    thing_name = thing.__struct__
    thing_context_module = apply(thing_name, :context_module, [])

    char_attrs = characterisation(thing_name, thing, thing_context_module)

    # IO.inspect(char_attrs)
    # characterise(user, pointer, %{})

    Repo.transact_with(fn ->
      # :ok <- {:ok, IO.inspect(character)}, # wtf, without this line character is not set in the next one
      #  {:ok, thing} <- character_link(thing, character, thing_context_module)
      with {:ok, character} <- create(user, char_attrs) do
        {:ok, character}
      end
    end)
  end

  @doc "Transform the fields of any Thing into those of a character. It is recommended to define a `charactersation/1` function (transforming the data similarly to `characterisation_default/2`) in your Thing's context module which will also be executed if present."
  def characterisation(thing_name, thing, thing_context_module) do
    attrs = characterisation_default(thing_name, thing)

    # IO.inspect(attrs)

    if(Kernel.function_exported?(thing_context_module, :characterisation, 1)) do
      # IO.inspect(function_exists_in: thing_context_module)
      apply(thing_context_module, :characterisation, [attrs])
    else
      attrs
    end
  end

  @doc "Transform the generic fields of anything to be turned into a character."
  def characterisation_default(thing_name, thing) do
    thing
    # use Thing name as character facet/trope
    |> Map.put(:facet, thing_name |> to_string() |> String.split(".") |> List.last())
    # include the linked thing
    |> Map.put(:characteristic, thing)
    # avoid reusing IDs
    |> Map.delete(:id)
    # convert to map
    |> Map.from_struct()
    |> Map.delete(:__meta__)
  end

  def update(user, %CommonsPub.Characters.Character{} = character, %{character: attrs})
      when is_map(attrs) do
    update(user, character, attrs)
  end

  def update(_user, %Character{} = character, attrs) when is_map(attrs) do
    # character = Repo.preload(character, :actor)

    Repo.transact_with(fn ->
      with {:ok, character} <-
             Repo.update(Character.update_changeset(character, attrs)) do
        {:ok, character}
      end
    end)
  end

  def update(_, character, _) do
    # fail silently if we haven't been passed a proper character or attrs
    {:ok, character}
  end

  def update_by(%User{}, filters, updates) do
    Repo.update_all(Queries.query(Character, filters), set: updates)
  end

  def ap_receive_update(actor, data, creator) do
    with {:ok, coll} <- CommonsPub.Characters.update(creator, actor, data) do
      {:ok, coll}
    else
      {:error, e} -> {:error, e}
    end
  end

  def soft_delete(%Character{} = character) do
    Repo.transact_with(fn ->
      with {:ok, character} <- Common.Deletion.soft_delete(character),
           %{character: chars, feed: feeds} = deleted_ids(character),
           :ok <- chase_delete(%User{}, chars, feeds) do
        {:ok, character}
      end
    end)
  end

  def soft_delete(%{} = obj) do
    soft_delete(obj_character(obj))
  end

  def soft_delete(list) when is_list(list) do
    Enum.map(list, &soft_delete/1)
    {:ok, nil}
  end

  def soft_delete(_o) do
    # IO.inspect(could_not_delete_character: o)
    {:ok, nil}
  end

  @delete_by_filters [select: :delete, deleted: false]

  def soft_delete_by(%User{} = user, filters) do
    Repo.transact_with(fn ->
      {_, ids} = update_by(user, @delete_by_filters ++ filters, deleted_at: DateTime.utc_now())

      %{character: character, feed: feed} = deleted_ids(ids)
      chase_delete(user, character, feed)

      :ok
    end)
  end

  defp deleted_ids(records) when is_list(records) do
    Enum.reduce(records, %{character: [], feed: []}, fn
      %{id: id, inbox_id: nil, outbox_id: nil}, acc ->
        Map.put(acc, :character, [id | acc.character])

      %{id: id, inbox_id: nil, outbox_id: o}, acc ->
        Map.merge(acc, %{character: [id | acc.character], feed: [o | acc.feed]})

      %{id: id, inbox_id: i, outbox_id: nil}, acc ->
        Map.merge(acc, %{character: [id | acc.character], feed: [i | acc.feed]})

      %{id: id, inbox_id: i, outbox_id: o}, acc ->
        Map.merge(acc, %{character: [id | acc.character], feed: [i, o | acc.feed]})
    end)
  end

  defp deleted_ids(records), do: deleted_ids([records])

  defp chase_delete(user, characters) do
    with :ok <- Activities.soft_delete_by(user, context: characters),
         :ok <- Blocks.soft_delete_by(user, context: characters),
         :ok <- Collections.soft_delete_by(user, community: characters),
         :ok <- Features.soft_delete_by(user, context: characters),
         :ok <- Flags.soft_delete_by(user, context: characters),
         :ok <- Follows.soft_delete_by(user, context: characters),
         :ok <- Likes.soft_delete_by(user, context: characters),
         :ok <- Resources.soft_delete_by(user, collection: characters),
         :ok <- Threads.soft_delete_by(user, context: characters) do
      :ok
    end
  end

  defp chase_delete(user, characters, []), do: chase_delete(user, characters)

  defp chase_delete(user, characters, feeds) do
    with :ok <- Feeds.soft_delete_by(user, id: feeds), do: chase_delete(user, characters)
  end

  def delete(%User{}, %Character{} = character), do: Repo.delete(character)


  # When the username is autogenerated, we have to scrub it
  def sanitise_username(username) when is_nil(username), do: nil

  def sanitise_username(username) do
    Slugger.slugify(username)
    # |> String.replace(@wordsplit_regex, "-")
    |> String.replace(@replacement_regex, "-")

    # |> String.replace(~r/--+/, "-")
  end

  def prepare_username(%{:preferred_username => preferred_username} = attrs)
      when not is_nil(preferred_username) and preferred_username != "" do
    Map.put(attrs, :preferred_username, sanitise_username(preferred_username))
  end

  # if no username set, autocreate from name
  def prepare_username(%{:name => name} = attrs)
      when not is_nil(name) and name != "" do
    Map.put(attrs, :preferred_username, sanitise_username(Map.get(attrs, :name)))
  end

  def prepare_username(attrs) do
    attrs
  end

  def display_username(obj, full_hostname \\ false)

  def display_username(%Ecto.Association.NotLoaded{}, _), do: nil

  def display_username(%CommonsPub.Communities.Community{} = obj, full_hostname) do
    display_username(obj, full_hostname, "&")
  end

  def display_username(%CommonsPub.Collections.Collection{} = obj, full_hostname) do
    display_username(obj, full_hostname, "+")
  end

  def display_username(%CommonsPub.Tag.Taggable{} = obj, full_hostname) do
    display_username(obj, full_hostname, "+")
  end

  def display_username(%CommonsPub.Tag.Category{} = obj, full_hostname) do
    display_username(obj, full_hostname, "+")
  end

  def display_username(%CommonsPub.Users.User{} = obj, full_hostname) do
    display_username(obj, full_hostname, "@")
  end

  def display_username(obj, full_hostname) do
    display_username(obj, full_hostname, "@")
  end

  def display_username(%{"preferred_username" => uname}, _full_hostname, prefix)
      when not is_nil(uname) do
    "#{prefix}#{uname}"
  end

  def display_username(%{preferred_username: uname}, _full_hostname, prefix)
      when not is_nil(uname) do
    "#{prefix}#{uname}"
  end

  def display_username(
        %{character: %{peer_id: nil, preferred_username: uname}},
        true,
        prefix
      ) do
    "#{prefix}#{uname}" <> "@" <> CommonsPub.Instance.hostname()
  end

  def display_username(
        %{character: %{peer_id: nil, preferred_username: uname}},
        false,
        prefix
      )
      when not is_nil(uname) do
    "#{prefix}#{uname}"
  end

  # def display_username(
  #       %{
  #         character: %{peer_id: nil, preferred_username: uname}
  #       },
  #       full_hostname,
  #       prefix
  #     ) do
  #   display_username(
  #     %{actor: actor},
  #     full_hostname,
  #     prefix
  #   )
  # end

  def display_username(
        %{character: %{preferred_username: uname}},
        _full_hostname,
        prefix
      )
      when not is_nil(uname) do
    "#{prefix}#{uname}"
  end

  def display_username(%{character: _} = obj, full_hostname, prefix) do
    obj = CommonsPub.Repo.maybe_preload(obj, :character)
    display_username(Map.get(obj, :character), full_hostname, prefix)
  end

  def display_username(%Pointer{} = pointer, full_hostname, prefix) do
    thing = CommonsPub.Meta.Pointers.follow!(pointer)
    display_username(thing, full_hostname, prefix)
  end

  def display_username(obj, _, _) do
    IO.inspect(could_not_display_username: obj)
    ""
  end

  def obj_with_character(obj) do
    CommonsPub.Repo.maybe_preload(obj, :character)
  end

  def obj_character(%{character: %Ecto.Association.NotLoaded{}} = obj) do
    obj_character(obj_with_character(obj))
  end

  def obj_character(%{character: character} = _obj) do
    character
  end
end
