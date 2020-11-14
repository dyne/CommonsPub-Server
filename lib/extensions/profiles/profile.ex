# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Profiles.Profile do
  use Pointers.Mixin,
    otp_app: :commons_pub,
    source: "profile"

  import CommonsPub.Common.Changeset, only: [change_public: 1, change_disabled: 1]

  alias Ecto.Changeset
  # alias CommonsPub.Profiles.Profile
  # alias CommonsPub.Feeds.Feed
  alias CommonsPub.Users.User
  alias CommonsPub.Uploads.Content

  # alias Pointers.Pointer

  @type t :: %__MODULE__{}

  mixin_schema do
    field(:name, :string)
    field(:summary, :string)

    field(:extra_info, :map)

    belongs_to(:icon, Content)
    belongs_to(:image, Content)

    belongs_to(:geolocation, Geolocation)

    # belongs_to(:primary_language, Language)

    belongs_to(:creator, User)

    field(:is_public, :boolean, virtual: true)
    field(:is_disabled, :boolean, virtual: true, default: false)

    field(:published_at, :utc_datetime_usec)
    field(:disabled_at, :utc_datetime_usec)
    field(:deleted_at, :utc_datetime_usec)
    # timestamps()
  end

  @required ~w(id name)a
  @cast @required ++ ~w(summary extra_info image_id icon_id is_disabled)a

  def create_changeset(
        nil,
        attrs
      ) do
    %CommonsPub.Profiles.Profile{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required(@required)
    |> Changeset.change(is_public: true)
    |> common_changeset()
  end

  def create_changeset(
        %User{} = creator,
        attrs
      ) do
    %CommonsPub.Profiles.Profile{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required(@required)
    |> Changeset.change(
      creator_id: creator.id,
      geolocation_id: CommonsPub.Common.attr_get_id(attrs, :geolocation), # TODO: validate location
      is_public: true
    )
    |> common_changeset()
  end

  def update_changeset(%CommonsPub.Profiles.Profile{} = profile, attrs) do
    profile
    |> Changeset.cast(attrs, @cast)
    |> common_changeset()
  end

  defp common_changeset(changeset) do
    changeset
    |> change_public()
    |> change_disabled()
  end
end
