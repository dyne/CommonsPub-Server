# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.UploadsTest do
  use CommonsPub.DataCase, async: true

  import CommonsPub.Utils.Simulation
  alias CommonsPub.Utils.Simulation
  alias CommonsPub.Uploads
  alias CommonsPub.Uploads.{FileDenied, Storage}

  @image_file %{path: "test/fixtures/images/150.png", filename: "150.png"}

  def fake_upload(file) do
    user = fake_user!()

    upload_def =
      Faker.Util.pick([
        CommonsPub.Uploads.IconUploader,
        CommonsPub.Uploads.ImageUploader,
        CommonsPub.Uploads.ResourceUploader
      ])

    Uploads.upload(upload_def, user, %{upload: file}, %{})
  end

  def strip(upload), do: Map.drop(upload, [:is_public, :url])

  describe "one" do
    test "returns an upload for an existing ID" do
      assert {:ok, original_upload} = fake_upload(@image_file)
      assert {:ok, fetched_upload} = Uploads.one(id: original_upload.id)
      assert original_upload.id == fetched_upload.id
      assert original_upload.content_upload.id == fetched_upload.content_upload.id
    end

    test "fails when given a missing ID" do
      assert {:error, %CommonsPub.Common.NotFoundError{}} = Uploads.one(id: Simulation.ulid())
    end
  end

  describe "upload" do
    test "creates a file upload" do
      assert {:ok, upload} = fake_upload(@image_file)
      assert upload.media_type == "image/png"
      assert upload.content_upload.path
      assert upload.content_upload.size
    end

    test "fails when the file has a disallowed extension" do
      file = %{path: "test/fixtures/empty.fbx", filename: "empty.fbx"}
      assert {:error, %FileDenied{}} = fake_upload(file)
    end

    test "fails when the upload is a missing file" do
      file = %{path: "missing.gif", filename: "missing.gif"}
      assert {:error, :enoent} = fake_upload(file)
    end
  end

  describe "remote_url" do
    test "returns the remote URL for an existing upload" do
      assert {:ok, upload} = fake_upload(@image_file)
      assert {:ok, url} = Uploads.remote_url(upload)

      uri = URI.parse(url)
      assert uri.scheme
      assert uri.host
      assert uri.path
    end
  end

  describe "soft_delete" do
    test "updates the deletion date of the upload" do
      assert {:ok, upload} = fake_upload(@image_file)
      refute upload.deleted_at
      assert {:ok, deleted_upload} = Uploads.soft_delete(upload)
      assert deleted_upload.deleted_at
      # file should still be available
      assert {:ok, _} = Storage.remote_url(upload.content_upload.path)
    end
  end

  describe "hard_delete" do
    test "removes the upload, including files" do
      assert {:ok, upload} = fake_upload(@image_file)
      assert :ok = Uploads.hard_delete(upload)
      assert {:error, :enoent} = Storage.remote_url(upload.content_upload.path)
    end
  end
end
