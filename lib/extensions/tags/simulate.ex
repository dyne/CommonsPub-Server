# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Tag.Simulate do
  @moduledoc false

  import CommonsPub.Utils.Simulation

  alias CommonsPub.Tag.Categories

  ### Start fake data functions

  def category(base \\ %{}) do
    base
    |> Map.put_new_lazy(:id, &uuid/0)
    |> Map.put_new_lazy(:name, &name/0)
    |> Map.put_new_lazy(:note, &summary/0)
    |> Map.put_new_lazy(:is_public, &truth/0)
    |> Map.put_new_lazy(:is_disabled, &falsehood/0)
  end

  def fake_category!(user, parent_category \\ nil, overrides \\ %{})

  def fake_category!(user, nil, overrides) do
    {:ok, category} = Categories.create(user, category(overrides))
    category
  end

  def fake_category!(user, parent_category, overrides) do
    {:ok, category} =
      Categories.create(user, category(Map.put(overrides, :parent_category, parent_category)))

    category
  end
end
