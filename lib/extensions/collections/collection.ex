# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Collections.Collection do
  use CommonsPub.Common.Schema

  import CommonsPub.Common.Changeset, only: [change_public: 1, change_disabled: 1]

  alias Ecto.Changeset
  alias CommonsPub.Collections
  alias CommonsPub.Characters.Character
  alias CommonsPub.Communities.Community
  alias CommonsPub.Collections.Collection
  alias CommonsPub.Threads.Thread
  alias CommonsPub.Resources.Resource
  # alias CommonsPub.Feeds.Feed
  alias CommonsPub.Users.User
  alias CommonsPub.Uploads.Content

  @type t :: %__MODULE__{}

  table_schema "mn_collection" do
    # belongs_to(:actor, Character)
    has_one(:character, Character, references: :id, foreign_key: :id)

    belongs_to(:creator, User)

    # deprecated by context
    # belongs_to(:community, Community)
    # field(:community_id, :string, virtual: true)

    belongs_to(:context, Pointers.Pointer)

    belongs_to(:community, Community, foreign_key: :context_id, define_field: false)
    belongs_to(:collection, Collection, foreign_key: :context_id, define_field: false)
    has_many(:collections, Collection, foreign_key: :context_id)
    has_many(:resources, Resource, foreign_key: :context_id)
    has_many(:threads, Thread, foreign_key: :context_id)

    # moved to Character
    # belongs_to(:inbox_feed, Feed, foreign_key: :inbox_id)
    # belongs_to(:outbox_feed, Feed, foreign_key: :outbox_id)

    # because it's keyed by pointer
    field(:follower_count, :any, virtual: true)


    field(:name, :string)
    field(:summary, :string)

    belongs_to(:icon, Content)

    # belongs_to(:primary_language, Language)

    field(:is_public, :boolean, virtual: true)
    field(:published_at, :utc_datetime_usec)

    field(:is_disabled, :boolean, virtual: true, default: false)
    field(:disabled_at, :utc_datetime_usec)

    field(:deleted_at, :utc_datetime_usec)

    field(:extra_info, :map)

    timestamps()
  end

  @required ~w(name is_public creator_id)a
  @cast @required ++ ~w(summary icon_id is_disabled)a

  def create_changeset(
        %User{} = creator,
        context,
        attrs
      ) do
    %Collection{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.change(
      creator_id: creator.id,
      context_id: context.id,
      is_public: true
    )
    |> Changeset.validate_required(@required)
    |> common_changeset()
  end

  def create_changeset(
        %User{} = creator,
        attrs
      ) do
    %Collection{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.change(
      creator_id: creator.id,
      is_public: true
    )
    |> Changeset.validate_required(@required)
    |> common_changeset()
  end

  def update_changeset(%Collection{} = collection, attrs) do
    collection
    |> Changeset.cast(attrs, @cast)
    |> common_changeset()
  end

  defp common_changeset(changeset) do
    changeset
    |> change_public()
    |> change_disabled()
  end

  ### behaviour callbacks

  def context_module, do: Collections

  def queries_module, do: Collections.Queries

  def follow_filters, do: [join: :character, preload: :character]

  def type, do: :collection
end
