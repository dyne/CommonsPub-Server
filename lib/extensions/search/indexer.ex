# SPDX-License-Identifier: AGPL-3.0-only

defmodule CommonsPub.Search.Indexer do
  require Logger
  # alias CommonsPub.Utils.Web.CommonHelper

  @public_index "public"

  def maybe_index_object(object) do
    indexable_object = maybe_indexable_object(object)

    if !is_nil(indexable_object) do
      index_public_object(indexable_object)
    end
  end

  def maybe_indexable_object(nil) do
    nil
  end

  def maybe_indexable_object(%{"index_type" => index_type} = object)
      when not is_nil(index_type) do
    # already formatted indexable object
    object
  end

  def maybe_indexable_object(%Pointers.Pointer{} = pointer) do
    pointed_object = CommonsPub.Meta.Pointers.follow!(pointer)
    maybe_indexable_object(pointed_object)
  end

  def maybe_indexable_object(%{__struct__: object_type} = object) do
    # already formatted indexable object
    # object_type = Map.get(object, :__struct__)

    if(
      !is_nil(object_type) and
        CommonsPub.Config.module_enabled?(object_type) and
        Kernel.function_exported?(object_type, :context_module, 0)
    ) do
      object_context_module = apply(object_type, :context_module, [])

      if(
        CommonsPub.Config.module_enabled?(object_context_module) and
          Kernel.function_exported?(object_context_module, :indexing_object_format, 1)
      ) do
        # IO.inspect(function_exists_in: object_context_module)
        indexable_object = apply(object_context_module, :indexing_object_format, [object])
        indexable_object
      else
        Logger.warn(
          "Could not index #{object_type} object (no context module with indexing_object_format/1)"
        )

        nil
      end
    else
      Logger.warn(
        "Could not index #{object_type} object (not a known type or context_module undefined)"
      )

      nil
    end
  end

  def maybe_indexable_object(obj) do
    Logger.warn("Could not index object (not formated for indexing or not a struct)")
    IO.inspect(obj)
    nil
  end

  # add to general instance search index
  def index_public_object(object) do
    # IO.inspect(search_indexing: objects)
    index_objects(object, @public_index, true)
  end

  # index several things in an existing index
  def index_objects(objects, index_name, init_index_first \\ true)

  def index_objects(objects, index_name, init_index_first) when is_list(objects) do
    # IO.inspect(objects)
    # FIXME - should create the index only once
    if init_index_first, do: init_index(index_name, true)
    CommonsPub.Search.Meili.put(objects, index_name <> "/documents")
  end

  # index something in an existing index
  def index_objects(object, index_name, init_index_first) do
    # IO.inspect(object)
    index_objects([object], index_name, init_index_first)
  end

  # create a new index
  def init_index(index_name \\ "public", fail_silently \\ false)

  def init_index("public" = index_name, fail_silently) do
    create_index(index_name, fail_silently)
    set_facets(index_name, ["username", "index_type", "index_instance"])
  end

  def init_index(index_name, fail_silently) do
    create_index(index_name, fail_silently)
  end

  def create_index(index_name, fail_silently \\ false) do
    CommonsPub.Search.Meili.post(%{uid: index_name}, "", fail_silently)
  end

  def index_exists(index_name) do
    with {:ok, _index} <- CommonsPub.Search.Meili.get(nil, index_name) do
      true
    else
      _e ->
        false
    end
  end

  # def set_attributes(attrs, index) do
  #   settings(%{attributesForFaceting: attrs}, index)
  # end

  def set_facets(index_name, facets) when is_list(facets) do
    CommonsPub.Search.Meili.post(
      facets,
      index_name <> "/settings/attributes-for-faceting",
      false
    )
  end

  def set_facets(index_name, facet) do
    set_facets(index_name, [facet])
  end

  def list_facets(index_name \\ "public") do
    CommonsPub.Search.Meili.get(nil, index_name <> "/settings/attributes-for-faceting")
  end

  def maybe_delete_object(object) do
    delete_object(object)
    :ok
  end

  defp delete_object(nil) do
    Logger.warn("Couldn't get object ID in order to delete")
  end

  defp delete_object(_object_id) do
    # TODO
  end

  def host(url) when is_binary(url) do
    URI.parse(url).host
  end

  def host(_) do
    ""
  end

  def format_creator(%{creator: %{id: id}} = obj) when not is_nil(id) do
    creator = CommonsPub.Repo.maybe_preload(obj, :creator).creator

    %{
      "id" => creator.id,
      "name" => creator.name,
      "username" => CommonsPub.Characters.display_username(creator),
      "canonical_url" => CommonsPub.ActivityPub.Utils.get_actor_canonical_url(creator)
    }
  end

  def format_creator(_) do
    nil
  end
end
