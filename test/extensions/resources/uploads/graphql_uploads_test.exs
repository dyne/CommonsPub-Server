# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.UploadsTest do
  use CommonsPub.Web.ConnCase, async: true

  # import CommonsPub.Utils.Simulation
  # import CommonsPub.Web.Test.ConnHelpers
  # import CommonsPub.Web.Test.GraphQLAssertions
  # import CommonsPub.Web.Test.GraphQLFields
  # import Grumble
  # alias CommonsPub.Uploads.Storage

  # @image_file %{
  #   path: "test/fixtures/images/150.png",
  #   filename: "150.png",
  #   content_type: "image/png"
  # }
  # @image_url "https://upload.wikimedia.org/wikipedia/commons/e/e9/South_African_Airlink_Boeing_737-200_Advanced_Smith.jpg"

  # def assert_content(content) do
  #   assert content["id"]
  #   assert_url content["url"]
  # end

  # def assert_content_upload(content, file) do
  #   assert content["mediaType"] == file.content_type
  #   assert content["upload"]["path"]
  #   assert content["upload"]["size"] > 0
  # end

  # def assert_content_mirror(content, url) do
  #   assert content["mirror"]["url"] == url
  #   assert content["mirror"]["url"] == content["url"]
  # end

  # setup_all do
  #   on_exit(fn ->
  #     Storage.delete_all()
  #   end)
  # end

  # describe "content.uploader" do
  #   test "returns the uploader for a content item" do
  #     user = fake_user!()
  #     query = upload_mutation(:upload_icon, fields: [uploader: [:id]])
  #     conn = user_conn(user)

  #     assert %{"uploader" => uploader} =
  #       grumble_post_key(query, conn, :upload_icon, %{context_id: user.id, upload: @image_file})

  #     assert uploader["id"] == user.id
  #   end
  # end

  # describe "content.url" do
  #   test "returns the remote URL for an upload" do
  #     user = fake_user!()
  #     query = upload_mutation(:upload_icon)
  #     conn = user_conn(user)

  #     assert content =
  #       grumble_post_key(query, conn, :upload_icon, %{context_id: user.id, upload: @image_file})
  #     assert_url content["url"]
  #   end

  #   test "returns the remote URL for a mirror" do
  #     user = fake_user!()
  #     query = upload_mutation(:upload_icon)
  #     conn = user_conn(user)

  #     params = %{context_id: user.id, upload: %{url: @image_url}}
  #     assert content = grumble_post_key(query, conn, :upload_icon, params)
  #     assert_content(content)
  #     assert_content_mirror(content, get_in(params, [:upload, :url]))
  #   end
  # end
end
