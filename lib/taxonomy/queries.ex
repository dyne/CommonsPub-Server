# MoodleNet: Connecting and empowering educators worldwide
# Copyright © 2018-2019 Moodle Pty Ltd <https://moodle.com/moodlenet/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Taxonomy.TaxonomyTag.Queries do
  import Ecto.Query

  alias Taxonomy.TaxonomyTag

  def query(TaxonomyTag) do
    from t in TaxonomyTag, as: :tag,
      left_join: c in assoc(t, :character), as: :character
  end

  def query(:count) do
    from c in TaxonomyTag, as: :tag
  end

  def query(q, filters), do: filter(query(q), filters)

  def queries(query, base_filters, data_filters, count_filters) do
    base_q = query(query, base_filters)
    data_q = filter(base_q, data_filters)
    count_q = filter(base_q, count_filters)
    {data_q, count_q}
  end

  def join_to(q, table_or_tables, jq \\ :left)

  ## many

  def join_to(q, tables, jq) when is_list(tables) do
    Enum.reduce(tables, q, &join_to(&2, &1, jq))
  end


  @doc "Filter the query according to arbitrary criteria"
  def filter(q, filter_or_filters)

  ## many

  def filter(q, filters) when is_list(filters) do
    Enum.reduce(filters, q, &filter(&2, &1))
  end

  ## by join

  def filter(q, {:join, {rel, jq}}), do: join_to(q, rel, jq)

  def filter(q, {:join, rel}), do: join_to(q, rel)

  ## by field values

  def filter(q, {:id, id}) when is_integer(id) do
    where q, [tag: f], f.id == ^id
  end

  def filter(q, {:id, ids}) when is_list(ids) do
    where q, [tag: f], f.id in ^ids
  end

  def filter(q, {:label, label}) when is_binary(label) do
    where q, [tag: f], f.label == ^label
  end

  def filter(q, {:id, id}) when is_binary(id), do: where(q, [tag: c], c.id == ^id)
  def filter(q, {:id, ids}) when is_list(ids), do: where(q, [tag: c], c.id in ^ids)

  # get children in taxonomy
  def filter(q, {:parent_tag, id}) when is_integer(id), do: where(q, [tag: t], t.parent_tag_id == ^id)
  def filter(q, {:parent_tag, ids}) when is_list(ids), do: where(q, [tag: t], t.parent_tag_id in ^ids)

  # get children with character
  def filter(q, {:context, id}) when is_binary(id), do: where(q, [tag: t, character: c], c.context_id == ^id)
  def filter(q, {:context, ids}) when is_list(ids), do: where(q, [tag: t, character: c], c.context_id in ^ids)

  # join with character
  def filter(q, :default) do
    filter q, [preload: :character]
  end

  def filter(q, {:preload, :character}) do
    preload q, [character: c], character: c
  end

  def filter(q, {:user, user}), do: q

end
