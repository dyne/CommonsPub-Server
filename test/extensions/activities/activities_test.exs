# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.ActivitiesTest do
  use CommonsPub.DataCase, async: true

  import CommonsPub.Utils.Simulation

  alias CommonsPub.Activities
  alias CommonsPub.Activities.Activity
  alias CommonsPub.Common.NotFoundError
  alias CommonsPub.Utils.Simulation

  setup do
    user = fake_user!()
    comm = fake_community!(user)
    {:ok, %{user: user, context: comm}}
  end

  describe "one" do
    test "can return an activity by ID", %{user: user, context: context} do
      activity = fake_activity!(user, context)
      assert {:ok, fetched} = Activities.one(id: activity.id)
      assert fetched.id == activity.id
    end

    test "can ignore activities that are unpublished", %{user: user, context: context} do
      activity = fake_activity!(user, context)
      assert {:ok, activity} = Activities.update(user, activity, %{is_public: false})
      assert {:error, %NotFoundError{}} = Activities.one(published: true, id: activity.id)
    end

    test "can ignore activities that are deleted", %{user: user, context: context} do
      activity = fake_activity!(user, context)
      assert {:ok, activity} = Activities.soft_delete(user, activity)
      assert {:error, %NotFoundError{}} = Activities.one(deleted: false, id: activity.id)
    end

    test "can return an activity by ID regardless of published or deleted status", %{
      user: user,
      context: context
    } do
      activity = fake_activity!(user, context)
      assert {:ok, activity} = Activities.one(id: activity.id)
      assert {:ok, activity} = Activities.update(user, activity, %{is_public: false})
      assert {:ok, activity} = Activities.one(id: activity.id)
      assert {:ok, activity} = Activities.soft_delete(user, activity)
      assert {:ok, _} = Activities.one(id: activity.id)
    end
  end

  describe "create" do
    test "creates a new activity", %{user: user, context: context} do
      attrs = Simulation.activity()
      assert {:ok, %Activity{} = activity} = Activities.create(user, context, attrs)
      assert activity.verb == attrs.verb
      assert activity.canonical_url == attrs.canonical_url
      assert activity.creator.id == user.id
      assert activity.context.id == context.id
    end

    test "fails if missing attributes", %{user: user, context: context} do
      assert {:error, changeset} = Activities.create(user, context, %{})
      assert Keyword.get(changeset.errors, :verb)
    end
  end

  describe "update" do
    test "updates an activity with new attributes", %{user: user, context: context} do
      activity = fake_activity!(user, context)
      assert attrs = Simulation.activity()
      assert {:ok, updated_activity} = Activities.update(user, activity, attrs)
      assert updated_activity != activity
      assert updated_activity.verb == attrs.verb
      assert updated_activity.canonical_url == attrs.canonical_url
    end
  end

  describe "soft_delete" do
    test "changes the deletion date of an activity", %{user: user, context: context} do
      activity = fake_activity!(user, context)
      refute activity.deleted_at
      assert {:ok, activity} = Activities.soft_delete(user, activity)
      assert activity.deleted_at
    end
  end
end
