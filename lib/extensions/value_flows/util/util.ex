# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Util do
  @schema CommonsPub.Web.GraphQL.Schema
  @all_types CommonsPub.Config.get([CommonsPub.ActivityPub.Adapter, :all_types])

  @graphql_ignore_fields [
    :communities,
    :collections,
    :my_like,
    :my_flag,
    :unit_based,
    :feature_count,
    :follower_count,
    :is_local,
    :is_disabled,
    :page_info,
    :edges,
    :threads,
    :outbox,
    :inbox,
    :followers,
    :community_follows
  ]

  # def try_tag_thing(user, thing, attrs) do
  #   IO.inspect(attrs)
  # end

  @doc """
  lookup tag from URL(s), to support vf-graphql mode
  """

  # def try_tag_thing(_user, thing, %{resource_classified_as: urls})
  #     when is_list(urls) and length(urls) > 0 do
  #   # todo: lookup tag by URL
  #   {:ok, thing}
  # end

  def try_tag_thing(user, thing, tags) do
    CommonsPub.Tag.TagThings.try_tag_thing(user, thing, tags)
  end

  def handle_changeset_errors(cs, attrs, fn_list) do
    Enum.reduce_while(fn_list, cs, fn cs_handler, cs ->
      case cs_handler.(cs, attrs) do
        {:error, reason} -> {:halt, {:error, reason}}
        cs -> {:cont, cs}
      end
    end)
    |> case do
      {:error, _} = e -> e
      cs -> {:ok, cs}
    end
  end

  def ap_prepare_object(id, schema_type, query_depth \\ 2, extra_field_filters \\ []) do
    field_filters = @graphql_ignore_fields ++ extra_field_filters

    with obj <-
           CommonsPub.Web.GraphQL.QueryHelper.run_query_id(
             id,
             @schema,
             schema_type,
             query_depth,
             &ap_graphql_fields_filter(&1, field_filters),
             true
           )
           |> ap_deep_key_rename() do
      # IO.inspect(prepared: obj)

      obj
    end
  end

  def ap_publish_activity(
        "create" = activity_type,
        schema_type,
        %{id: id} = thing,
        query_depth \\ 2,
        extra_field_filters \\ []
      )
      when is_binary(id) do
    with activity_params <-
           ap_prepare_activity(
             activity_type,
             thing,
             ap_prepare_object(id, schema_type, query_depth, extra_field_filters)
           ),
         {:ok, activity} <- ActivityPub.create(activity_params, id) do
      # IO.inspect(activity_created: activity)

      IO.puts(struct_to_json(activity.data))
      IO.puts(struct_to_json(activity.object.data))

      if is_map_key(thing, :canonical_url) do
        Ecto.Changeset.change(thing, %{canonical_url: activity_object_id(activity)})
        |> CommonsPub.Repo.update()
      end

      {:ok, activity}
    else
      e -> {:error, e}
    end
  end

  def ap_prepare_activity("create", thing, object, author_id \\ nil) do
    with context <-
           CommonsPub.ActivityPub.Utils.get_cached_actor_by_local_id!(Map.get(thing, :context_id)),
         author <-
           author_id || Map.get(thing, :creator_id) || Map.get(thing, :primary_accountable_id) ||
             Map.get(thing, :provider_id) || Map.get(thing, :receiver_id),
         actor <- CommonsPub.ActivityPub.Utils.get_cached_actor_by_local_id!(author),
         ap_id <- CommonsPub.ActivityPub.Utils.generate_object_ap_id(thing),
         object <-
           Map.merge(object, %{
             "id" => ap_id,
             "actor" => actor.ap_id,
             "attributedTo" => actor.ap_id
           })
           |> CommonsPub.Common.maybe_put("context", context.ap_id)
           |> CommonsPub.Common.maybe_put("name", Map.get(thing, :name, Map.get(thing, :label)))
           #  |> CommonsPub.Common.maybe_put(
           #    "summary",
           #    Map.get(thing, :note, Map.get(thing, :summary))
           #  )
           |> CommonsPub.Common.maybe_put("icon", Map.get(object, "image")),
         activity_params = %{
           actor: actor,
           to: [CommonsPub.ActivityPub.Utils.public_uri(), context.ap_id],
           object: object,
           context: context.ap_id,
           additional: %{
             "cc" => [actor.data["followers"]]
           }
         } do
      activity_params
    end
  end

  def ap_graphql_fields_filter(e, field_filters \\ []) do
    # IO.inspect(e)

    case e do
      {key, {key2, val}} ->
        if key not in field_filters and key2 not in field_filters and
             is_list(val) do
          {key, {key2, for(n <- val, do: ap_graphql_fields_filter(n, field_filters))}}
          # else
          #   IO.inspect(hmm1: e)
        end

      {key, val} ->
        if key not in field_filters and is_list(val) do
          {key, for(n <- val, do: ap_graphql_fields_filter(n, field_filters))}
          # else
          #   IO.inspect(hmm2: e)
        end

      _ ->
        if e not in field_filters, do: e
    end
  end

  def ap_deep_key_rename(map, parent_key \\ nil)

  def ap_deep_key_rename(map = %{}, _parent_key) do
    map
    |> Enum.reject(fn {_, v} -> is_nil(v) or v == %{} end)
    |> Enum.map(fn {k, v} -> {ap_field_key(k), ap_deep_key_rename(v, k)} end)
    |> Enum.into(%{})
  end

  def ap_deep_key_rename(list, parent_key) when is_list(list) do
    list
    |> Enum.reject(fn v -> is_nil(v) or v == %{} end)
    |> Enum.map(fn v -> ap_deep_key_rename(v, parent_key) end)

    # |> Enum.into(%{})
  end

  def ap_deep_key_rename(val, parent_key)
      when parent_key == "__typename" and val not in @all_types do
    "ValueFlows:#{val}"
  end

  def ap_deep_key_rename(val, parent_key) when parent_key == "id" do
    CommonsPub.ActivityPub.Utils.get_object_canonical_url(val)
  end

  def ap_deep_key_rename(val, _parent_key) do
    # IO.inspect(deep_key_rename_k: parent_key)
    # IO.inspect(deep_key_rename_v: val)
    val
  end

  def ap_field_key(k) do
    case k do
      "__typename" -> "type"
      "canonicalUrl" -> "id"
      "creator" -> "actor"
      "displayUsername" -> "preferredUsername"
      "created" -> "published"
      # "hasBeginning" -> "published"
      _ -> k
    end
  end

  def struct_to_json(struct) do
    Jason.encode!(deep_map_from_struct(struct))
  end

  def deep_map_from_struct(struct = %{__struct__: _}) do
    Map.from_struct(struct) |> Map.drop([:__meta__]) |> deep_map_from_struct()
  end

  def deep_map_from_struct(map = %{}) do
    map
    |> Enum.map(fn {k, v} -> {k, deep_map_from_struct(v)} end)
    |> Enum.into(%{})
  end

  def deep_map_from_struct(v) when is_tuple(v), do: v |> Tuple.to_list()
  def deep_map_from_struct(v), do: v

  def activity_object_id(%{object: object}) do
    activity_object_id(object)
  end

  def activity_object_id(%{"object" => object}) do
    activity_object_id(object)
  end

  def activity_object_id(%{data: data}) do
    activity_object_id(data)
  end

  def activity_object_id(%{"id" => id}) do
    id
  end
end
