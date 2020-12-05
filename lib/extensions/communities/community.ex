# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Communities.Community do
  use CommonsPub.Common.Schema

  import CommonsPub.Common.Changeset,
    only: [
      change_public: 1,
      change_disabled: 1
      # validate_language_code: 2
    ]

  alias Ecto.Changeset
  # alias CommonsPub.Characters.Character
  alias CommonsPub.Communities
  alias CommonsPub.Communities.{Community, CommunityFollowerCount}
  alias CommonsPub.Collections.Collection
  alias CommonsPub.Threads.Thread
  alias CommonsPub.Resources.Resource
  # alias CommonsPub.Feeds.Feed
  alias CommonsPub.Flags.Flag
  # alias CommonsPub.Locales.Language
  alias CommonsPub.Users.User
  # alias CommonsPub.Uploads.Content

  table_schema "mn_community" do
    has_one(:character, CommonsPub.Characters.Character, references: :id, foreign_key: :id)
    # belongs_to(:actor, Character)

    belongs_to(:creator, User)
    belongs_to(:context, Pointers.Pointer)

    belongs_to(:community, Community, foreign_key: :context_id, define_field: false)
    belongs_to(:collection, Collection, foreign_key: :context_id, define_field: false)
    has_many(:collections, Collection, foreign_key: :context_id)
    has_many(:resources, Resource, foreign_key: :context_id)
    has_many(:threads, Thread, foreign_key: :context_id)

    # moved to Character
    # belongs_to(:inbox_feed, Feed, foreign_key: :inbox_id)
    # belongs_to(:outbox_feed, Feed, foreign_key: :outbox_id)

    field(:canonical_url, :string, virtual: true)
    field(:preferred_username, :string, virtual: true)

    # belongs_to(:primary_language, Language)
    has_one(:follower_count, CommunityFollowerCount)

    field(:name, :string)
    field(:summary, :string)

    belongs_to(:icon, CommonsPub.Uploads.Content)
    belongs_to(:image, CommonsPub.Uploads.Content)

    field(:is_disabled, :boolean, virtual: true)
    field(:disabled_at, :utc_datetime_usec)

    field(:is_public, :boolean, virtual: true)
    field(:published_at, :utc_datetime_usec)

    field(:is_deleted, :boolean, virtual: true)
    field(:deleted_at, :utc_datetime_usec)

    field(:is_local, :boolean, virtual: true)

    has_many(:flags, Flag)

    field(:extra_info, :map)

    timestamps()
  end

  @create_required ~w(name creator_id)a
  @create_cast @create_required ++
                 ~w(is_disabled is_public summary icon_id image_id)a

  def create_changeset(
        %User{} = creator,
        %{} = context,
        fields
      ) do
    %Community{}
    |> Changeset.cast(fields, @create_cast)
    |> Changeset.change(
      # communities are currently all public
      is_public: true,
      context_id: context.id,
      creator_id: creator.id
    )
    |> Changeset.validate_required(@create_required)
    |> common_changeset()
  end

  def create_changeset(
        %User{} = creator,
        fields
      ) do
    %Community{}
    |> Changeset.cast(fields, @create_cast)
    |> Changeset.change(
      # communities are currently all public
      is_public: true,
      creator_id: creator.id
    )
    |> Changeset.validate_required(@create_required)
    |> common_changeset()
  end

  @update_cast ~w(name summary icon_id image_id is_disabled is_public)a
  def update_changeset(%Community{} = community, fields) do
    community
    |> Changeset.cast(fields, @update_cast)
    |> common_changeset()
  end

  defp common_changeset(changeset) do
    changeset
    |> change_public()
    |> change_disabled()

    # |> validate_language_code(:primary_language)
  end

  ### behaviour callbacks

  def context_module, do: Communities

  def queries_module, do: Communities.Queries

  def follow_filters, do: [:default]

  def type, do: :community
end
