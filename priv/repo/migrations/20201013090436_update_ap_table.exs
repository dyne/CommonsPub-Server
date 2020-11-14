defmodule CommonsPub.Repo.Migrations.UpdateApTable do
  use Ecto.Migration

  def up do
    rename(table(:ap_object), :mn_pointer_id, to: :pointer_id)
  end

  def down do
    rename(table(:ap_object), :pointer_id, to: :mn_pointer_id)
  end
end
