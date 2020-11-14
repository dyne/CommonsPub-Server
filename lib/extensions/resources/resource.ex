# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Resources.Resource do
  use CommonsPub.Common.Schema

  import CommonsPub.Common.Changeset,
    only: [change_public: 1, change_disabled: 1, cast_object: 1]

  alias Ecto.Changeset
  alias CommonsPub.Collections.Collection
  alias CommonsPub.Resources
  alias CommonsPub.Resources.Resource
  alias CommonsPub.Uploads.Content
  alias CommonsPub.Users.User

  table_schema "mn_resource" do
    belongs_to(:creator, User)

    # replaced by context
    # belongs_to(:collection, Collection)
    # field(:collection_id, :string, virtual: true)
    # field(:community_id, :string, virtual: true)
    belongs_to(:community, Community, foreign_key: :context_id, define_field: false)
    belongs_to(:collection, Collection, foreign_key: :context_id, define_field: false)

    belongs_to(:context, Pointers.Pointer)

    belongs_to(:content, Content)
    belongs_to(:icon, Content)

    # belongs_to(:primary_language, Language, type: :binary)

    field(:canonical_url, :string)

    field(:name, :string)
    field(:summary, :string)

    field(:license, :string)

    field(:author, :string)
    field(:level, :string)
    field(:subject, :string)
    field(:language, :string)
    field(:type, :string)

    # @desc "The file type"
    field(:mime_type, :string)

    # @desc "The type of content that may be embeded"
    field(:embed_type, :string)

    # @desc "The HTML code of content that may be embeded"
    field(:embed_code, :string)

    # @desc "Can you use this without needing an account somewhere?"
    field(:public_access, :boolean)

    # @desc "Can you use it without paying?"
    field(:free_access, :boolean)

    # @desc "How can you access it? see https://www.w3.org/wiki/WebSchemas/Accessibility"
    field(:accessibility_feature, {:array, :string})

    field(:extra_info, :map)

    field(:is_public, :boolean, virtual: true)
    field(:published_at, :utc_datetime_usec)
    field(:is_disabled, :boolean, virtual: true)
    field(:disabled_at, :utc_datetime_usec)
    field(:deleted_at, :utc_datetime_usec)

    many_to_many(:tags, CommonsPub.Tag.Taggable,
      join_through: "tags_things",
      unique: true,
      join_keys: [pointer_id: :id, tag_id: :id],
      on_replace: :delete
    )

    timestamps()
  end

  @required ~w(name content_id creator_id)a
  @cast @required ++
          ~w(canonical_url is_public is_disabled license summary icon_id extra_info author subject level language type mime_type embed_type embed_code public_access free_access accessibility_feature)a

  @doc "Creates a changeset for insertion of a resource with the given attributes."
  def create_changeset(creator, context, attrs) do
    %Resource{}
    |> Changeset.cast(attrs, @cast)
    |> cast_object()
    |> Changeset.change(
      context_id: context.id,
      creator_id: creator.id,
      is_public: true
    )
    |> Changeset.validate_required(@required)
    |> common_changeset()
  end

  def create_changeset(creator, attrs) do
    %Resource{}
    |> Changeset.cast(attrs, @cast)
    |> cast_object()
    |> Changeset.change(
      creator_id: creator.id,
      is_public: true
    )
    |> Changeset.validate_required(@required)
    |> common_changeset()
  end

  @spec update_changeset(%Resource{}, map) :: Changeset.t()
  @doc "Creates a changeset for updating the resource with the given attributes."
  def update_changeset(%Resource{} = resource, attrs) do
    resource
    |> Changeset.cast(attrs, @cast)
    |> common_changeset()
  end

  defp common_changeset(changeset) do
    changeset
    |> change_disabled()
    |> change_public()
  end

  ### behaviour callbacks

  def context_module, do: Resources

  def queries_module, do: Resources.Queries

  def follow_filters, do: []
end
