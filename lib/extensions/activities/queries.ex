# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Activities.Queries do
  alias CommonsPub.Activities.Activity
  alias CommonsPub.Meta.TableService
  import CommonsPub.Common.Query, only: [match_admin: 0]
  import Ecto.Query

  def query(Activity), do: from(a in Activity, as: :activity)

  def query(q, filters), do: filter(query(q), filters)

  def join_to(q, rel, jq \\ :left)

  def join_to(q, :context, jq),
    do: join(q, jq, [activity: a], c in assoc(a, :context), as: :context)

  def join_to(q, :feed_activity, jq) do
    join(q, jq, [activity: a], fa in assoc(a, :feed_activities), as: :feed_activity)
  end

  ### filter/2

  @doc "Filters the query according to arbitrary filters"
  def filter(q, filter_or_filters)

  def filter(q, filters) when is_list(filters), do: Enum.reduce(filters, q, &filter(&2, &1))

  def filter(q, {:feed_timeline, id}) do
    filter(q,
      join: :feed_activity,
      feed: id,
      # this does the actual ordering
      distinct: [desc: :id],
      # this is here because ecto knows better than me oslt
      order: [desc: :created],
      deleted: false,
      join: :context
    )
  end

  def filter(q, {:join, {rel, jq}}), do: join_to(q, rel, jq)
  def filter(q, {:join, rel}), do: join_to(q, rel)

  def filter(q, {:published, nil}), do: where(q, [activity: a], is_nil(a.published_at))
  def filter(q, {:published, :not_nil}), do: where(q, [activity: a], not is_nil(a.published_at))
  def filter(q, {:published, false}), do: where(q, [activity: a], is_nil(a.published_at))
  def filter(q, {:published, true}), do: where(q, [activity: a], not is_nil(a.published_at))

  def filter(q, {:published, {:gte, %DateTime{} = time}}),
    do: where(q, [activity: a], a.published_at >= ^time)

  def filter(q, {:published, {:lte, %DateTime{} = time}}),
    do: where(q, [activity: a], a.published_at <= ^time)

  def filter(q, {:user, match_admin()}), do: filter(q, deleted: false)
  def filter(q, {:user, _}), do: filter(q, deleted: false, published: true)

  def filter(q, {:deleted, nil}), do: where(q, [activity: a], is_nil(a.deleted_at))
  def filter(q, {:deleted, :not_nil}), do: where(q, [activity: a], not is_nil(a.deleted_at))
  def filter(q, {:deleted, false}), do: where(q, [activity: a], is_nil(a.deleted_at))
  def filter(q, {:deleted, true}), do: where(q, [activity: a], not is_nil(a.deleted_at))

  def filter(q, {:deleted, {:gte, %DateTime{} = time}}),
    do: where(q, [activity: a], a.deleted_at >= ^time)

  def filter(q, {:deleted, {:lte, %DateTime{} = time}}),
    do: where(q, [activity: a], a.deleted_at <= ^time)

  def filter(q, {:id, id}) when is_binary(id), do: where(q, [activity: a], a.id == ^id)
  def filter(q, {:id, {:gte, id}}) when is_binary(id), do: where(q, [activity: a], a.id >= ^id)
  def filter(q, {:id, {:lte, id}}) when is_binary(id), do: where(q, [activity: a], a.id <= ^id)
  def filter(q, {:id, ids}) when is_list(ids), do: where(q, [activity: a], a.id in ^ids)

  def filter(q, {:creator, id}) when is_binary(id),
    do: where(q, [activity: a], a.creator_id == ^id)

  def filter(q, {:creator, ids}) when is_list(ids),
    do: where(q, [activity: a], a.creator_id in ^ids)

  def filter(q, {:context, id}) when is_binary(id),
    do: where(q, [activity: a], a.context_id == ^id)

  def filter(q, {:context, ids}) when is_list(ids),
    do: where(q, [activity: a], a.context_id in ^ids)

  def filter(q, {:feed, id}) when is_binary(id),
    do: where(q, [feed_activity: fa], fa.feed_id == ^id)

  def filter(q, {:feed, ids}) when is_list(ids),
    do: where(q, [feed_activity: fa], fa.feed_id in ^ids)

  def filter(q, {:feed, _}), do: q

  def filter(q, {:table, id}) when is_binary(id), do: where(q, [context: c], c.table_id == ^id)

  def filter(q, {:table, table}) when is_atom(table),
    do: filter(q, {:table, TableService.lookup_id!(table)})

  def filter(q, {:table, tables}) when is_list(tables) do
    ids = TableService.lookup_ids!(tables)
    where(q, [context: c], c.table_id in ^ids)
  end

  def filter(q, {:page, [desc: [created: %{after: [a], limit: l}]]}) do
    filter(q, order: [desc: :created], limit: l + 2, id: {:lte, a})
  end

  def filter(q, {:page, [desc: [created: %{before: [b], limit: l}]]}) do
    filter(q, order: [desc: :created], limit: l + 2, id: {:gte, b})
  end

  def filter(q, {:page, [desc: [created: %{limit: l}]]}),
    do: filter(q, order: [desc: :created], limit: l + 1)

  # default limit (10)
  def filter(q, {:page, [desc: [created: _]]}),
    do: filter(q, order: [desc: :created], limit: 11)


  def filter(q, {:distinct, [desc: key]}) when is_atom(key),
    do: distinct(q, [activity: a], desc: field(a, ^key))

  def filter(q, {:distinct, [asc: key]}) when is_atom(key),
    do: distinct(q, [activity: a], asc: field(a, ^key))

  def filter(q, {:distinct, key}) when is_atom(key),
    do: distinct(q, [activity: a], field(a, ^key))

  def filter(q, {:group, :feed}), do: group_by(q, [feed_activity: fa], fa.feed_id)
  def filter(q, {:group, key}) when is_atom(key), do: group_by(q, [activity: a], field(a, ^key))

  def filter(q, {:order, [desc: :created]}), do: order_by(q, [activity: a], desc: a.id)

  def filter(q, {:limit, n}) when is_integer(n), do: limit(q, ^n)

  def filter(q, {:preload, :context}), do: preload(q, [context: c], context: c)

  # deletion

  def filter(q, {:select, :id}), do: select(q, [activity: a], [a.id])

  def filter(q, :delete) do
    now = DateTime.utc_now()
    update(q, set: [deleted_at: ^now])
  end
end
