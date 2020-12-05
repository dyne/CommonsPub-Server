# SPDX-License-Identifier: AGPL-3.0-only

defmodule CommonsPub.Web.GraphQL.UploadResolver do
  alias CommonsPub.GraphQL.{
    FetchFields,
    # Fields,
    ResolveFields
  }

  alias CommonsPub.{Uploads, Users}
  alias CommonsPub.Uploads.Content

  require Logger

  @uploader_fields %{
    content: CommonsPub.Uploads.ResourceUploader,
    image: CommonsPub.Uploads.ImageUploader,
    icon: CommonsPub.Uploads.IconUploader
  }

  def upload(user, %{} = params, _info) do
    params
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Enum.reduce_while(%{}, &do_upload(user, &1, &2))
    |> case do
      {:error, _} = e -> e
      val -> {:ok, Enum.into(val, %{})}
    end
  end

  defp do_upload(user, {field_name, %Absinthe.Blueprint.Input.String{value: url}}, acc) when is_binary(url) do
    # if we are getting a string rather than a Content object, assume its a URL
    do_upload(user, {field_name, %{"url" => url}}, acc)
  end

  defp do_upload(user, {field_name, content_input}, acc) do
    uploader = @uploader_fields[field_name]

    if uploader do
      case Uploads.upload(uploader, user, content_input, %{}) do
        {:ok, content} ->
          field_id_name = String.to_existing_atom("#{field_name}_id")
          {:cont, Map.put(acc, field_id_name, content.id)}

        {:error, reason} ->
          # FIXME: delete other successful files on failure
          Logger.warn("Could not upload #{field_name}: #{reason}")

          {:halt, {:error, reason}}

        _ ->
          {:cont, acc}
      end
    else
      {:cont, acc}
    end
  end

  def icon_content_edge(%{icon_id: id}, _, info), do: content_edge(id, info)
  def icon_content_edge(_, _, _), do: {:ok, nil}

  def image_content_edge(%{image_id: id}, _, info), do: content_edge(id, info)
  def image_content_edge(_, _, _), do: {:ok, nil}

  def resource_content_edge(%{content_id: id}, _, info), do: content_edge(id, info)
  def resource_content_edge(_, _, _), do: {:ok, nil}

  def content_edge(id, info) when is_binary(id) do
    ResolveFields.run(%ResolveFields{
      module: __MODULE__,
      fetcher: :fetch_content_edge,
      context: id,
      info: info
    })
  end

  def content_edge(_, _), do: {:ok, nil}

  def fetch_content_edge(_, ids) do
    FetchFields.run(%FetchFields{
      queries: Uploads.Queries,
      query: Content,
      group_fn: & &1.id,
      filters: [deleted: false, published: true, id: ids]
    })
  end

  def is_public(%Content{} = upload, _, _info), do: {:ok, not is_nil(upload.published_at)}

  def uploader(%Content{uploader_id: id}, _, _info), do: Users.one(id: id, preset: :character)

  def remote_url(%Content{} = upload, _, _info), do: Uploads.remote_url(upload)

  def content_upload(%Content{content_upload: upload}, _, _info), do: {:ok, upload}
  def content_mirror(%Content{content_mirror: mirror}, _, _info), do: {:ok, mirror}
end
