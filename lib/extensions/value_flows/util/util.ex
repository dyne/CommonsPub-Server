# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Util do
  # def try_tag_thing(user, thing, attrs) do
  #   IO.inspect(attrs)
  # end

  @doc """
  lookup tag from URL(s), to support vf-graphql mode
  """

  # def try_tag_thing(_user, thing, %{resource_classified_as: urls})
  #     when is_list(urls) and length(urls) > 0 do
  #   # todo: lookup tag by URL
  #   {:ok, thing}
  # end

  def try_tag_thing(user, thing, tags) do
    CommonsPub.Tag.TagThings.try_tag_thing(user, thing, tags)
  end

  def image_url(%{profile_id: profile_id} = thing) when not is_nil(profile_id) do
    CommonsPub.Repo.maybe_preload(thing, :profile)
    |> Map.get(:profile)
    |> image_url()
  end

  def image_url(%{icon_id: icon_id} = thing) when not is_nil(icon_id) do
    CommonsPub.Repo.maybe_preload(thing, [icon: [:content_upload, :content_mirror]])
    # |> IO.inspect()
    |> Map.get(:icon)
    |> content_url_or_path()
  end

  def image_url(%{image_id: image_id} = thing) when not is_nil(image_id) do
    # IO.inspect(thing)
    CommonsPub.Repo.maybe_preload(thing, [image: [:content_upload, :content_mirror]])
    |> Map.get(:image)
    |> content_url_or_path()
  end

  def image_url(_) do
    nil
  end

  def content_url_or_path(content) do
    CommonsPub.Utils.Web.CommonHelper.e(
      content,
      :content_upload,
      :path,
      CommonsPub.Utils.Web.CommonHelper.e(content, :content_mirror, :url, nil)
    )
  end

  def handle_changeset_errors(cs, attrs, fn_list) do
    Enum.reduce_while(fn_list, cs, fn cs_handler, cs ->
      case cs_handler.(cs, attrs) do
        {:error, reason} -> {:halt, {:error, reason}}
        cs -> {:cont, cs}
      end
    end)
    |> case do
      {:error, _} = e -> e
      cs -> {:ok, cs}
    end
  end
end
