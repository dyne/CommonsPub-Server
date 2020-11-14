defmodule ValueFlows.Observation.Process.ProcessesTest do
  use CommonsPub.Web.ConnCase, async: true

  import CommonsPub.Utils.Simulation
  import CommonsPub.Test.Faking
  import CommonsPub.Tag.Simulate
  import CommonsPub.Utils.Trendy, only: [some: 2]

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  alias ValueFlows.Observation.Process.Processes

  describe "one" do
    test "fetches an existing process by ID" do
      user = fake_user!()
      spec = fake_process!(user)

      assert {:ok, fetched} = Processes.one(id: spec.id)
      assert_process(fetched)
      assert {:ok, fetched} = Processes.one(user: user)
      assert_process(fetched)
    end

    test "cannot fetch a deleted process" do
      user = fake_user!()
      spec = fake_process!(user)
      assert {:ok, spec} = Processes.soft_delete(spec)
      assert {:error, %CommonsPub.Common.NotFoundError{}} =
              Processes.one([:deleted, id: spec.id])
    end
  end

  describe "track" do
    test "Returns EconomicEvents that are outputs" do
      user = fake_user!()
      process = fake_process!(user)
      _input_events = some(3, fn -> fake_economic_event!(user, %{
        input_of: process.id,
        action: "consume"
      }) end)
      output_events = some(5, fn -> fake_economic_event!(user, %{
        output_of: process.id,
        action: "produce"
      }) end)
      assert {:ok, events} = Processes.track(process)
      assert Enum.map(events, &(&1.id)) == Enum.map(output_events, &(&1.id))
    end
  end

  describe "trace" do
    test "Return EconomicEvents that are inputs" do
      user = fake_user!()
      process = fake_process!(user)
      input_events = some(3, fn -> fake_economic_event!(user, %{
        input_of: process.id,
        action: "consume"
      }) end)
      _output_events = some(5, fn -> fake_economic_event!(user, %{
        output_of: process.id,
        action: "produce"
      }) end)
      assert {:ok, events} = Processes.trace(process)
      assert Enum.map(events, &(&1.id)) == Enum.map(input_events, &(&1.id))
    end
  end

  describe "inputs" do
    test "return EconomicEvents that are inputs" do
      user = fake_user!()
      process = fake_process!(user)
      input_events = some(3, fn -> fake_economic_event!(user, %{
        input_of: process.id,
        action: "consume"
      }) end)
      _output_events = some(5, fn -> fake_economic_event!(user, %{
        output_of: process.id,
        action: "produce"
      }) end)
      assert {:ok, events} = Processes.inputs(process)
      assert Enum.map(events, &(&1.id)) == Enum.map(input_events, &(&1.id))
    end

    test "return EconomicEvents that are inputs and with action consume" do
      user = fake_user!()
      process = fake_process!(user)
      input_events = some(3, fn -> fake_economic_event!(user, %{
        input_of: process.id,
        action: "consume"
      }) end)
      _other_input_events = some(5, fn -> fake_economic_event!(user, %{
        input_of: process.id,
        action: "use"
      }) end)
      assert {:ok, events} = Processes.inputs(process, "consume")
      assert Enum.map(events, &(&1.id)) == Enum.map(input_events, &(&1.id))
    end
  end

  describe "outputs" do
    test "return EconomicEvents that are ouputs" do
      user = fake_user!()
      process = fake_process!(user)
      _input_events = some(3, fn -> fake_economic_event!(user, %{
        input_of: process.id,
        action: "consume"
      }) end)
      output_events = some(5, fn -> fake_economic_event!(user, %{
        output_of: process.id,
        action: "produce"
      }) end)
      assert {:ok, events} = Processes.outputs(process)
      assert Enum.map(events, &(&1.id)) == Enum.map(output_events, &(&1.id))
    end

    test "return EconomicEvents that are ouputs and with action produce" do
      user = fake_user!()
      process = fake_process!(user)
      _other_output_events = some(3, fn -> fake_economic_event!(user, %{
        output_of: process.id,
        action: "raise"
      }) end)
      output_events = some(5, fn -> fake_economic_event!(user, %{
        output_of: process.id,
        action: "produce"
      }) end)
      assert {:ok, events} = Processes.outputs(process, "produce")
      assert Enum.map(events, &(&1.id)) == Enum.map(output_events, &(&1.id))
    end
  end

  describe "create" do
    test "can create a process" do
      user = fake_user!()

      assert {:ok, process} = Processes.create(user, process())
      assert_process(process)
    end

    test "can create a process with context" do
      user = fake_user!()
      parent = fake_user!()

      attrs = %{in_scope_of: [parent.id]}
      assert {:ok, process} = Processes.create(user, process(attrs))
      assert_process(process)
      assert process.context.id == parent.id
    end

    test "can create a process with tags" do
      user = fake_user!()
      tags = some(5, fn -> fake_category!(user).id end)

      attrs = process(%{tags: tags})
      assert {:ok, process} = Processes.create(user, attrs)
      assert_process(process)

      process = CommonsPub.Repo.preload(process, :tags)
      assert Enum.count(process.tags) == Enum.count(tags)
    end
  end

  describe "update" do
    test "can update an existing process" do
      user = fake_user!()
      spec = fake_process!(user)

      assert {:ok, updated} = Processes.update(spec, process())
      assert_process(updated)
      assert updated.updated_at != spec.updated_at
    end
  end

  describe "soft delete" do
    test "delete an existing process" do
      user = fake_user!()
      spec = fake_process!(user)

      refute spec.deleted_at
      assert {:ok, spec} = Processes.soft_delete(spec)
      assert spec.deleted_at
    end

  end

end
