# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Characters.Queries do
  # alias CommonsPub.Users
  # alias CommonsPub.Characters.Character
  alias CommonsPub.Follows.{Follow, FollowerCount}
  alias CommonsPub.Users.User

  import CommonsPub.Common.Query, only: [match_admin: 0]
  import Ecto.Query

  def query(CommonsPub.Characters.Character) do
    from(c in CommonsPub.Characters.Character,
      as: :character
      # join: a in assoc(c, :actor),
      # as: :actor,
      # select_merge: %{preferred_username: a.preferred_username},
      # select_merge: %{canonical_url: a.canonical_url},
      # select_merge: %{signing_key: a.signing_key}
    )
  end

  def query(:count) do
    from(c in CommonsPub.Characters.Character, as: :character)
  end

  def query(q, filters), do: filter(query(q), filters)

  def queries(query, _page_opts, base_filters, data_filters, count_filters) do
    base_q = query(query, base_filters)
    data_q = filter(base_q, data_filters)
    count_q = filter(base_q, count_filters)
    {data_q, count_q}
  end

  def join_to(q, spec, join_qualifier \\ :left)

  def join_to(q, specs, jq) when is_list(specs) do
    Enum.reduce(specs, q, &join_to(&2, &1, jq))
  end

  def join_to(q, :context, jq) do
    join(q, jq, [character: c], c2 in assoc(c, :context), as: :context)
  end

  def join_to(q, {:context_follow, follower_id}, jq) do
    join(q, jq, [context: c], f in Follow,
      as: :context_follow,
      on: c.id == f.context_id and f.creator_id == ^follower_id
    )
  end

  def join_to(q, {:follow, follower_id}, jq) do
    join(q, jq, [character: c], f in Follow,
      as: :follow,
      on: c.id == f.context_id and f.creator_id == ^follower_id
    )
  end

  def join_to(q, :follower_count, jq) do
    join(q, jq, [character: c], f in FollowerCount,
      on: c.id == f.context_id,
      as: :follower_count
    )
  end

  ### filter/2

  ## by many

  def filter(q, filters) when is_list(filters) do
    Enum.reduce(filters, q, &filter(&2, &1))
  end

  ## by preset

  def filter(q, :default) do
    filter(q, deleted: false)
  end

  ## by join

  def filter(q, {:join, {join, qual}}), do: join_to(q, join, qual)
  def filter(q, {:join, join}), do: join_to(q, join)

  ## by user

  def filter(q, {:user, match_admin()}), do: q

  def filter(q, {:user, %User{id: id} = _user}) do
    q
    |> join_to(follow: id)
    |> where([character: o, follow: f], not is_nil(o.published_at) or not is_nil(f.id))
  end

  def filter(q, {:user, nil}) do
    filter(q, ~w(deleted disabled private)a)
  end

  ## by status

  def filter(q, {:select, :delete}) do
    select(q, [character: c], %{id: c.id, inbox_id: c.inbox_id, outbox_id: c.outbox_id})
  end

  def filter(q, {:deleted, false}), do: where(q, [character: c], is_nil(c.deleted_at))
  def filter(q, {:deleted, true}), do: where(q, [character: c], not is_nil(c.deleted_at))
  def filter(q, {:deleted, nil}), do: where(q, [character: c], is_nil(c.deleted_at))
  def filter(q, {:deleted, :not_nil}), do: where(q, [character: c], not is_nil(c.deleted_at))

  def filter(q, :disabled) do
    where(q, [character: o], is_nil(o.disabled_at))
  end

  def filter(q, :private) do
    where(q, [character: o], not is_nil(o.published_at))
  end

  ## by field values

  def filter(q, {:cursor, [followers: {:gte, [count, id]}]})
      when is_integer(count) and is_binary(id) do
    where(
      q,
      [character: c, follower_count: fc],
      (fc.count == ^count and c.id >= ^id) or fc.count > ^count
    )
  end

  def filter(q, {:cursor, [followers: {:lte, [count, id]}]})
      when is_integer(count) and is_binary(id) do
    where(
      q,
      [character: c, follower_count: fc],
      (fc.count == ^count and c.id <= ^id) or fc.count < ^count
    )
  end

  def filter(q, {:id, id}) when is_binary(id) do
    where(q, [character: c], c.id == ^id)
  end

  def filter(q, {:id, %{id: id}}) when is_binary(id) do
    where(q, [character: c], c.id == ^id)
  end

  def filter(q, {:id, ids}) when is_list(ids) do
    where(q, [character: c], c.id in ^ids)
  end

  def filter(q, {:context_id, id}) when is_binary(id) do
    where(q, [character: c], c.context_id == ^id)
  end

  def filter(q, {:context_id, ids}) when is_list(ids) do
    where(q, [character: c], c.context_id in ^ids)
  end

  def filter(q, {:username, username}) when is_binary(username) do
    where(q, [character: a], a.preferred_username == ^username)
  end

  def filter(q, {:username, usernames}) when is_list(usernames) do
    where(q, [character: a], a.preferred_username in ^usernames)
  end

  ## by ordering

  def filter(q, {:order, :followers_desc}) do
    filter(q, order: [desc: :followers])
  end

  def filter(q, {:order, [desc: :followers]}) do
    order_by(q, [character: c, follower_count: fc],
      desc: coalesce(fc.count, 0),
      desc: c.id
    )
  end

  # grouping and counting

  def filter(q, {:group_count, key}) when is_atom(key) do
    filter(q, group: key, count: key)
  end

  def filter(q, {:group, key}) when is_atom(key) do
    group_by(q, [character: c], field(c, ^key))
  end

  def filter(q, {:count, key}) when is_atom(key) do
    select(q, [character: c], {field(c, ^key), count(c.id)})
  end

  # def filter(q, {:preload, :actor}) do
  #   preload(q, [actor: a], actor: a)
  # end

  def filter(q, {:preload, :context}) do
    preload(q, [context: c], context: c)
  end

  # pagination

  def filter(q, {:limit, limit}) do
    limit(q, ^limit)
  end

  def filter(q, {:paginate_id, %{after: a, limit: limit}}) do
    limit = limit + 2

    q
    |> where([character: c], c.id >= ^a)
    |> limit(^limit)
  end

  def filter(q, {:paginate_id, %{before: b, limit: limit}}) do
    q
    |> where([character: c], c.id <= ^b)
    |> filter(limit: limit + 2)
  end

  def filter(q, {:paginate_id, %{limit: limit}}) do
    filter(q, limit: limit + 1)
  end

  def filter(q, {:page, [desc: [followers: page_opts]]}) do
    q
    |> filter(join: :follower_count, order: [desc: :followers])
    |> page(page_opts, desc: :followers)
    |> select(
      [character: c, follower_count: fc],
      %{c | follower_count: coalesce(fc.count, 0)}
    )
  end

  def filter(q, {:peer, nil}), do: where(q, [character: a], is_nil(a.peer_id))
  def filter(q, {:peer, :not_nil}), do: where(q, [character: a], not is_nil(a.peer_id))
  def filter(q, {:peer, id}) when is_binary(id), do: where(q, [character: a], a.peer_id == ^id)
  def filter(q, {:peer, ids}) when is_list(ids), do: where(q, [character: a], a.peer_id in ^ids)

  defp page(q, %{after: cursor, limit: limit}, desc: :followers) do
    filter(q, cursor: [followers: {:lte, cursor}], limit: limit + 2)
  end

  defp page(q, %{before: cursor, limit: limit}, desc: :followers) do
    filter(q, cursor: [followers: {:gte, cursor}], limit: limit + 2)
  end

  defp page(q, %{limit: limit}, _), do: filter(q, limit: limit + 1)
end
