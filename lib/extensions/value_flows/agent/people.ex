# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Agent.People do
  # alias ValueFlows.{Simulate}
  require Logger

  def people(signed_in_user) do
    {:ok, users} = CommonsPub.Users.many([:default, user: signed_in_user])

    Enum.map(
      users,
      &(&1
        |> ValueFlows.Agent.Agents.character_to_agent())
    )
  end

  def person(id, signed_in_user) do
    # IO.inspect(id)

    case CommonsPub.Users.one([:default, :geolocation, id: id, user: signed_in_user]) do
      {:ok, item} -> item |> ValueFlows.Agent.Agents.character_to_agent()
      {:error, error} -> {:error, error}
    end
  end
end
