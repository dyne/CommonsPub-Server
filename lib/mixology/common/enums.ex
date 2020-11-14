# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Common.Enums do
  @moduledoc "Missing functions from Enum"

  @compile {:inline, group: 3}

  def count_where(collection, function) do
    Enum.reduce(collection, 0, fn item, count ->
      if function.(item), do: count + 1, else: count
    end)
  end

  @doc """
  Like group_by, except children are required to be unique (will throw
  otherwise!) and the resulting map does not wrap each item in a list
  """
  def group([], fun) when is_function(fun, 1), do: %{}

  def group(list, fun)
      when is_list(list) and is_function(fun, 1),
      do: group(list, %{}, fun)

  defp group([x | xs], acc, fun), do: group(xs, group_item(fun.(x), x, acc), fun)
  defp group([], acc, _), do: acc

  defp group_item(key, value, acc)
       when not is_map_key(acc, key),
       do: Map.put(acc, key, value)

  def group_map([], fun) when is_function(fun, 1), do: %{}

  def group_map(list, fun)
      when is_list(list) and is_function(fun, 1),
      do: group_map(list, %{}, fun)

  defp group_map([x | xs], acc, fun), do: group_map(xs, group_map_item(fun.(x), acc), fun)
  defp group_map([], acc, _), do: acc

  defp group_map_item({key, value}, acc)
       when not is_map_key(acc, key),
       do: Map.put(acc, key, value)
end
