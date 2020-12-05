# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Agent.Agents do
  # alias ValueFlows.{Simulate}
  require Logger

  # TODO - change approach to allow pagination
  def agents(signed_in_user) do
    orgs = ValueFlows.Agent.Organizations.organizations(signed_in_user)
    people = ValueFlows.Agent.People.people(signed_in_user)

    orgs ++ people
  end

  # FIXME - this works but isn't elegant
  def agent(id, signed_in_user) do
    case ValueFlows.Agent.People.person(id, signed_in_user) do
      {:error, _error} ->
        ValueFlows.Agent.Organizations.organization(id, signed_in_user)

      org ->
        org
    end
  end

  def agent_to_character(a) do
    a
    |> CommonsPub.Common.maybe_put(:summary, Map.get(a, :note))
    |> CommonsPub.Common.maybe_put(:geolocation, Map.get(a, :primary_location))
  end

  def character_to_agent(a) do
    # a = CommonsPub.Repo.maybe_preload(a, [icon: [:content], image: [:content]])

    a
    |> Map.put(:image, ValueFlows.Util.image_url(a))
    |> CommonsPub.Common.maybe_put(:primary_location, agent_location(a))
    |> CommonsPub.Common.maybe_put(:note, Map.get(a, :summary))
    |> add_type()

    # |> IO.inspect()
  end

  def agent_location(%{profile_id: profile_id} = a) when not is_nil(profile_id) do
    CommonsPub.Repo.maybe_preload(a, profile: [:geolocation])
    |> Map.get(:profile)
    |> agent_location()
  end

  def agent_location(%{geolocation_id: geolocation_id} = a) when not is_nil(geolocation_id) do
    CommonsPub.Repo.maybe_preload(a, :geolocation)
    |> Map.get(:geolocation)
  end

  def agent_location(_) do
    nil
  end



  def add_type(%CommonsPub.Users.User{} = a) do
    a
    |> Map.put(:agent_type, :person)
  end

  def add_type(%Organisation{} = a) do
    a
    |> Map.put(:agent_type, :organization)
  end

  def add_type(a) do
    a
  end
end
