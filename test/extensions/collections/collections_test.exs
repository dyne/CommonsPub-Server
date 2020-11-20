# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.CollectionsTest do
  use CommonsPub.DataCase, async: true

  import CommonsPub.Utils.Simulation
  alias CommonsPub.Common.NotFoundError
  alias CommonsPub.{Collections, Communities}
  alias CommonsPub.Utils.Simulation

  setup do
    user = fake_user!()
    community = fake_community!(user)
    collection = fake_collection!(user, community)
    {:ok, %{user: user, community: community, collection: collection}}
  end

  describe "one" do
    test "returns a collection by ID", context do
      assert {:ok, coll} = Collections.one(id: context.collection.id)
      assert coll.id == context.collection.id
      assert coll.character
      assert coll.creator
    end

    test "fails when it has been deleted", context do
      assert {:ok, collection} = Collections.soft_delete(context.user, context.collection)

      assert {:error, %NotFoundError{}} =
               Collections.one(deleted: false, id: context.collection.id)
    end

    @tag :skip
    test "fails when the parent community has been deleted", context do
      assert collection = fake_collection!(context.user, context.community)
      assert {:ok, _} = Communities.soft_delete(context.user, context.community)

      assert {:error, %NotFoundError{}} =
               Collections.one(deleted: false, id: context.collection.id)
    end

    test "fails with a missing ID" do
      assert {:error, %NotFoundError{}} = Collections.one(id: Simulation.ulid())
    end
  end

  describe "create" do
    test "creates a new collection", context do
      attrs = Simulation.collection()

      assert {:ok, collection} = Collections.create(context.user, context.community, attrs)

      assert collection.name == attrs.name
      # assert collection.community_id == context.community.id
      assert collection.creator_id == context.user.id
      assert collection.character
    end

    test "fails if given invalid attributes", context do
      assert {:error, changeset} = Collections.create(context.user, context.community, %{})
    end
  end

  describe "update" do
    test "updates a collection with the given attributes", %{user: user, collection: collection} do
      attrs = Simulation.collection()
      assert {:ok, updated_collection} = Collections.update(user, collection, attrs)
      assert updated_collection.name == attrs.name
    end
  end

  describe "soft_delete" do
    test "works", context do
      refute context.collection.deleted_at
      assert {:ok, collection} = Collections.soft_delete(context.user, context.collection)
      assert collection.deleted_at
    end
  end
end
