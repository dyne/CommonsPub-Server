defmodule CommonsPub.Repo.Migrations.APLibTest do
  use Ecto.Migration

  def change do
    ActivityPub.Migrations.prepare_test()
  end

end
