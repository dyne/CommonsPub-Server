# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule CommonsPub.HTML.Scrubber do
  # TBD: Scrubbers may need to be compiled on boot so they can be configured in OTP releases
  #  @on_load :compile_scrubbers

  # def compile_scrubbers do
  #   dir = Path.join(:code.priv_dir(:commons_pub), "scrubbers")

  #   dir
  #   |> CommonsPub.ReleaseTasks.compile_dir()
  #   |> case do
  #     {:error, _errors, _warnings} ->
  #       raise "Compiling scrubbers failed"

  #     {:ok, _modules, _warnings} ->
  #       :ok
  #   end
  # end

  @default_scrubber HtmlSanitizeEx.Scrubber.MarkdownHTML

  # @default_scrubber CommonsPub.HTML.Scrubber.SomeFormatting

  defp get_scrubbers(scrubber) when is_atom(scrubber), do: [scrubber]
  defp get_scrubbers(scrubbers) when is_list(scrubbers), do: scrubbers
  defp get_scrubbers(_), do: [@default_scrubber]

  def get_scrubbers do
    CommonsPub.Config.get([:markup, :scrub_policy], [
      @default_scrubber
      # CommonsPub.HTML.Transform.MediaProxy
    ])
    |> get_scrubbers
  end

  def scrub_html(content) when is_binary(content) do
    content
    # html content comes from DB already encoded, decode first and scrub after
    |> HtmlEntities.decode()
    |> String.replace(~r/<br\s?\/?>/, " ")
    |> strip_tags()
  end

  def scrub_html(content), do: content

  # def scrub_html_and_truncate(content, max_length \\ 200)

  # def scrub_html_and_truncate(%{data: %{"content" => content}} = object, max_length) do
  #   content
  #   # if html content comes from DB already encoded, decode first and scrub after
  #   |> HtmlEntities.decode()
  #   |> String.replace(~r/<br\s?\/?>/, " ")
  #   |> get_cached_stripped_html_for_object(object, "metadata")
  #   # |> Emoji.Formatter.demojify()
  #   |> HtmlEntities.decode()
  #   |> CommonsPub.HTML.truncate(max_length)
  # end

  # def scrub_html_and_truncate(content, max_length) when is_binary(content) do
  #   content
  #   |> scrub_html
  #   # |> Emoji.Formatter.demojify()
  #   |> HtmlEntities.decode()
  #   |> CommonsPub.HTML.truncate(max_length)
  # end

  def filter_tags(html, nil) do
    filter_tags(html, get_scrubbers())
  end

  def filter_tags(html, scrubbers) when is_list(scrubbers) do
    Enum.reduce(scrubbers, html, fn scrubber, html ->
      filter_tags(html, scrubber)
    end)
  end

  def filter_tags(html, scrubber) do
    HtmlSanitizeEx.Scrubber.scrub(html, scrubber)
  end

  def filter_tags(html), do: filter_tags(html, nil)

  def strip_tags(html), do: filter_tags(html, HtmlSanitizeEx.Scrubber.StripTags)

  def get_cached_stripped_html_for_object(content, data, key) do
    get_cached_scrubbed_html(
      content,
      HtmlSanitizeEx.Scrubber.StripTags,
      data,
      key,
      &HtmlEntities.decode/1
    )
  end

  def get_cached_scrubbed_html(
        content,
        scrubbers,
        data,
        key \\ "",
        callback \\ fn x -> x end
      ) do
    key = "#{key}#{generate_scrubber_signature(scrubbers)}|#{data.id}"

    Cachex.fetch!(:scrubber_cache, key, fn _key ->
      ensure_scrubbed_html(content, scrubbers, false, callback)
    end)
  end

  def ensure_scrubbed_html(
        content,
        scrubbers,
        fake,
        callback
      ) do
    content =
      content
      |> filter_tags(scrubbers)
      |> callback.()

    if fake do
      {:ignore, content}
    else
      {:commit, content}
    end
  end

  defp generate_scrubber_signature(scrubber) when is_atom(scrubber) do
    generate_scrubber_signature([scrubber])
  end

  defp generate_scrubber_signature(scrubbers) do
    Enum.reduce(scrubbers, "", fn scrubber, signature ->
      "#{signature}#{to_string(scrubber)}"
    end)
  end

  def extract_first_external_url(_, nil), do: {:error, "No content"}

  def extract_first_external_url(object, content) do
    key = "URL|#{object.id}"

    Cachex.fetch!(:scrubber_cache, key, fn _key ->
      result =
        content
        |> Floki.parse_fragment!()
        |> Floki.filter_out("a.mention,a.hashtag,a.attachment,a[rel~=\"tag\"]")
        |> Floki.attribute("a", "href")
        |> Enum.at(0)

      {:commit, {:ok, result}}
    end)
  end
end
