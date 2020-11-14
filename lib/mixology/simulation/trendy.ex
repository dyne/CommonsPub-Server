# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Utils.Trendy do
  @moduledoc """
  Utilities for tidying up tests. Mostly things that look like they
  should belong to Enum but are quite fast and strangely specific
  about when functions are run relative to their result order.
  """

  import Zest
  alias CommonsPub.Common.Enums

  @compile {:inline, repeat_for_count: 4, noccat: 2, flat_pam: 3, flat_pam_product: 4}
  @compile {:inline, flat_pam_product2: 4, piz: 4}

  def repeat(_list, 0), do: []
  def repeat(list, 1), do: list

  def repeat(list, times) when is_integer(times) and times > 1 do
    Enum.reduce(2..times, list, fn _, acc -> list ++ acc end)
  end

  def repeat_for_count(_list, 0), do: []

  def repeat_for_count(list, count)
      when is_integer(count) and count > 0,
      do: repeat_for_count(list, list, [], count)

  defp repeat_for_count(_working, _template, acc, 0), do: acc

  defp repeat_for_count([work | working], template, acc, count),
    do: repeat_for_count(working, template, [work | acc], count - 1)

  defp repeat_for_count([], template, acc, count),
    do: repeat_for_count(template, template, acc, count)

  @doc """
  A very fast list prepend where the reverse of the left list is
  prepended to the right list.
  """
  @spec noccat([term], [term]) :: term
  def noccat([x | xs], acc), do: noccat(xs, [x | acc])
  def noccat([], acc), do: acc

  @doc """
  A very fast map where the function is called in list order but the
  results come out in reverse order
  """
  def pam([], fun) when is_function(fun, 1), do: []
  def pam(list, fun) when is_list(list) and is_function(fun, 1), do: pam(list, [], fun)

  defp pam([x | xs], acc, fun), do: pam(xs, [fun.(x) | acc], fun)
  defp pam([], acc, _), do: acc

  @doc """
  A very fast flatmap where the results come out backwards
  """
  def flat_pam([], fun) when is_function(fun, 1), do: []

  def flat_pam(list, fun)
      when is_list(list) and
             is_function(fun, 1),
      do: flat_pam(list, [], fun)

  defp flat_pam([x | xs], acc, fun), do: flat_pam(xs, noccat(fun.(x), acc), fun)
  defp flat_pam([], acc, _), do: acc

  @doc """
  Perform the cartesian product of two lists, calling the provided
  function once per pair and returning the results as a list.

  Note: O(n*m), do not use for large lists!
  """
  @spec map_product([term], [term], (term, term -> term)) :: [term]
  def map_product(as, bs, fun) when is_function(fun, 2) do
    for a <- as, b <- bs do
      fun.(a, b)
    end
  end

  @doc """
  Perform the cartesian product of two lists, calling the provided
  function once per pair and concatenating the results.

  Note: O(n*m), do not use for large lists!
  """
  def flat_map_product(as, bs, fun) when is_function(fun, 2) do
    Enum.flat_map(as, fn a ->
      Enum.flat_map(bs, fn b ->
        fun.(a, b)
      end)
    end)
  end

  @doc """
  Perform the cartesian product of two lists, calling the provided
  function once per pair and returning the reverse of concatenating
  the results.

  Note: O(n*m), do not use for large lists!
  """
  def flat_pam_product(as, bs, fun) when is_function(fun, 2) do
    flat_pam_product(as, bs, [], fun)
  end

  # input: [1,2], [3,4]
  # call order [1,3], [1,4], [2,3], [2,4]
  defp flat_pam_product([a | as], bs, acc, fun) do
    flat_pam_product(as, bs, flat_pam_product2(bs, acc, a, fun), fun)
  end

  defp flat_pam_product([], _, acc, _), do: acc

  defp flat_pam_product2([b | bs], acc, a, fun) do
    flat_pam_product2(bs, noccat(fun.(a, b), acc), a, fun)
  end

  defp flat_pam_product2([], acc, _, _), do: acc

  def group(list, fun), do: Enums.group(list, fun)

  # this is hurrendous
  def zip(as, bs, fun) do
    Enum.map(Enum.zip(as, bs), fn {a, b} -> fun.(a, b) end)
  end

  @doc """
  A zip where the provided fn is executed in list order and
  results are returned in reverse list order
  """
  def piz(as, bs, fun)
      when is_function(fun, 2) and
             is_list(as) and
             is_list(bs),
      do: piz(as, bs, [], fun)

  defp piz([a | as], [b | bs], acc, fun), do: piz(as, bs, [fun.(a, b) | acc], fun)
  defp piz(_, _, acc, _), do: acc

  def unpiz(list), do: unpiz(list, [], [])

  defp unpiz([], as, bs), do: {as, bs}
  defp unpiz([{a, b} | abs], as, bs), do: unpiz(abs, [a | as], [b | bs])

  @doc """
  Drops the first drop elements of as and each with bs using fun.
  """
  def drop_each(as, bs, drop, fun), do: each(Enum.drop(as, drop), bs, fun)

  @doc """
  Repeats a function count times if count_or_range is a positive integer.

  If count_or_range is a positive range, a random number from this
  range is selected and that value used as a count
  """
  def some(count_or_range \\ 1, fun)

  def some(count, fun)
      when is_function(fun, 0) and
             is_integer(count) and
             count > 0 do
    for _ <- 1..count do
      fun.()
    end
  end

  def some(%Range{first: first, last: last}, fun)
      when is_function(fun, 0) and
             is_integer(first) and
             is_integer(last) and
             first > 0 and
             last >= first do
    some(Faker.random_between(first, last), fun)
  end

  def flat_pam_some(as, some_arg \\ 1, fun)

  def flat_pam_some(as, some_arg, fun) do
    flat_pam(as, &some(some_arg, fn -> fun.(&1) end))
  end

  def flat_pam_product_some(as, bs, some_arg \\ 1, fun)

  def flat_pam_product_some(as, bs, some_arg, fun) do
    flat_pam_product(as, bs, fn a, b ->
      some(some_arg, fn -> fun.(a, b) end)
    end)
  end
end
