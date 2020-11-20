# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.FollowsTest do
  use CommonsPub.DataCase, async: true
  use Oban.Testing, repo: CommonsPub.Repo
  require Ecto.Query
  import CommonsPub.Utils.Simulation
  alias CommonsPub.Follows
  alias CommonsPub.Utils.Simulation

  setup do
    {:ok, %{user: fake_user!()}}
  end

  def fake_followable!() do
    user = fake_user!()
    community = fake_community!(user)
    collection = fake_collection!(user, community)
    thread = fake_thread!(user, collection)
    Faker.Util.pick([user, community, collection, thread])
  end

  describe "follow/3" do
    test "creates a follow for anything with an outbox", %{user: follower} do
      followed = fake_followable!()

      attrs = Simulation.follow(%{is_public: true, is_muted: false})
      assert {:ok, follow} = Follows.create(follower, followed, attrs)

      assert follow.creator_id == follower.id
      assert follow.context_id == followed.id
      assert follow.published_at
      refute follow.muted_at
    end

    # test "can mute a follow", %{user: follower} do
    #   followed = fake_meta!()
    #   assert {:ok, follow} = Common.follow(follower, followed, Simulation.follow(%{is_muted: true}))
    #   assert follow.muted_at
    # end

    test "fails to create a follow with missing attributes", %{user: follower} do
      followed = fake_followable!()
      assert {:error, _} = Follows.create(follower, followed, %{})
    end
  end

  describe "update/2" do
    test "updates the attributes of an existing follow", %{user: follower} do
      followed = fake_followable!()

      assert {:ok, follow} =
               Follows.create(follower, followed, Simulation.follow(%{is_public: false}))

      assert {:ok, updated_follow} =
               Follows.update(follower, follow, Simulation.follow(%{is_public: true}))

      assert follow != updated_follow
    end
  end

  describe "soft_delete/2" do
    test "removes a follower from a followed object", %{user: follower} do
      followed = fake_followable!()
      assert {:ok, follow} = Follows.create(follower, followed, Simulation.follow())
      refute follow.deleted_at

      assert {:ok, follow} = Follows.soft_delete(follower, follow)
      assert follow.deleted_at
    end
  end
end
