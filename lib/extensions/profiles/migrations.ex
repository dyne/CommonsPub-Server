defmodule CommonsPub.Profiles.Migrations do
  import Ecto.Migration
  import Pointers.Migration

  alias CommonsPub.Profiles.Profile

  defp table_name(), do: Profile.__schema__(:source)
  defp geo_table_name(), do: Geolocation.__schema__(:source)

  def migrate(index_opts, :up) do
    # a profile is a group actor that is home to resources
    create_mixin_table(Profile) do
      add(:name, :string)
      add(:summary, :text)
      add(:extra_info, :map)
      add(:icon_id, references(:mn_content))
      add(:image_id, references(:mn_content))
      # add(:geolocation_id, references(geo_table_name(), on_delete: :nilify_all))
      # add :primary_language_id, references("languages", on_delete: :nilify_all)
      add(:creator_id, references("mn_user", on_delete: :nilify_all))
      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)
      # timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    flush()

    # create_if_not_exists(index(:profile, :updated_at))
    create_if_not_exists(index(table_name(), :creator_id, index_opts))
    # create_if_not_exists index(:profile, :primary_language_id)
  end

  def migrate(index_opts, :down) do
    # drop_if_exists(index(:profile, :updated_at))
    drop_if_exists(index(table_name(), :creator_id, index_opts))
    drop_if_exists(index(table_name(), :primary_language_id, index_opts))
    drop_mixin_table(CommonsPub.Profiles.Profile)
  end

  def add_geolocation do
    alter table(table_name()) do
      add_if_not_exists(
        :geolocation_id,
        references(geo_table_name(), on_delete: :nilify_all)
      )
    end
  end
end
