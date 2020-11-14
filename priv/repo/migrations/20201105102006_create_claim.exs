defmodule CommonsPub.Repo.Migrations.CreateClaim do
  use Ecto.Migration

  def up, do: ValueFlows.Claim.Migrations.up()
  def down, do: ValueFlows.Claim.Migrations.down()
end
