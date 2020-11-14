# SPDX-License-Identifier: AGPL-3.0-only
defmodule Measurement.Measure.Queries do
  import CommonsPub.Common.Query, only: [match_admin: 0]
  import Ecto.Query
  alias CommonsPub.Repo
  alias CommonsPub.Users.User
  alias Measurement.{Measure, Unit}

  def query(Measure) do
    from(c in Measure, as: :measure)
  end

  def query(:count) do
    from(c in Measure, as: :measure)
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

  ### filter/2

  ## by many

  def filter(q, filters) when is_list(filters) do
    Enum.reduce(filters, q, &filter(&2, &1))
  end

  ## by preset

  def filter(q, :default) do
    filter(q, [:deleted])
  end

  ## by join

  def filter(q, {:join, {join, qual}}), do: join_to(q, join, qual)
  def filter(q, {:join, join}), do: join_to(q, join)

  ## by user

  def filter(q, {:user, match_admin()}), do: q

  def filter(q, {:user, %User{id: _id}}) do
    q
    |> where([measure: c], not is_nil(c.published_at))
    |> filter(~w(disabled)a)
  end

  def filter(q, {:user, nil}) do
    q
    |> filter(~w(disabled private)a)
  end

  ## by unit

  def filter(q, {:unit, %Unit{id: id}}) do
    where(q, [measure: c], c.unit_id == ^id)
  end

  ## by status

  def filter(q, :deleted) do
    where(q, [measure: c], is_nil(c.deleted_at))
  end

  def filter(q, :disabled) do
    where(q, [measure: c], is_nil(c.disabled_at))
  end

  def filter(q, :private) do
    where(q, [measure: c], not is_nil(c.published_at))
  end

  ## by field values


  def filter(q, {:id, id}) when is_binary(id) do
    where(q, [measure: c], c.id == ^id)
  end

  def filter(q, {:id, ids}) when is_list(ids) do
    where(q, [measure: c], c.id in ^ids)
  end

  ## by ordering

  def filter(q, {:order, :id}) do
    filter(q, order: [desc: :id])
  end

  def filter(q, {:order, [desc: :id]}) do
    order_by(q, [measure: c, id: id],
      desc: coalesce(id.count, 0),
      desc: c.id
    )
  end

  # grouping and counting

  def filter(q, {:group_count, key}) when is_atom(key) do
    filter(q, group: key, count: key)
  end

  def filter(q, {:group, key}) when is_atom(key) do
    group_by(q, [measure: c], field(c, ^key))
  end

  def filter(q, {:count, key}) when is_atom(key) do
    select(q, [measure: c], {field(c, ^key), count(c.id)})
  end

  # defp page(q, %{limit: limit}, _), do: filter(q, limit: limit + 1)

  def inc_quantity(id, amount) do
    from(r in Measure,
      update: [inc: [has_numerical_value: ^amount]],
      where: r.id == ^id
    )
    |> Repo.update_all([])
  end

end
