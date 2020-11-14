defmodule CommonsPub.HTML.Scrubber.MediaProxy do
  @moduledoc "Transforms inline image URIs to use MediaProxy."

  # def before_scrub(html), do: html

  # def scrub_attribute(:img, {"src", "http" <> target}) do
  #   media_url =
  #     ("http" <> target)
  #     |> Pleroma.Web.MediaProxy.url()

  #   {"src", media_url}
  # end

  # def scrub_attribute(_tag, attribute), do: attribute

  # def scrub({:img, attributes, children}) do
  #   attributes =
  #     attributes
  #     |> Enum.map(fn attr -> scrub_attribute(:img, attr) end)
  #     |> Enum.reject(&is_nil(&1))

  #   {:img, attributes, children}
  # end

  # def scrub({:comment, _text, _children}), do: ""

  # def scrub({tag, attributes, children}), do: {tag, attributes, children}
  # def scrub({_tag, children}), do: children
  # def scrub(text), do: text
end
