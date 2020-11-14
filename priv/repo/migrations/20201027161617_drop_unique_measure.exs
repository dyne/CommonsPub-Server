defmodule CommonsPub.Repo.Migrations.DropUniqueMeasure do
  use Ecto.Migration

  def down do

  end

  def up do
    drop_if_exists(unique_index(:measurement, [:unit_id, :has_numerical_value]))
  end
end
