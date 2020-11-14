defmodule ValueFlows.Knowledge.ProcessSpecification.ProcessSpecificationsTest do
  use CommonsPub.Web.ConnCase, async: true

  import CommonsPub.Utils.Simulation
  import CommonsPub.Test.Faking
  import CommonsPub.Tag.Simulate
  import CommonsPub.Utils.Trendy, only: [some: 2]

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  alias ValueFlows.Knowledge.ProcessSpecification.ProcessSpecifications

  describe "one" do
    test "fetches an existing process specification by ID" do
      user = fake_user!()
      spec = fake_process_specification!(user)

      assert {:ok, fetched} = ProcessSpecifications.one(id: spec.id)
      assert_process_specification(fetched)
      assert {:ok, fetched} = ProcessSpecifications.one(user: user)
      assert_process_specification(fetched)
    end

    test "cannot fetch a deleted process specification" do
      user = fake_user!()
      spec = fake_process_specification!(user)
      assert {:ok, spec} = ProcessSpecifications.soft_delete(spec)
      assert {:error, %CommonsPub.Common.NotFoundError{}} =
              ProcessSpecifications.one([:deleted, id: spec.id])
    end
  end

  describe "create" do
    test "can create a process specification" do
      user = fake_user!()

      assert {:ok, spec} = ProcessSpecifications.create(user, process_specification())
      assert_process_specification(spec)
    end

    test "can create a process specification with context" do
      user = fake_user!()

      attrs = %{in_scope_of: [fake_user!().id]}

      assert {:ok, spec} = ProcessSpecifications.create(user, process_specification(attrs))
      assert_process_specification(spec)
      assert spec.context_id == hd(attrs.in_scope_of)
    end

    test "can create a process_specification with tags" do
      user = fake_user!()
      tags = some(5, fn -> fake_category!(user).id end)

      attrs = process_specification(%{tags: tags})
      assert {:ok, process_specification} = ProcessSpecifications.create(user, attrs)
      assert_process_specification(process_specification)

      process_specification = CommonsPub.Repo.preload(process_specification, :tags)
      assert Enum.count(process_specification.tags) == Enum.count(tags)
    end
  end

  describe "update" do
    test "can update an existing process specification" do
      user = fake_user!()
      spec = fake_process_specification!(user)

      assert {:ok, updated} = ProcessSpecifications.update(spec, process_specification())
      assert_process_specification(updated)
      assert updated.updated_at != spec.updated_at
    end
  end

  describe "soft delete" do
    test "delete an existing process specification" do
      user = fake_user!()
      spec = fake_process_specification!(user)

      refute spec.deleted_at
      assert {:ok, spec} = ProcessSpecifications.soft_delete(spec)
      assert spec.deleted_at
    end

  end

end
