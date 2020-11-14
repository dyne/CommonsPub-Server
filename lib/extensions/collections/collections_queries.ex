# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Collections.Queries do
  alias CommonsPub.Communities
  alias CommonsPub.Collections.Collection
  alias CommonsPub.Follows.{Follow, FollowerCount}
  alias CommonsPub.Users.User
  alias CommonsPub.Communities.Community

  import CommonsPub.Common.Query, only: [match_admin: 0]
  import Ecto.Query

  def query(Collection), do: from(c in Collection, as: :collection)

  def query(q, filters), do: filter(query(q), filters)

  defp join_to(q, spec, join_qualifier \\ :left)
  defp join_to(q, specs, jq) when is_list(specs), do: Enum.reduce(specs, q, &join_to(&2, &1, jq))

  defp join_to(q, :character, jq),
    do: join(q, jq, [collection: c], assoc(c, :character), as: :character)

  defp join_to(q, :community, jq),
    do: join(q, jq, [collection: c], assoc(c, :community), as: :community)

  defp join_to(q, {:community_follow, follower_id}, jq) do
    join(q, jq, [community: c], f in Follow,
      as: :community_follow,
      on: c.id == f.context_id and f.creator_id == ^follower_id
    )
  end

  defp join_to(q, {:follow, follower_id}, jq) do
    join(q, jq, [collection: c], f in Follow,
      as: :follow,
      on: c.id == f.context_id and f.creator_id == ^follower_id
    )
  end

  defp join_to(q, :follower_count, jq) do
    join(q, jq, [collection: c], f in FollowerCount,
      on: c.id == f.context_id,
      as: :follower_count
    )
  end

  def filter(query, filter_or_filters)
  def filter(q, filters) when is_list(filters), do: Enum.reduce(filters, q, &filter(&2, &1))

  def filter(q, {:join, {join, qual}}), do: join_to(q, join, qual)
  def filter(q, {:join, join}), do: join_to(q, join)

  def filter(q, :default), do: filter(q, deleted: false, join: :character, preload: :character)

  def filter(q, {:user, match_admin()}), do: filter(q, deleted: false)

  def filter(q, {:user, %User{id: id}}) do
    q
    |> join_to([:community, follow: id, community_follow: id])
    |> where([community: c, community_follow: f], not is_nil(c.published_at) or not is_nil(f.id))
    |> where([collection: c, follow: f], not is_nil(c.published_at) or not is_nil(f.id))
    |> filter(disabled: false)
    |> Communities.Queries.filter(deleted: false, disabled: false)
  end

  def filter(q, {:user, nil}) do
    filter(q, join: :community, deleted: false, disabled: false, published: true)
  end

  def filter(q, {:deleted, nil}), do: where(q, [collection: c], is_nil(c.deleted_at))
  def filter(q, {:deleted, :not_nil}), do: where(q, [collection: c], not is_nil(c.deleted_at))
  def filter(q, {:deleted, false}), do: where(q, [collection: c], is_nil(c.deleted_at))
  def filter(q, {:deleted, true}), do: where(q, [collection: c], not is_nil(c.deleted_at))

  def filter(q, {:deleted, {:gte, %DateTime{} = time}}),
    do: where(q, [collection: c], c.deleted_at >= ^time)

  def filter(q, {:deleted, {:lte, %DateTime{} = time}}),
    do: where(q, [collection: c], c.deleted_at <= ^time)

  def filter(q, {:disabled, nil}), do: where(q, [collection: c], is_nil(c.disabled_at))
  def filter(q, {:disabled, :not_nil}), do: where(q, [collection: c], not is_nil(c.disabled_at))
  def filter(q, {:disabled, false}), do: where(q, [collection: c], is_nil(c.disabled_at))
  def filter(q, {:disabled, true}), do: where(q, [collection: c], not is_nil(c.disabled_at))

  def filter(q, {:disabled, {:gte, %DateTime{} = time}}),
    do: where(q, [collection: c], c.disabled_at >= ^time)

  def filter(q, {:disabled, {:lte, %DateTime{} = time}}),
    do: where(q, [collection: c], c.disabled_at <= ^time)

  def filter(q, {:published, nil}), do: where(q, [collection: c], is_nil(c.published_at))
  def filter(q, {:published, :not_nil}), do: where(q, [collection: c], not is_nil(c.published_at))
  def filter(q, {:published, false}), do: where(q, [collection: c], is_nil(c.published_at))
  def filter(q, {:published, true}), do: where(q, [collection: c], not is_nil(c.published_at))

  def filter(q, {:published, {:gte, %DateTime{} = time}}),
    do: where(q, [collection: c], c.published_at >= ^time)

  def filter(q, {:published, {:lte, %DateTime{} = time}}),
    do: where(q, [collection: c], c.published_at <= ^time)

  def filter(q, {:cursor, [followers: {:gte, [count, id]}]})
      when is_integer(count) and is_binary(id) do
    where(
      q,
      [collection: c, follower_count: fc],
      (fc.count == ^count and c.id >= ^id) or fc.count > ^count
    )
  end

  def filter(q, {:cursor, [followers: {:lte, [count, id]}]})
      when is_integer(count) and is_binary(id) do
    where(
      q,
      [collection: c, follower_count: fc],
      (fc.count == ^count and c.id <= ^id) or fc.count < ^count
    )
  end

  def filter(q, {:id, id}) when is_binary(id), do: where(q, [collection: c], c.id == ^id)
  def filter(q, {:id, ids}) when is_list(ids), do: where(q, [collection: c], c.id in ^ids)

  def filter(q, {:context, id}) when is_binary(id),
    do: where(q, [collection: c], c.context_id == ^id)

  def filter(q, {:context, ids}) when is_list(ids),
    do: where(q, [collection: c], c.context_id in ^ids)

  def filter(q, {:community, id}) when is_binary(id),
    do: where(q, [collection: c], c.context_id == ^id)

  def filter(q, {:community, ids}) when is_list(ids),
    do: where(q, [collection: c], c.context_id in ^ids)

  def filter(q, {:creator, id}) when is_binary(id) do
    where(q, [collection: c], c.creator_id == ^id)
  end

  def filter(q, {:creator, ids}) when is_list(ids) do
    where(q, [collection: c], c.creator_id in ^ids)
  end

  def filter(q, {:username, username}) when is_binary(username) do
    where(q, [character: a], a.preferred_username == ^username)
  end

  def filter(q, {:username, usernames}) when is_list(usernames) do
    where(q, [character: a], a.preferred_username in ^usernames)
  end

  def filter(q, {:order, [asc: :followers]}) do
    order_by(q, [collection: c, follower_count: fc], asc: coalesce(fc.count, 0), desc: c.id)
  end

  def filter(q, {:order, [desc: :followers]}) do
    order_by(q, [collection: c, follower_count: fc], desc: coalesce(fc.count, 0), desc: c.id)
  end

  def filter(q, {:group_count, key}) when is_atom(key), do: filter(q, group: key, count: key)

  def filter(q, {:group, key}) when is_atom(key), do: group_by(q, [collection: c], field(c, ^key))

  def filter(q, {:count, key}) when is_atom(key),
    do: select(q, [collection: c], {field(c, ^key), count(c.id)})

  def filter(q, {:preload, :character}), do: preload(q, [character: a], character: a)

  def filter(q, {:limit, limit}), do: limit(q, ^limit)

  def filter(q, {:page, [desc: [followers: page_opts]]}) do
    q
    |> filter(join: :follower_count, order: [desc: :followers])
    |> page(page_opts, desc: :followers)
    |> select(
      [collection: c, character: a, follower_count: fc],
      %{c | follower_count: coalesce(fc.count, 0), character: a}
    )
  end

  defp page(q, %{after: cursor, limit: limit}, asc: :followers) do
    filter(q, cursor: [followers: {:gte, cursor}], limit: limit + 2)
  end

  defp page(q, %{before: cursor, limit: limit}, asc: :followers) do
    filter(q, cursor: [followers: {:lte, cursor}], limit: limit + 2)
  end

  defp page(q, %{after: cursor, limit: limit}, desc: :followers) do
    filter(q, cursor: [followers: {:lte, cursor}], limit: limit + 2)
  end

  defp page(q, %{before: cursor, limit: limit}, desc: :followers) do
    filter(q, cursor: [followers: {:gte, cursor}], limit: limit + 2)
  end

  defp page(q, %{limit: limit}, _), do: filter(q, limit: limit + 1)
end
