# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.CommunitiesTest do
  use CommonsPub.DataCase, async: true

  import CommonsPub.Utils.Simulation
  alias CommonsPub.Utils.Simulation
  alias CommonsPub.Common.NotFoundError
  alias CommonsPub.Communities
  alias CommonsPub.Communities.Community

  describe "Communities.many/1" do
    test "returns a list of non-deleted communities" do
      user = fake_user!()
      all = for _ <- 1..5, do: fake_community!(user)

      deleted =
        Enum.reduce(all, [], fn comm, acc ->
          if Simulation.bool() do
            {:ok, comm} = Communities.soft_delete(user, comm)
            [comm | acc]
          else
            acc
          end
        end)

      {:ok, fetched} = Communities.many(deleted: false)

      assert Enum.count(all) - Enum.count(deleted) == Enum.count(fetched)

      for comm <- fetched do
        assert comm.character
        assert comm.follower_count
        refute comm.deleted_at
      end
    end
  end

  describe "Communities.one/1" do
    test "returns a community by ID when available" do
      user = fake_user!()
      community = fake_community!(user)
      assert {:ok, community = %Community{}} = Communities.one(id: community.id)
      assert community.character
      assert community.creator
    end

    test "fails if the community has been removed" do
      user = fake_user!()
      community = fake_community!(user)
      assert {:ok, community} = Communities.soft_delete(user, community)
      assert {:error, %NotFoundError{}} = Communities.one(deleted: false, id: community.id)
    end

    # Everything is public currently
    @tag :skip
    test "fails if the community is private" do
      community = fake_user!() |> fake_community!(nil, %{is_public: false})
      assert {:error, %NotFoundError{}} = Communities.one(id: community.id)
    end

    test "fails when given a missing ID" do
      assert {:error, %NotFoundError{}} = Communities.one(id: Simulation.ulid())
    end
  end

  describe "Communities.create/3" do
    test "creates a community valid attributes" do
      assert user = fake_user!()
      attrs = Simulation.community()
      assert {:ok, community} = Communities.create(user, attrs)
      assert community.name == attrs.name
      assert community.creator_id == user.id

      assert community.character.preferred_username ==
               String.replace(String.replace(attrs.preferred_username, ".", "-"), "_", "-")

      assert community.is_public == attrs.is_public
    end

    test "fails if given invalid attributes" do
      user = fake_user!()
      assert {:error, changeset} = Communities.create(user, %{})
      refute Enum.empty?(changeset.errors)
    end
  end

  describe "Communities.update/2" do
    @tag :skip
    test "works for the creator of the community" do
      # assert user = fake_user!()
      # assert community = fake_community!(user)
      # assert {:ok, updated_community} = Communities.update(community, %{is_public: false})
      # assert updated_community.id == community.id
      # refute updated_community.is_public
    end

    @tag :skip
    test "works for an instance admin" do
      # assert user = fake_user!()
      # assert community = fake_community!(user)
      # assert {:ok, updated_community} = Communities.update(community, %{is_public: false})
      # assert updated_community.id == community.id
      # refute updated_community.is_public
    end

    test "works" do
      assert user = fake_user!()
      assert community = fake_community!(user, nil, %{is_public: true})
      assert {:ok, updated_community} = Communities.update(user, community, %{is_public: false})
      assert updated_community.id == community.id
      refute updated_community.is_public
    end
  end

  describe "Communities.soft_delete/2" do
    test "works" do
      assert user = fake_user!()
      assert community = fake_community!(user)
      assert {:ok, deleted_community} = Communities.soft_delete(user, community)
      assert deleted_community.id == community.id
      assert deleted_community.deleted_at
    end
  end
end
