# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Uploads.Content do
  use CommonsPub.Common.Schema
  import CommonsPub.Common.Changeset, only: [change_public: 1]

  alias Ecto.Changeset
  alias CommonsPub.Users.User
  alias CommonsPub.Uploads.{ContentMirror, ContentUpload}

  @type t :: %__MODULE__{}

  table_schema "mn_content" do
    # has_one(:preview, __MODULE__)
    belongs_to(:uploader, User)
    belongs_to(:content_mirror, ContentMirror)
    belongs_to(:content_upload, ContentUpload)
    field(:url, :string, virtual: true)
    field(:media_type, :string)
    field(:metadata, :map)
    field(:is_public, :boolean, virtual: true)
    field(:published_at, :utc_datetime_usec)
    field(:deleted_at, :utc_datetime_usec)
    timestamps(inserted_at: :created_at)
  end

  @create_cast ~w(media_type metadata is_public)a
  @create_required ~w(media_type)a

  def mirror_changeset(%ContentMirror{} = mirror, uploader, attrs) do
    common_changeset(uploader, attrs)
    |> Changeset.change(content_mirror_id: mirror.id)
  end

  def upload_changeset(%ContentUpload{} = upload, uploader, attrs) do
    common_changeset(uploader, attrs)
    |> Changeset.change(content_upload_id: upload.id)
  end

  defp common_changeset(uploader, attrs) do
    %__MODULE__{}
    |> Changeset.cast(attrs, @create_cast)
    |> Changeset.validate_required(@create_required)
    |> Changeset.validate_length(:media_type, max: 256)
    |> Changeset.change(
      is_public: true,
      uploader_id: CommonsPub.Common.maybe_get(uploader, :id)
    )
    |> change_public()
  end
end
