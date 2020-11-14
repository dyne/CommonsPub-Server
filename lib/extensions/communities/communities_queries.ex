# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Communities.Queries do
  alias CommonsPub.Communities.Community
  alias CommonsPub.Follows.{Follow, FollowerCount}
  alias CommonsPub.Users.User
  import CommonsPub.Common.Query, only: [match_admin: 0]

  import Ecto.Query

  def query(Community), do: from(c in Community, as: :community)

  def query(query, filters), do: filter(query(query), filters)

  defp join_to(q, spec, join_qualifier \\ :left)

  defp join_to(q, :character, jq),
    do: join(q, jq, [community: c], assoc(c, :character), as: :character)

  defp join_to(q, {:follow, follower_id}, jq) do
    join(q, jq, [community: c], f in Follow,
      as: :follow,
      on: c.id == f.context_id and f.creator_id == ^follower_id
    )
  end

  defp join_to(q, :follower_count, jq) do
    join(q, jq, [community: c], fc in FollowerCount,
      as: :follower_count,
      on: c.id == fc.context_id
    )
  end

  @doc "Filter the query according to arbitrary criteria"
  def filter(query, filter_or_filters)

  def filter(q, filters) when is_list(filters), do: Enum.reduce(filters, q, &filter(&2, &1))

  def filter(q, :default), do: filter(q, deleted: false, join: :character, preload: :character)

  def filter(q, {:join, {join, qual}}), do: join_to(q, join, qual)
  def filter(q, {:join, join}), do: join_to(q, join)

  def filter(q, {:user, match_admin()}), do: filter(q, deleted: false)
  def filter(q, {:user, nil}), do: filter(q, deleted: false, disabled: false, published: true)

  def filter(q, {:user, %User{id: id}}) do
    join_to(q, {:follow, id})
    |> where([follow: f, community: c], not is_nil(c.published_at) or not is_nil(f.id))
  end

  def filter(q, {:deleted, nil}), do: where(q, [community: c], is_nil(c.deleted_at))
  def filter(q, {:deleted, :not_nil}), do: where(q, [community: c], not is_nil(c.deleted_at))
  def filter(q, {:deleted, false}), do: where(q, [community: c], is_nil(c.deleted_at))
  def filter(q, {:deleted, true}), do: where(q, [community: c], not is_nil(c.deleted_at))

  def filter(q, {:deleted, {:gte, %DateTime{} = time}}),
    do: where(q, [community: c], c.deleted_at >= ^time)

  def filter(q, {:deleted, {:lte, %DateTime{} = time}}),
    do: where(q, [community: c], c.deleted_at <= ^time)

  def filter(q, {:disabled, nil}), do: where(q, [community: c], is_nil(c.disabled_at))
  def filter(q, {:disabled, :not_nil}), do: where(q, [community: c], not is_nil(c.disabled_at))
  def filter(q, {:disabled, false}), do: where(q, [community: c], is_nil(c.disabled_at))
  def filter(q, {:disabled, true}), do: where(q, [community: c], not is_nil(c.disabled_at))

  def filter(q, {:disabled, {:gte, %DateTime{} = time}}),
    do: where(q, [community: c], c.disabled_at >= ^time)

  def filter(q, {:disabled, {:lte, %DateTime{} = time}}),
    do: where(q, [community: c], c.disabled_at <= ^time)

  def filter(q, {:published, nil}), do: where(q, [community: c], is_nil(c.published_at))
  def filter(q, {:published, :not_nil}), do: where(q, [community: c], not is_nil(c.published_at))
  def filter(q, {:published, false}), do: where(q, [community: c], is_nil(c.published_at))
  def filter(q, {:published, true}), do: where(q, [community: c], not is_nil(c.published_at))

  def filter(q, {:published, {:gte, %DateTime{} = time}}),
    do: where(q, [community: c], c.published_at >= ^time)

  def filter(q, {:published, {:lte, %DateTime{} = time}}),
    do: where(q, [community: c], c.published_at <= ^time)

  def filter(q, {:id, id}) when is_binary(id), do: where(q, [community: c], c.id == ^id)
  def filter(q, {:id, {:gte, id}}) when is_binary(id), do: where(q, [community: c], c.id >= ^id)
  def filter(q, {:id, {:lte, id}}) when is_binary(id), do: where(q, [community: c], c.id <= ^id)
  def filter(q, {:id, ids}) when is_list(ids), do: where(q, [community: c], c.id in ^ids)

  @doc "filter by parent/context"
  def filter(q, {:context, id}) when is_binary(id),
    do: where(q, [community: c], c.context_id == ^id)

  def filter(q, {:context, ids}) when is_list(ids),
    do: where(q, [community: c], c.context_id in ^ids)

  def filter(q, {:creator, id}) when is_binary(id) do
    where(q, [community: c], c.creator_id == ^id)
  end

  def filter(q, {:creator, ids}) when is_list(ids) do
    where(q, [community: c], c.creator_id in ^ids)
  end

  def filter(q, {:username, username}) when is_binary(username) do
    where(q, [community: c, character: a], a.preferred_username == ^username)
  end

  def filter(q, {:username, usernames}) when is_list(usernames) do
    where(q, [character: a], a.preferred_username in ^usernames)
  end

  def filter(q, {:cursor, [followers: {:gte, [count, id]}]})
      when is_integer(count) and is_binary(id) do
    where(
      q,
      [community: c, follower_count: fc],
      (fc.count == ^count and c.id >= ^id) or fc.count > ^count
    )
  end

  def filter(q, {:cursor, [followers: {:lte, [count, id]}]})
      when is_integer(count) and is_binary(id) do
    where(
      q,
      [community: c, follower_count: fc],
      (fc.count == ^count and c.id <= ^id) or fc.count < ^count
    )
  end

  def filter(q, {:limit, limit}), do: limit(q, ^limit)

  def filter(q, {:preload, :character}), do: preload(q, [character: a], character: a)

  def filter(q, {:order, [asc: :created]}), do: order_by(q, [community: c], asc: c.id)
  def filter(q, {:order, [desc: :created]}), do: order_by(q, [community: c], desc: c.id)

  def filter(q, {:order, [asc: :followers]}) do
    order_by(q, [community: c, follower_count: fc], asc: coalesce(fc.count, 0), desc: c.id)
  end

  def filter(q, {:order, [desc: :followers]}) do
    order_by(q, [community: c, follower_count: fc], desc: coalesce(fc.count, 0), desc: c.id)
  end


  def filter(q, {:page, [desc: [followers: page_opts]]}) do
    q
    |> filter(join: :follower_count, order: [desc: :followers])
    |> page(page_opts, desc: :followers)
    |> select(
      [community: c, character: a, follower_count: fc],
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

  defp page(q, %{limit: limit}, desc: :followers), do: filter(q, limit: limit + 1)
end
