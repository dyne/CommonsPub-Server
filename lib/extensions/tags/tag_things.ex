defmodule CommonsPub.Tag.TagThings do
  # import Ecto.Query
  # alias Ecto.Changeset
  alias CommonsPub.{
    # Common, GraphQL,
    Repo
  }

  alias CommonsPub.Tag.Taggable

  @doc """
  tag IDs from a `tags` field
  """
  def try_tag_thing(user, thing, %{tags: tag_ids}) when is_binary(tag_ids) do
    tag_ids = CommonsPub.Web.Component.TagAutocomplete.tags_split(tag_ids)
    things_add_tags(user, thing, tag_ids)
  end

  def try_tag_thing(user, thing, %{tags: tag_ids})
      when is_list(tag_ids) and length(tag_ids) > 0 do
    things_add_tags(user, thing, tag_ids)
  end


  @doc """
  otherwise maybe we have tagnames inline in the note?
  """
  def try_tag_thing(_user, thing, %{note: text}) when bit_size(text) > 1 do
    # CommonsPub.Web.Component.TagAutocomplete.try_prefixes(text)
    # TODO - use tags in the note
    {:ok, thing}
  end

  def try_tag_thing(_user, thing, _) do
    {:ok, thing}
  end

  @doc """
  tag existing thing with one or multiple Taggables, Pointers, or anything that can be made taggable
  """
  def things_add_tags(user, thing, taggables) do
    with {:ok, _taggable} <- thing_attach_tags(user, thing, taggables) do
      {:ok, CommonsPub.Repo.maybe_preload(thing, :tags)}
    end
  end

  @doc """
  Add tag(s) to a pointable thing. Will replace any existing tags.
  """
  def thing_attach_tags(user, thing, taggables) when is_list(taggables) do
    thing = thing_to_pointer(thing)
    tags = Enum.map(taggables, &tag_preprocess(user, &1))
    # {:ok, thing |> Map.merge(%{tags: things_add_tags})}
    thing_tags_save(thing, tags)
  end

  def thing_attach_tags(user, thing, taggable) do
    thing_attach_tags(user, thing, [taggable])
  end

  def thing_attach_tag(user, thing, taggable) do
    thing_attach_tags(user, thing, [taggable])
  end

  @doc """
  Prepare a tag to be used, by loading or even creating it
  """
  defp tag_preprocess(_user, %Taggable{} = tag) do
    tag
  end

  defp tag_preprocess(_, tag) when is_nil(tag) or tag == "" do
    nil
  end

  defp tag_preprocess(_user, {:error, e}) do
    IO.inspect(invalid_taggable: e)
    nil
  end

  defp tag_preprocess(user, {_at_mention, taggable}) do
    tag_preprocess(user, taggable)
  end

  defp tag_preprocess(user, "@" <> taggable) do
    tag_preprocess(user, taggable)
  end

  defp tag_preprocess(user, "+" <> taggable) do
    tag_preprocess(user, taggable)
  end

  defp tag_preprocess(user, "&" <> taggable) do
    tag_preprocess(user, taggable)
  end

  defp tag_preprocess(user, taggable) do

    with {:ok, tag} <- CommonsPub.Tag.Taggables.maybe_make_taggable(user, taggable) do
      # with an object that we have just made taggable
      tag_preprocess(user, tag)
    else
      _e ->
        {:error, "Could not find or create such a tag or taggable context"}
    end
  end

  defp thing_tags_save(%{} = thing, tags) when is_list(tags) and length(tags) > 0 do
    # remove nils
    tags = Enum.filter(tags, & &1)

    Repo.transact_with(fn ->
      cs = Taggable.thing_tags_changeset(thing, tags)
      with {:ok, thing} <- Repo.update(cs, on_conflict: :nothing), do: {:ok, thing}
    end)
  end

  defp thing_tags_save(thing, _tags) do
    {:ok, thing}
  end

  @doc """
  Load thing as Pointer
  """
  defp thing_to_pointer(pointer_id) when is_binary(pointer_id) do
    with {:ok, pointer} <- CommonsPub.Meta.Pointers.one(id: pointer_id) do
      # thing = CommonsPub.Meta.Pointers.follow!(pointer)
      pointer
    end
  end

  defp thing_to_pointer(%Pointers.Pointer{} = pointer) do
    pointer
  end

  defp thing_to_pointer(%{id: id}) do
    thing_to_pointer(id)
  end

  # def tag_things(user, tag, pointer_ids) when is_list(pointer_ids) do
  #   # requires a list of Pointer IDs
  #   with {:ok, pointers} <- CommonsPub.Meta.Pointers.many(ids: pointer_ids) do
  #     tag_pointers(user, tag, pointers)
  #   end
  # end

  # defp tag_pointers(user, %Taggable{} = tag, things) do
  #   Repo.transact_with(fn ->
  #     tag = Repo.preload(tag, :things)

  #     with {:ok, taggable} <- tag_pointers_save(tag, things) do
  #       {:ok, taggable}
  #     end
  #   end)
  # end

  # defp tag_pointers(_, "", _) do
  #   nil
  # end

  # defp tag_pointers(user, {:error, e}, things) do
  #   IO.inspect(invalid_taggable: e)
  #   nil
  # end

  # defp tag_pointers(user, taggable, things) do
  #   IO.inspect(taggable)
  #   IO.inspect(things)

  #   with {:ok, tag} <- CommonsPub.Tag.Taggables.maybe_make_taggable(user, taggable) do
  #     IO.inspect(taggable)
  #     # with an object that we made taggable
  #     tag_pointers(user, tag, things)
  #   else
  #     _e ->
  #       {:error, "Could not find or create such a tag or taggable context"}
  #   end
  # end

  # defp tag_pointers_save(tag, things) do
  #   IO.inspect(tag_pointers_insert: tag)
  #   IO.inspect(tag_pointers_insert: things)
  #   cs = Taggable.tag_things_changeset(tag, things)
  #   with {:ok, taggable} <- Repo.update(cs), do: {:ok, taggable}
  # end
end
