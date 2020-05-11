# MoodleNet: Connecting and empowering educators worldwide
# Copyright © 2018-2020 Moodle Pty Ltd <https://moodle.com/moodlenet/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule MoodleNet.FlagsTest do
  use MoodleNet.DataCase, async: true
  use Oban.Testing, repo: MoodleNet.Repo
  require Ecto.Query
  import MoodleNet.Test.Faking
  alias MoodleNet.Flags
  alias MoodleNet.Test.Fake

  setup do
    {:ok, %{user: fake_user!()}}
  end

  def fake_meta!() do
    user = fake_user!()
    community = fake_community!(user)
    collection = fake_collection!(user, community)
    resource = fake_resource!(user, collection)
    thread = fake_thread!(user, resource)
    comment = fake_comment!(user, thread)
    Faker.Util.pick([user, community, collection, resource, comment])
  end

  describe "flag/3" do
    test "a user can flag any meta object", %{user: flagger} do
      flagged = fake_meta!()
      assert {:ok, flag} = Flags.create(flagger, flagged, Fake.flag())
      assert flag.creator_id == flagger.id
      assert flag.context_id == flagged.id
      assert flag.message
    end
  end

  describe "flag/4" do
    test "creates a flag referencing a community", %{user: flagger} do
      user = fake_user!()
      community = fake_community!(user)
      collection = fake_collection!(user, community)
      assert {:ok, flag} = Flags.create(flagger, collection, community, Fake.flag())
      assert flag.context_id == collection.id
      assert flag.community_id == community.id
    end
  end

  describe "soft_delete/1" do
    test "soft deletes a flag", %{user: flagger} do
      thing = fake_meta!()
      assert {:ok, flag} = Flags.create(flagger, thing, Fake.flag())
      refute flag.deleted_at

      assert {:ok, flag} = Flags.soft_delete(flag)
      assert flag.deleted_at
    end
  end

end
