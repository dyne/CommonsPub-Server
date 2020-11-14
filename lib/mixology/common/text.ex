defmodule CommonsPub.Utils.Text do
  @truncate_ending "..."

  def blank?(str_or_nil), do: "" == str_or_nil |> to_string() |> String.trim()

  def truncate(text, max_length \\ 250), do: truncate(text, max_length, @truncate_ending)

  def truncate(text, max_length, omission) do
    text = String.trim(text)

    if String.length(text) < max_length do
      text
    else
      length_with_omission = max_length - String.length(omission)
      String.slice(text, 0, length_with_omission) <> omission
    end
  end

  def human_trim(input, length \\ 250) do
    input
    |> String.trim()
    |> String.split()
    |> fill_to(length)
  end

  # defp fill_to(word_list, length) when length > do
  #   IO.inspect(word_list)
  #   IO.inspect(length)
  #   # if String.length(List.(word_list))
  # end

  defp fill_to(word_list, length) do
    fill_to(word_list, length, {[], 0})
  end

  defp fill_to([head | []], length, {[], _}) do
    String.slice(head, 0..(length - 1)) <> @truncate_ending
  end

  defp fill_to([head | tail], length, {str, cur_length}) do
    new_length = cur_length + String.length(head)

    if new_length >= length do
      Enum.join(str, " ")
    else
      fill_to(tail, length, {str ++ [head], new_length})
    end
  end
end
