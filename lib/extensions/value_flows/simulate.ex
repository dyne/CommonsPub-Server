# SPDX-License-Identifier: AGPL-3.0-only
defmodule ValueFlows.Simulate do
  @moduledoc false

  import CommonsPub.Utils.Simulation
  import CommonsPub.Utils.Trendy
  # import CommonsPub.Utils.Simulation

  import Measurement.Simulate

  alias ValueFlows.Claim.Claims
  alias ValueFlows.Planning.Intent.Intents
  alias ValueFlows.Proposal.Proposals
  alias ValueFlows.Observation.EconomicEvent.EconomicEvents
  alias ValueFlows.Observation.EconomicResource.EconomicResources
  alias ValueFlows.Observation.Process.Processes

  alias ValueFlows.Knowledge.Action.Actions
  alias ValueFlows.Knowledge.ProcessSpecification.ProcessSpecifications
  alias ValueFlows.Knowledge.ResourceSpecification.ResourceSpecifications

  ### Start fake data functions

  def claim(base \\ %{}) do
    base
    |> Map.put_new_lazy(:note, &summary/0)
    |> Map.put_new_lazy(:agreed_in, &url/0)
    |> Map.put_new_lazy(:finished, &bool/0)
    |> Map.put_new_lazy(:created, &past_datetime/0)
    |> Map.put_new_lazy(:due, &future_datetime/0)
    |> Map.put_new_lazy(:action, &action_id/0)
    |> Map.put_new_lazy(:resource_classified_as, fn -> some(1..5, &url/0) end)
  end

  def claim_input(base \\ %{}) do
    base
    |> Map.put_new_lazy("note", &summary/0)
    # FIXME: URI doesn't work, scalar?
    # |> Map.put_new_lazy("agreedIn", &url/0)
    |> Map.put_new_lazy("finished", &bool/0)
    |> Map.put_new_lazy("created", &past_datetime_iso/0)
    |> Map.put_new_lazy("due", &future_datetime_iso/0)
    |> Map.put_new_lazy("action", &action_id/0)

    # |> Map.put_new_lazy("resourceClassifiedAs", fn -> some(1..5, &url/0) end)
  end

  def agent_type(), do: Faker.Util.pick([:person, :organization])

  def agent(base \\ %{}) do
    base
    # |> Map.put_new_lazy(:id, &ulid/0)
    |> Map.put_new_lazy(:name, &name/0)
    |> Map.put_new_lazy(:note, &summary/0)
    |> Map.put_new_lazy(:image, &image/0)
    |> Map.put_new_lazy(:primary_location, &fake_geolocation_id/0)
    |> Map.put_new_lazy(:agent_type, &agent_type/0)
  end

  def fake_agent!(overrides \\ %{}, opts \\ []) when is_map(overrides) and is_list(opts) do
    fake_agent_from_user!(
      fake_user!(ValueFlows.Agent.Agents.agent_to_character(agent(overrides)))
    )
  end

  def fake_agent_from_user!(user) do
    ValueFlows.Agent.Agents.character_to_agent(user)
  end

  def resource_specification(base \\ %{}) do
    base
    |> Map.put_new_lazy(:name, &name/0)
    |> Map.put_new_lazy(:note, &summary/0)
    # |> Map.put_new_lazy(:image, &icon/0)
    # |> Map.put_new_lazy(:default_unit_of_effort, &unit/0)
    |> Map.put_new_lazy(:resource_classified_as, fn -> some(1..5, &url/0) end)
    |> Map.put_new_lazy(:is_public, &truth/0)
    |> Map.put_new_lazy(:is_disabled, &falsehood/0)
  end

  def resource_specification_input(base \\ %{}) do
    base
    |> Map.put_new_lazy("name", &name/0)
    |> Map.put_new_lazy("note", &summary/0)
  end

  def inc_dec(), do: Faker.Util.pick(["increment", "decrement"])

  def action, do: Faker.Util.pick(Actions.actions_list())
  def actions, do: Actions.actions_list()

  def action_id, do: action().id
  def fake_agent_id, do: fake_agent!().id
  def fake_geolocation_id, do: Geolocation.Simulate.fake_geolocation!().id

  def economic_event(base \\ %{}) do
    base
    |> Map.put_new_lazy(:action, &action_id/0)
    # |> Map.put_new_lazy(:provider, &fake_agent_id/0)
    # |> Map.put_new_lazy(:receiver, &fake_agent_id/0)
    |> Map.put_new_lazy(:note, &summary/0)
    |> Map.put_new_lazy(:has_beginning, &past_datetime/0)
    |> Map.put_new_lazy(:has_end, &future_datetime/0)
    |> Map.put_new_lazy(:has_point_in_time, &future_datetime/0)
    # |> Map.put_new_lazy(:resource_classified_as, fn -> some(1..5, &url/0) end)
    |> Map.put_new_lazy(:is_public, &truth/0)
    |> Map.put_new_lazy(:is_disabled, &falsehood/0)
  end

  def economic_event_input(base \\ %{}) do
    base
    |> Map.put_new_lazy("action", &action_id/0)
    # |> Map.put_new_lazy("provider", &fake_agent_id/0)
    # |> Map.put_new_lazy("receiver", &fake_agent_id/0)
    |> Map.put_new_lazy("note", &summary/0)
    |> Map.put_new_lazy("hasBeginning", &past_datetime_iso/0)
    |> Map.put_new_lazy("hasEnd", &future_datetime_iso/0)
    |> Map.put_new_lazy("hasPointInTime", &future_datetime_iso/0)

    # |> Map.put_new_lazy("resource_classified_as", fn -> some(1..5, &url/0) end)
  end

  def economic_resource(base \\ %{}) do
    base
    |> Map.put_new_lazy(:name, &name/0)
    |> Map.put_new_lazy(:note, &summary/0)
    |> Map.put_new_lazy(:tracking_identifier, &uuid/0)
    |> Map.put_new_lazy(:state, &action_id/0)
    # |> Map.put_new_lazy(:accounting_quantity, &measure/0)
    # |> Map.put_new_lazy(:onhand_quantity, &measure/0)
    # |> Map.put_new_lazy(:unit_of_effort, &unit/0)
    # |> Map.put_new_lazy(:image, &icon/0)
    |> Map.put_new_lazy(:is_public, &truth/0)
    |> Map.put_new_lazy(:is_disabled, &falsehood/0)
  end

  def economic_resource_input(base \\ %{}) do
    base
    |> Map.put_new_lazy("name", &name/0)
    |> Map.put_new_lazy("note", &summary/0)
    |> Map.put_new_lazy("tracking_identifier", &uuid/0)
  end

  def process(base \\ %{}) do
    base
    |> Map.put_new_lazy(:name, &name/0)
    |> Map.put_new_lazy(:note, &summary/0)
    # |> Map.put_new_lazy(:image, &icon/0)
    |> Map.put_new_lazy(:resource_classified_as, fn -> some(1..5, &url/0) end)
    |> Map.put_new_lazy(:finished, &bool/0)
    |> Map.put_new_lazy(:is_public, &truth/0)
    |> Map.put_new_lazy(:is_disabled, &falsehood/0)
  end

  def process_input(base \\ %{}) do
    base
    |> Map.put_new_lazy("name", &name/0)
    |> Map.put_new_lazy("note", &summary/0)

    # |> Map.put_new_lazy(:image, &icon/0)
    # |> Map.put_new_lazy(:resource_classified_as, fn -> some(1..5, &url/0) end)
  end

  def process_specification(base \\ %{}) do
    base
    |> Map.put_new_lazy(:name, &name/0)
    |> Map.put_new_lazy(:note, &summary/0)
    |> Map.put_new_lazy(:classified_as, fn -> some(1..5, &url/0) end)
    |> Map.put_new_lazy(:is_public, &truth/0)
    |> Map.put_new_lazy(:is_disabled, &falsehood/0)
  end

  def process_specification_input(base \\ %{}) do
    base
    |> Map.put_new_lazy("name", &name/0)
    |> Map.put_new_lazy("note", &summary/0)
  end

  def proposal(base \\ %{}) do
    base
    |> Map.put_new_lazy(:name, &name/0)
    |> Map.put_new_lazy(:note, &summary/0)
    # |> Map.put_new_lazy(:image, &icon/0)
    |> Map.put_new_lazy(:has_beginning, &past_datetime/0)
    |> Map.put_new_lazy(:has_end, &future_datetime/0)
    |> Map.put_new_lazy(:created, &future_datetime/0)
    |> Map.put_new_lazy(:unit_based, &bool/0)
    |> Map.put_new_lazy(:is_public, &truth/0)
    |> Map.put_new_lazy(:is_disabled, &falsehood/0)
  end

  def proposal_input(base \\ %{}) do
    base
    |> Map.put_new_lazy("name", &name/0)
    |> Map.put_new_lazy("note", &summary/0)
    |> Map.put_new_lazy("hasBeginning", &past_datetime_iso/0)
    |> Map.put_new_lazy("hasEnd", &future_datetime_iso/0)
    |> Map.put_new_lazy("created", &future_datetime_iso/0)
    |> Map.put_new_lazy("unitBased", &bool/0)
  end

  def update_proposal_input(base \\ %{}) do
    proposal_input(base)
    |> Map.drop(["created"])
  end

  def proposed_intent(base \\ %{}) do
    base
    |> Map.put_new_lazy(:reciprocal, &maybe_bool/0)
  end

  def proposed_intent_input(base \\ %{}) do
    base
    |> Map.put_new_lazy("reciprocal", &maybe_bool/0)
  end

  def intent(base \\ %{}) do
    base
    |> Map.put_new_lazy(:name, &name/0)
    |> Map.put_new_lazy(:note, &summary/0)
    # |> Map.put_new_lazy(:image, &icon/0)
    |> Map.put_new_lazy(:action, &action_id/0)
    |> Map.put_new_lazy(:has_beginning, &past_datetime/0)
    |> Map.put_new_lazy(:has_end, &future_datetime/0)
    |> Map.put_new_lazy(:has_point_in_time, &future_datetime/0)
    |> Map.put_new_lazy(:due, &future_datetime/0)
    # TODO: list of URIs?
    |> Map.put_new_lazy(:resource_classified_as, fn -> some(1..5, &url/0) end)
    |> Map.put_new_lazy(:finished, &bool/0)
    |> Map.put_new_lazy(:is_public, &truth/0)
    |> Map.put_new_lazy(:is_disabled, &falsehood/0)
  end

  def intent_input(base \\ %{}) do
    base
    |> Map.put_new_lazy("name", &name/0)
    |> Map.put_new_lazy("note", &summary/0)
    # |> Map.put_new_lazy("image", &icon/0)
    |> Map.put_new_lazy("action", &action_id/0)
    |> Map.put_new_lazy("resource_classified_as", fn -> some(1..5, &url/0) end)
    |> Map.put_new_lazy("has_beginning", &past_datetime_iso/0)
    |> Map.put_new_lazy("has_end", &future_datetime_iso/0)
    |> Map.put_new_lazy("has_point_in_time", &future_datetime_iso/0)
    |> Map.put_new_lazy("due", &future_datetime_iso/0)
    |> Map.put_new_lazy("finished", &bool/0)
  end

  @doc "Shorter version of fake_claim!/4, but instead generates a provider and receiver."
  def fake_claim!(user, overrides \\ %{}) do
    fake_claim!(user, fake_agent!(), fake_agent!(), overrides)
  end

  def fake_claim!(user, provider, receiver, overrides \\ %{}) do
    {:ok, claim} = Claims.create(user, provider, receiver, claim(overrides))
    claim
  end

  def fake_intent!(user, overrides \\ %{}) do
    unit = fake_unit!(user)
    fake_intent!(user, overrides, unit)
  end

  def fake_intent!(user, overrides, unit) do
    measure_attrs = %{unit_id: unit.id}

    measures = %{
      available_quantity: measure(measure_attrs),
      resource_quantity: measure(measure_attrs),
      effort_quantity: measure(measure_attrs)
    }

    overrides = Map.merge(overrides, measures)

    {:ok, intent} = Intents.create(user, intent(overrides))
    intent
  end

  def fake_proposal!(user, overrides \\ %{}) do
    {:ok, proposal} = Proposals.create(user, proposal(overrides))
    proposal
  end

  def fake_proposed_intent!(proposal, intent, overrides \\ %{}) do
    {:ok, proposed_intent} =
      Proposals.propose_intent(proposal, intent, proposed_intent(overrides))

    proposed_intent
  end

  def fake_proposed_to!(proposed_to, proposed) do
    {:ok, proposed_to} = Proposals.propose_to(proposed_to, proposed)
    proposed_to
  end

  def proposal_fields(extra \\ []) do
    extra ++ ~w(id name note created has_beginning has_end unit_based)a
  end

  def fake_process_specification!(user, overrides \\ %{}) do
    {:ok, spec} = ProcessSpecifications.create(user, process_specification(overrides))
    spec
  end

  def fake_economic_event!(user, overrides \\ %{}) do
    unit = fake_unit!(user)
    fake_economic_event!(user, overrides, unit)
  end

  def fake_economic_event!(user, overrides, unit) do
    with {:ok, event} <- fake_economic_event(user, overrides, unit) do
      event
    else
      e ->
        e
    end
  end

  def fake_economic_event(user, overrides \\ %{}) do
    unit = fake_unit!(user)
    fake_economic_event(user, overrides, unit)
  end

  def fake_economic_event(user, overrides, unit) do
    measure_attrs = %{unit_id: unit.id}

    measures = %{
      resource_quantity: measure(measure_attrs),
      effort_quantity: measure(measure_attrs)
    }

    overrides = Map.merge(overrides, measures)

    EconomicEvents.create(user, economic_event(overrides))
  end

  def fake_process!(user, overrides \\ %{}) do
    {:ok, process} = Processes.create(user, process(overrides))
    process
  end

  def fake_resource_specification!(user, overrides \\ %{}) do
    {:ok, spec} = ResourceSpecifications.create(user, resource_specification(overrides))
    spec
  end

  def fake_economic_resource!(user, overrides \\ %{}) do
    unit = fake_unit!(user)
    fake_economic_resource!(user, overrides, unit)
  end

  def fake_economic_resource!(user, overrides, unit) do
    measure_attrs = %{unit_id: unit.id}

    measures = %{
      accounting_quantity: measure(measure_attrs),
      onhand_quantity: measure(measure_attrs)
    }

    overrides = Map.merge(overrides, measures)

    {:ok, spec} = EconomicResources.create(user, economic_resource(overrides))
    spec
  end
end
