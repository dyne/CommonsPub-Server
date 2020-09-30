defmodule ValueFlows.Observation.EconomicEvent.EventSideEffects do
  import Logger

  alias CommonsPub.Repo

  alias ValueFlows.Observation.EconomicEvent
  alias ValueFlows.Observation.EconomicEvent.EconomicEvents
  alias ValueFlows.Observation.EconomicResource.EconomicResources
  alias ValueFlows.Observation.EconomicEvent.Queries

  def event_side_effects(
        %EconomicEvent{
          action: %{label: action, resource_effect: operation},
          resource_quantity: quantity
        } = event
      ) do
    event =
      Repo.preload(event,
        resource_inventoried_as: [:accounting_quantity, :onhand_quantity],
        to_resource_inventoried_as: [:accounting_quantity, :onhand_quantity]
      )

    resource = event.resource_inventoried_as
    to_resource = event.to_resource_inventoried_as

    cond do
      #     If action.resourceEffect is "+"
      operation == "increment" and event.resource_inventoried_as_id != nil ->
        #         Add event resourceQuantity to accountingQuantity
        resource = quantity_effect(:accounting_quantity, resource, quantity, operation)

        #         Add event resourceQuantity to onhandQuantity
        resource = quantity_effect(:onhand_quantity, resource, quantity, operation)

        return_updated_event(event, resource)

      #     ElseIf action.resourceEffect is "-"
      operation == "decrement" and event.resource_inventoried_as_id != nil ->
        #         Subtract event resourceQuantity from accountingQuantity
        resource = quantity_effect(:accounting_quantity, resource, quantity, operation)

        #         Subtract event resourceQuantity from onhandQuantity
        resource = quantity_effect(:onhand_quantity, resource, quantity, operation)

        return_updated_event(event, resource)

      # ElseIf action.resourceEffect is "-+"
      operation == "decrementIncrement" ->
        # # (two resources can be affected)
        # If action is "transfer-custody" or "transfer-complete" or "move"
        cond do
          action == "transfer" or action == "move" ->
            #     If the from-resource exists
            #         Subtract event resourceQuantity from from_resource.onhandQuantity and accountingQuantity
            resource = quantity_effect(:onhand_quantity, resource, quantity, "decrement")
            resource = quantity_effect(:accounting_quantity, resource, quantity, "decrement")

            #     If the to-resource exists
            #         Add event resourceQuantity to to_resource.onhandQuantity and accountingQuantity
            to_resource = quantity_effect(:onhand_quantity, to_resource, quantity, "increment")

            to_resource =
              quantity_effect(:accounting_quantity, to_resource, quantity, "increment")

            return_updated_event(event, resource, to_resource)

          action == "transfer-custody" ->
            #     If the from-resource exists
            #         Subtract event resourceQuantity from from_resource.onhandQuantity
            resource = quantity_effect(:onhand_quantity, resource, quantity, "decrement")

            #     If the to-resource exists
            #         Add event resourceQuantity to to_resource.onhandQuantity
            to_resource = quantity_effect(:onhand_quantity, to_resource, quantity, "increment")

            return_updated_event(event, resource, to_resource)

          # ElseIf action is "transfer-all-rights" or "transfer-complete" or "move"
          action == "transfer-all-rights" ->
            #     If the from-resource exists
            #         Subtract event resourceQuantity from from_resource.accountingQuantity
            resource = quantity_effect(:accounting_quantity, resource, quantity, "decrement")

            #     If the to-resource exists
            #         Add event resourceQuantity to to_resource.accountingQuantity
            to_resource =
              quantity_effect(:accounting_quantity, to_resource, quantity, "increment")

            return_updated_event(event, resource, to_resource)

          # Else
          true ->
            {:ok, event}
        end

      # Else
      true ->
        {:ok, event}
    end
  end

  def quantity_effect(
        :onhand_quantity,
        %{
          onhand_quantity: %{unit_id: onhand_unit} = onhand_quantity
        } = resource,
        %{unit_id: event_unit},
        _
      )
      when onhand_unit != event_unit do
    {:error,
     "The units used on the existing resource's onhand quantity do not match the event's unit"}
  end

  def quantity_effect(
        :accounting_quantity,
        %{
          accounting_quantity: %{unit_id: accounting_unit} = accounting_quantity
        } = resource,
        %{unit_id: event_unit},
        _
      )
      when accounting_unit != event_unit do
    {:error,
     "The units used on the existing the resource's accounting quantity do not match the event's unit"}
  end

  def quantity_effect(
        :onhand_quantity = field,
        %{
          onhand_quantity: %{unit_id: onhand_unit} = onhand_quantity
        } = resource,
        %{unit_id: event_unit, has_numerical_value: amount} = _by_quantity,
        operation
      )
      when onhand_unit == event_unit do
    onhand_quantity = measurement_effect(operation, onhand_quantity, amount)

    %{resource | onhand_quantity: onhand_quantity}
  end

  def quantity_effect(
        :accounting_quantity = field,
        %{
          accounting_quantity: %{unit_id: accounting_unit} = accounting_quantity
        } = resource,
        %{unit_id: event_unit, has_numerical_value: amount} = _by_quantity,
        operation
      )
      when accounting_unit == event_unit do
    accounting_quantity = measurement_effect(operation, accounting_quantity, amount)

    %{resource | accounting_quantity: accounting_quantity}
  end

  def quantity_effect(
        :onhand_quantity = field,
        %{
          onhand_quantity_id: existing_quantity
        } = resource,
        by_quantity,
        _
      )
      when is_nil(existing_quantity) do
    Logger.warn("# TODO: Set onhandQuantity? ")
    resource
  end

  def quantity_effect(
        :accounting_quantity = field,
        %{
          accounting_quantity_id: existing_quantity
        } = resource,
        by_quantity,
        _
      )
      when is_nil(existing_quantity) do
    Logger.warn("# TODO: Set accountingQuantity? ")
    resource
  end

  def quantity_effect(_, resource, _, _) do
    resource
  end

  def measurement_effect("decrement", measurement, amount) do
    measurement_effect(nil, measurement, -amount)
  end

  def measurement_effect(_, %{id: id} = _measurement, amount) do
    Measurement.Measure.Queries.inc_quantity(id, amount)
    # reload the measurement
    {:ok, measurement} = Measurement.Measure.Measures.one(id: id)
    measurement
  end

  def return_updated_event(event, resource) do
    {:ok, %{event | resource_inventoried_as: resource}}
  end

  def return_updated_event(event, resource, to_resource) do
    {:ok, %{event | resource_inventoried_as: resource, to_resource_inventoried_as: to_resource}}
  end
end
