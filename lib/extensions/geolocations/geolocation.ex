defmodule Geolocation do
  use Pointers.Pointable,
    otp_app: :commons_pub,
    source: "geolocation",
    table_id: "AP1ACEW1THGE0010CAT10NMARK"

  use CommonsPub.Common.Schema

  import CommonsPub.Common.Changeset, only: [change_public: 1, change_disabled: 1]

  alias Ecto.Changeset
  alias CommonsPub.Users.User
  # alias CommonsPub.Characters.Character
  alias Pointers.Pointer
  # alias CommonsPub.Feeds.Feed

  @type t :: %__MODULE__{}

  pointable_schema do
    field(:name, :string)

    field(:geom, Geo.PostGIS.Geometry)
    # altitude
    field(:alt, :float)
    field(:mappable_address, :string)
    field(:note, :string)

    field(:lat, :float, virtual: true)
    field(:long, :float, virtual: true)

    field(:is_public, :boolean, virtual: true)
    field(:published_at, :utc_datetime_usec)
    field(:is_disabled, :boolean, virtual: true, default: false)
    field(:disabled_at, :utc_datetime_usec)
    field(:deleted_at, :utc_datetime_usec)

    has_one(:character, CommonsPub.Characters.Character, references: :id, foreign_key: :id)
    # belongs_to(:actor, Character)

    belongs_to(:creator, User)

    belongs_to(:context, Pointer)

    # belongs_to(:inbox_feed, Feed, foreign_key: :inbox_id)
    # belongs_to(:outbox_feed, Feed, foreign_key: :outbox_id)

    # because it's keyed by pointer
    field(:follower_count, :any, virtual: true)

    timestamps(inserted_at: false)
  end

  @postgis_srid 4326

  @required ~w(name)a
  @cast @required ++ ~w(note mappable_address lat long geom alt is_disabled)a

  def create_changeset(
        creator,
        %{id: _} = context,
        attrs
      ) do
    %__MODULE__{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required(@required)
    |> Changeset.change(
      creator_id: CommonsPub.Common.maybe_get(creator, :id),
      context_id: context.id,
      is_public: true
    )
    |> common_changeset()
  end

  def create_changeset(
        creator,
        attrs
      ) do
    %__MODULE__{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required(@required)
    |> Changeset.change(
      creator_id: CommonsPub.Common.maybe_get(creator, :id),
      is_public: true
    )
    |> common_changeset()
  end

  def update_changeset(%__MODULE__{} = geolocation, attrs) do
    geolocation
    |> Changeset.cast(attrs, @cast)
    |> common_changeset()
  end

  defp common_changeset(changeset) do
    changeset
    |> change_public()
    |> change_disabled()
    |> validate_coordinates()
  end

  defp validate_coordinates(changeset) do
    lat = Changeset.get_change(changeset, :lat)
    long = Changeset.get_change(changeset, :long)

    if not (is_nil(lat) or is_nil(long)) do
      geom = %Geo.Point{coordinates: {lat, long}, srid: @postgis_srid}
      Changeset.change(changeset, geom: geom)
    else
      changeset
    end
  end

  def context_module, do: Geolocation.Geolocations

  def queries_module, do: Geolocation.Queries

  def follow_filters, do: []
end
