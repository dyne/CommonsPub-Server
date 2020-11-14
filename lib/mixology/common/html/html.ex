defmodule CommonsPub.HTML do
  alias CommonsPub.Config

  alias CommonsPub.HTML.Formatter

  @doc """
  For use for things like a bio, where we want links but not to actually trigger mentions.
  """

  def parse_input(
        text,
        content_type \\ "text/plain",
        user \\ nil
      )

  def parse_input(
        text,
        content_type,
        user
      )
      when is_binary(text) and text != "" do
    options = [mentions_format: :full, user: user]
    content_type = get_content_type(content_type)

    text
    |> format_input(content_type, options)
    |> elem(0)
  end

  def parse_input(_, _, _), do: ""

  @doc """
  For use for things like a post/comment, to process the content, and get back any @/&/+ mentions and hashtags
  """
  def parse_input_and_tags(
        text,
        content_type \\ "text/plain",
        user \\ nil
      )

  def parse_input_and_tags(
        text,
        content_type,
        user
      )
      when is_binary(text) and text != "" do
    options = [tagging_save_and_publish: true, user: user]
    content_type = get_content_type(content_type)

    text
    |> format_input(content_type, options)

    # |> maybe_add_attachments(attachments, attachment_links)
    # |> maybe_add_nsfw_tag(data)
  end

  def parse_input_and_tags(text, _, _), do: {text, [], []}

  defp get_content_type(content_type) do
    if Enum.member?(
         Config.get([:instance, :allowed_post_formats], [
           "text/plain",
           "text/markdown",
           "text/html"
         ]),
         content_type
       ) do
      content_type
    else
      "text/plain"
    end
  end

  def format_input(text, format \\ "text/plain", options \\ [])

  @doc """
  Formatting text to plain text.
  """
  def format_input(text, "text/plain", options) do
    text
    |> Formatter.html_escape("text/plain")
    |> String.replace("&amp;", "&")
    |> Formatter.linkify(options)
    |> (fn {text, mentions, tags} ->
          {String.replace(text, ~r/\r?\n/, "<br>"), mentions, tags}
        end).()
  end

  @doc """
  Formatting text to html.
  """
  def format_input(text, "text/html", options) do
    text
    |> Formatter.html_escape("text/html")
    |> String.replace("&amp;", "&")
    |> Formatter.linkify(options)
  end

  @doc """
  Formatting text to markdown.
  FIXME
  """
  def format_input(text, "text/markdown", options) do
    text
    # |> Formatter.mentions_escape(options)
    # |> Earmark.as_html()
    # |> elem(1)
    |> String.replace("&amp;", "&")
    |> Formatter.linkify(options ++ [content_type: "text/markdown"])
  end

  # defp maybe_add_nsfw_tag({text, mentions, tags}, %{"sensitive" => sensitive})
  #      when sensitive in [true, "True", "true", "1"] do
  #   {text, mentions, [{"#nsfw", "nsfw"} | tags]}
  # end

  # defp maybe_add_nsfw_tag(data, _), do: data
end
