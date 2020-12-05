# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Uploads do
  alias Ecto.Changeset
  alias CommonsPub.Repo
  alias CommonsPub.Users.User

  alias CommonsPub.Uploads.{
    Content,
    ContentUpload,
    ContentUploadQueries,
    ContentMirror,
    ContentMirrorQueries,
    FileDenied,
    Storage,
    Queries
  }

  def one(filters), do: Repo.single(Queries.query(Content, filters))

  def many(filters \\ []), do: {:ok, Repo.all(Queries.query(Content, filters))}

  @doc """
  Attempt to store a file, returning an upload, for any parent item that
  participates in the meta abstraction, providing the actor responsible for
  the upload.
  """
  @spec upload(upload_def :: any, uploader :: User.t(), file :: any, attrs :: map) ::
          {:ok, Content.t()} | {:error, Changeset.t()}
  def upload(upload_def, uploader, file, attrs) do
    file = CommonsPub.Utils.Web.CommonHelper.input_to_atoms(file)
    # IO.inspect(upload: file)

    with {:ok, file} <- parse_file(file),
         :ok <- allow_media_type(upload_def, file),
         {:ok, content} <- insert_content(upload_def, uploader, file, attrs),
         {:ok, url} <- remote_url(content) do
          content = %{content | url: url}
          # IO.inspect(content: content)
      {:ok, content}
    end
  end

  defp insert_content(upload_def, uploader, %{} = file, attrs) do
    attrs = Map.merge(file, attrs)

    # FIXME: delegate to Storage
    Repo.transact_with(fn ->
      if is_remote_file?(file) do
        insert_content_mirror(uploader, attrs)
      else
        insert_content_upload(upload_def, uploader, attrs)
      end
    end)
  end

  defp insert_content(_, _, nil, attrs) do
    attrs
  end

  defp insert_content_mirror(uploader, %{url: url} = attrs) when is_binary(url) and url != "" do
    attrs = %{attrs | url: url |> CommonsPub.Utils.File.ensure_valid_url()}

    with {:ok, mirror} <- Repo.insert(ContentMirror.changeset(attrs)),
         {:ok, content} <- Repo.insert(Content.mirror_changeset(mirror, uploader, attrs)) do
      {:ok, %{content | content_mirror: mirror}}
    end
  end

  defp insert_content_mirror(_, _) do
    {:ok, nil}
  end

  defp insert_content_upload(upload_def, uploader, attrs) do
    storage_opts = [scope: uploader.id]

    with {:ok, file_info} <- Storage.store(upload_def, attrs, storage_opts) do
      attrs =
        attrs
        |> Map.put(:path, file_info.path)
        |> Map.put(:size, file_info.info.size)

      with {:ok, upload} <- Repo.insert(ContentUpload.changeset(attrs)),
           {:ok, content} <- Repo.insert(Content.upload_changeset(upload, uploader, attrs)) do
        {:ok, %{content | content_upload: upload}}
      else
        e ->
          # rollback file changes on failure
          Storage.delete(file_info.path)
          e
      end
    end
  end

  @doc """
  Attempt to fetch a remotely accessible URL for the associated file in an upload.
  """
  def remote_url(%Content{content_mirror: mirror, content_mirror_id: id}) when is_binary(id),
    do: {:ok, mirror.url}

  def remote_url(%Content{content_upload: upload, content_upload_id: id}) when is_binary(id),
    do: Storage.remote_url(upload.path)

  def remote_url_from_id(content_id) when is_binary(content_id) do
    case __MODULE__.one(id: content_id) do
      {:ok, content} ->
        {:ok, url} = remote_url(content)
        url

      _ ->
        nil
    end
  end

  def remote_url_from_id(_), do: nil

  def update_by(filters, updates) do
    Repo.update_all(Queries.query(Content, filters), set: updates)
  end

  def update_by(ContentMirror, filters, updates) do
    Repo.update_all(ContentMirrorQueries.query(ContentMirror, filters), set: updates)
  end

  def update_by(ContentUpload, filters, updates) do
    Repo.update_all(ContentUploadQueries.query(ContentUpload, filters), set: updates)
  end

  @doc """
  Delete an upload, removing it from indexing, but the files remain available.
  """
  @spec soft_delete(Content.t()) :: {:ok, Content.t()} | {:error, Changeset.t()}
  def soft_delete(%Content{} = content) do
    CommonsPub.Common.Deletion.soft_delete(content)
  end

  # def soft_delete_by(filters) do

  # end

  # def soft_delete_by(ContentMirror, filters) do
  # end

  # def soft_delete_by(ContentUpload, filters) do
  # end

  @doc """
  Delete an upload, removing any associated files.
  """
  @spec hard_delete(Content.t()) :: :ok | {:error, Changeset.t()}
  def hard_delete(%Content{} = content) do
    resp =
      Repo.transaction(fn ->
        with {:ok, content} <- Repo.delete(content),
             {:ok, _} <- Storage.delete(content.content_upload.path) do
          :ok
        end
      end)

    with {:ok, v} <- resp, do: v
  end

  # Sweep deleted content
  @doc false
  def hard_delete() do
    {_, work} = delete_by(deleted: true)

    {mirrors, uploads} =
      Enum.reduce(work, {[], []}, fn item, {mirrors, uploads} ->
        case item do
          %{content_mirror_id: nil, content_upload_id: nil} -> {mirrors, uploads}
          %{content_mirror_id: m, content_upload_id: nil} -> {[m | mirrors], uploads}
          %{content_mirror_id: nil, content_upload_id: u} -> {mirrors, [u | uploads]}
          %{content_mirror_id: m, content_upload_id: u} -> {[m | mirrors], [u | uploads]}
        end
      end)

    delete_by(ContentMirror, id: mirrors)
    delete_by(ContentUpload, id: uploads)
  end

  defp delete_by(filters) do
    Queries.query(Content)
    |> Queries.filter(filters)
    |> Repo.delete_all()
  end

  defp delete_by(ContentMirror, filters) do
    ContentMirrorQueries.query(ContentMirror)
    |> ContentMirrorQueries.filter(filters)
    |> Repo.delete_all()
  end

  defp delete_by(ContentUpload, filters) do
    ContentUploadQueries.query(ContentUpload)
    |> ContentUploadQueries.filter(filters)
    |> Repo.delete_all()
  end

  defp is_remote_file?(%{url: url}), do: is_remote_file?(url)

  defp is_remote_file?(url) when is_binary(url) do
    uri = URI.parse(url)
    not is_nil(uri.host)
  end

  defp is_remote_file?(_other), do: false

  defp parse_file(%{url: url, upload: upload})
       when is_binary(url) and url != "" and not is_nil(upload) do
    {:error, :both_url_and_upload_should_not_be_set}
  end

  if Mix.env() == :test do
    # FIXME: seriously don't do this, send help
    defp parse_file(%{url: url} = file) when is_binary(url) do
      {:ok, file_info} = CommonsPub.MockFileParser.from_uri(url)
      {:ok, Map.merge(file, file_info)}
    end
  else
    defp parse_file(%{url: url} = file) when is_binary(url) and url != "" do
      with {:ok, file_info} <- TwinkleStar.from_uri(url, follow_redirect: true) do
        {:ok, Map.merge(file, file_info)}
      else
        # match behaviour of uploads
        {:error, {:request_failed, 404}} -> {:error, :enoent}
        {:error, {:request_failed, 403}} -> {:error, :forbidden}
        {:error, :bad_request} -> {:error, :bad_request}
        {:error, {:tls_alert, _}} -> {:error, :tls_alert}
        {:error, other} -> {:error, other}
      end
    end
  end

  defp parse_file(%{upload: %{path: path} = file}) do
    with {:ok, file_info} <- TwinkleStar.from_filepath(path) do
      file =
        file
        |> Map.take([:path, :filename])
        |> Map.merge(file_info)

      {:ok, file}
    end
  end

  # defp parse_file(_), do: {:error, :missing_url_or_upload}
  defp parse_file(_), do: {:ok, nil}

  defp allow_media_type(upload_def, %{media_type: media_type}) do
    media_types = allowed_media_types(upload_def)

    case media_types do
      :all ->
        :ok

      allowed ->
        if media_type in allowed do
          :ok
        else
          {:error, FileDenied.new(media_type)}
        end
    end
  end

  defp allow_media_type(_upload_def, nil) do
    :ok
  end

  def allowed_media_types(upload_def) do
    CommonsPub.Config.get([upload_def, :allowed_media_types])
  end

  def max_file_size() do
    {size, ""} =
      CommonsPub.Config.get([__MODULE__, :max_file_size])
      |> Integer.parse()

    size
  end

  def base_url() do
    CommonsPub.Config.get([__MODULE__, :base_url])
  end

  def prepend_url(url) do
    base_url()
    |> URI.merge(url)
    |> URI.to_string()
  end
end
