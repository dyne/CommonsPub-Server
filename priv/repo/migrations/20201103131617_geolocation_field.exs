defmodule CommonsPub.Repo.Migrations.GeolocationField do
  use Ecto.Migration

  defp table_name(), do: Geolocation.__schema__(:source)

  def up do
    add_geolocation()

    CommonsPub.Profiles.Migrations.add_geolocation()
  end

  def down do

  end

  def add_geolocation do
    alter table("mn_user") do
      add_if_not_exists(:geolocation_id, references(table_name(), on_delete: :nilify_all))
    end
  end
end
