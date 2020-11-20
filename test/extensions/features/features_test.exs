# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.FeaturesTest do
  use CommonsPub.DataCase, async: true
  use Oban.Testing, repo: CommonsPub.Repo
  require Ecto.Query
  import CommonsPub.Utils.Simulation
  alias CommonsPub.Features

  def fake_featurable!() do
    user = fake_user!()
    community = fake_community!(user)
    collection = fake_collection!(user, community)
    Faker.Util.pick([community, collection])
  end

  describe "one/1" do
    test "works" do
      alice = fake_user!()
      comm = fake_community!(alice)
      assert {:ok, feat} = Features.create(alice, comm, %{is_local: true})
      assert feat.context_id == comm.id
      assert {:ok, feat2} = Features.one(id: feat.id)
      assert Map.delete(feat, :context) == Map.delete(feat2, :context)
    end
  end

  describe "create/3" do
    test "creates a feature for a collection" do
      alice = fake_user!()
      comm = fake_community!(alice)
      coll = fake_collection!(alice, comm)
      assert {:ok, feat} = Features.create(alice, coll, %{is_local: true})
      assert feat.context_id == coll.id
    end

    test "creates a feature for a community" do
      alice = fake_user!()
      comm = fake_community!(alice)
      assert {:ok, feat} = Features.create(alice, comm, %{is_local: true})
      assert feat.context_id == comm.id
    end
  end

  describe "delete/1" do
    test "removes a feature" do
      alice = fake_user!()
      comm = fake_community!(alice)
      assert {:ok, feat} = Features.create(alice, comm, %{is_local: true})
      assert feat.context_id == comm.id
      assert {:ok, feat2} = Features.one(id: feat.id)
      assert Map.delete(feat, :context) == Map.delete(feat2, :context)
      assert {:ok, _} = Features.soft_delete(alice, feat)
      assert {:error, _} = Features.one(deleted: false, id: feat.id)
    end
  end
end
