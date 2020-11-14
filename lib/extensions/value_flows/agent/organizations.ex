# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Agent.Organizations do
  # alias ValueFlows.Simulate
  require Logger

  def organizations(signed_in_user) do
    {:ok, orgs} = Organisation.Organisations.many([:default, user: signed_in_user])

    Enum.map(
      orgs,
      &(&1
        |> ValueFlows.Agent.Agents.character_to_agent())
    )
  end

  def organization(id, signed_in_user) do
    case Organisation.Organisations.one([:default, id: id, user: signed_in_user]) do
      {:ok, item} -> item |> ValueFlows.Agent.Agents.character_to_agent()
      {:error, error} -> {:error, error}
    end
  end
end
