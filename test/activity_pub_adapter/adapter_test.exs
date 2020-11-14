defmodule CommonsPub.ActivityPub.AdapterTest do
  import CommonsPub.Test.Faking
  use CommonsPub.DataCase

  describe "fetching local actors by id" do
    test "users" do
      user = fake_user!()
      {:ok, actor} = ActivityPub.Actor.get_by_local_id(user.id)
      assert actor.data["type"] == "Person"
      assert actor.username == user.character.preferred_username
    end

    test "communities" do
      user = fake_user!()
      community = fake_community!(user)
      {:ok, actor} = ActivityPub.Actor.get_by_local_id(community.id)
      assert actor.data["type"] == "Group"
      assert actor.username == community.character.preferred_username
      assert actor.data["attributedTo"]
    end

    test "collections" do
      user = fake_user!()
      community = fake_community!(user)
      collection = fake_collection!(user, community)
      {:ok, actor} = ActivityPub.Actor.get_by_local_id(collection.id)
      assert actor.data["type"] == "MN:Collection"
      assert actor.username == collection.character.preferred_username
      assert actor.data["attributedTo"]
      assert actor.data["context"]
    end
  end

  describe "fetching local actors by username" do
    test "users" do
      user = fake_user!()
      {:ok, actor} = ActivityPub.Actor.get_by_username(user.character.preferred_username)
      assert actor.data["type"] == "Person"
      assert actor.username == user.character.preferred_username
    end

    test "communities" do
      user = fake_user!()
      community = fake_community!(user)
      {:ok, actor} = ActivityPub.Actor.get_by_username(community.character.preferred_username)
      assert actor.data["type"] == "Group"
      assert actor.username == community.character.preferred_username
      assert actor.data["attributedTo"]
    end

    test "collections" do
      user = fake_user!()
      community = fake_community!(user)
      collection = fake_collection!(user, community)
      # IO.inspect(collection)
      {:ok, actor} = ActivityPub.Actor.get_by_username(collection.character.preferred_username)
      assert actor.data["type"] == "MN:Collection"
      assert actor.username == collection.character.preferred_username
      assert actor.data["attributedTo"]
      assert actor.data["context"]
    end
  end

end
