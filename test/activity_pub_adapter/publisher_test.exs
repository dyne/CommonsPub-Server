defmodule CommonsPub.ActivityPub.PublisherTest do
  use CommonsPub.DataCase
  import CommonsPub.Test.Faking
  import ActivityPub.Factory
  alias CommonsPub.ActivityPub.Publisher
  alias CommonsPub.Follows

  describe "comments" do
    test "it federates a comment that's threaded on an actor" do
      actor = fake_user!()
      commented_actor = fake_user!()
      thread = fake_thread!(actor, commented_actor)
      comment = fake_comment!(actor, thread)

      assert {:ok, activity} = Publisher.publish("create", comment)
      assert activity.object.pointer_id == comment.id
      assert activity.local == true
      assert activity.object.local == true

      {:ok, actor} =
        ActivityPub.Actor.get_by_username(commented_actor.character.preferred_username)

      assert activity.data["context"] == actor.ap_id
    end

    test "it federates a reply to a comment" do
      actor = fake_user!()
      reply_actor = fake_user!()
      commented_actor = fake_user!()
      thread = fake_thread!(actor, commented_actor, %{is_local: true})
      comment = fake_comment!(actor, thread)
      # Publish the comment first so we can reply to it
      Publisher.publish("create", comment)

      {:ok, reply} =
        CommonsPub.Threads.Comments.create_reply(reply_actor, thread, comment, %{
          content: "test",
          is_local: true
        })

      assert {:ok, activity} = Publisher.publish("create", reply)
      assert activity.object.data["inReplyTo"]
      assert activity.data["actor"] not in activity.object.data["to"]
      assert length(activity.object.data["to"]) == 3
    end

    test "it deletes a comment" do
      actor = fake_user!()
      commented_actor = fake_user!()
      thread = fake_thread!(actor, commented_actor, %{is_local: true})
      comment = fake_comment!(actor, thread)
      # Publish the comment first so we can delete it
      Publisher.publish("create", comment)

      assert {:ok, activity} = Publisher.publish("delete", comment)
    end
  end

  describe "creating resources" do
    test "it federates a resource" do
      actor = fake_user!()
      community = fake_community!(actor)
      collection = fake_collection!(actor, community)
      resource = fake_resource!(actor, collection)

      assert {:ok, activity} = Publisher.publish("create", resource)
      assert activity.object.pointer_id == resource.id
      assert activity.local == true
      assert activity.object.local == true
      {:ok, collection} = ActivityPub.Actor.get_by_local_id(collection.id)
      {:ok, actor} = ActivityPub.Actor.get_by_local_id(actor.id)
      assert activity.data["context"] == collection.ap_id
      assert activity.data["actor"] == actor.ap_id
      {:ok, resource} = CommonsPub.Resources.one(id: resource.id)
      assert resource.canonical_url == activity.object.data["id"]
    end

    test "it deletes a resource" do
      actor = fake_user!()
      community = fake_community!(actor)
      collection = fake_collection!(actor, community)
      resource = fake_resource!(actor, collection)
      Publisher.publish("create", resource)

      assert {:ok, activity} = Publisher.publish("delete", resource)
    end
  end

  describe "creating actors" do
    test "it federates a create activity for a community" do
      actor = fake_user!()
      community = fake_community!(actor)

      assert {:ok, activity} = Publisher.publish("create", community)
      assert activity.data["object"]["type"] == "Group"
      assert activity.data["object"]["id"]
      {:ok, community} = CommonsPub.Communities.one([:default, id: community.id])
      assert community.character.canonical_url == activity.data["object"]["id"]
    end

    test "it federate a create activity for a collection" do
      actor = fake_user!()
      community = fake_community!(actor)
      collection = fake_collection!(actor, community)

      assert {:ok, activity} = CommonsPub.Collections.ap_publish_activity("create", collection)
      assert activity.data["object"]["type"] == "Group"
      assert activity.data["object"]["id"]
      {:ok, collection} = CommonsPub.Collections.one([:default, id: collection.id])
      assert collection.character.canonical_url == activity.data["object"]["id"]
    end
  end

  describe "follows" do
    test "it federates a follow of a remote actor" do
      follower = fake_user!()
      ap_followed = actor()
      {:ok, followed} = CommonsPub.Users.one([:default, username: ap_followed.username])

      {:ok, follow} =
        CommonsPub.Follows.create(follower, followed, %{
          is_muted: false,
          is_public: true,
          is_local: true
        })

      assert {:ok, activity} = Publisher.publish("create", follow)
      assert activity.data["to"] == [ap_followed.ap_id]
    end

    test "it federate an unfollow of a remote actor" do
      follower = fake_user!()
      ap_followed = actor()
      {:ok, followed} = CommonsPub.Users.one([:default, username: ap_followed.username])

      {:ok, follow} =
        CommonsPub.Follows.create(follower, followed, %{
          is_muted: false,
          is_public: true,
          is_local: true
        })

      {:ok, follow_activity} = Publisher.publish("create", follow)
      {:ok, unfollowed} = Follows.soft_delete(follower, follow)

      assert {:ok, unfollow_activity} = Publisher.publish("delete", unfollowed)
      assert unfollow_activity.data["object"]["id"] == follow_activity.data["id"]
    end

    test "it errors when remote account manually approves followers" do
      follower = fake_user!()
      ap_followed = actor(%{data: %{"manuallyApprovesFollowers" => true}})
      {:ok, followed} = CommonsPub.Users.one([:default, username: ap_followed.username])

      {:ok, follow} =
        CommonsPub.Follows.create(follower, followed, %{
          is_muted: false,
          is_public: true,
          is_local: true
        })

      assert {:error, "account is private"} = Publisher.publish("create", follow)
    end
  end

  describe "blocks" do
    test "it federates a block of a remote actor" do
      blocker = fake_user!()
      ap_blocked = actor()
      {:ok, blocked} = CommonsPub.Users.one([:default, username: ap_blocked.username])

      {:ok, block} =
        CommonsPub.Blocks.create(blocker, blocked, %{
          is_muted: false,
          is_public: true,
          is_blocked: false,
          is_local: true
        })

      assert {:ok, activity} = Publisher.publish("create", block)
      assert activity.data["to"] == [ap_blocked.ap_id]
    end

    test "it federate an unblock of a remote actor" do
      blocker = fake_user!()
      ap_blocked = actor()
      {:ok, blocked} = CommonsPub.Users.one([:default, username: ap_blocked.username])

      {:ok, block} =
        CommonsPub.Blocks.create(blocker, blocked, %{
          is_muted: false,
          is_public: true,
          is_blocked: false,
          is_local: true
        })

      {:ok, block_activity} = Publisher.publish("create", block)
      {:ok, unblock} = CommonsPub.Blocks.soft_delete(blocker, block)

      assert {:ok, unblock_activity} = Publisher.publish("delete", unblock)
      assert unblock_activity.data["object"]["id"] == block_activity.data["id"]
    end
  end

  describe "flags" do
    test "it flags an actor" do
      flagger = fake_user!()
      ap_flagged = actor()
      {:ok, flagged} = CommonsPub.ActivityPub.Adapter.get_actor_by_username(ap_flagged.username)

      {:ok, flag} =
        CommonsPub.Flags.create(flagger, flagged, %{
          message: "this is not cool",
          is_local: true
        })

      assert {:ok, activity} = Publisher.publish("create", flag)
    end

    test "it flags a community" do
      flagger = fake_user!()
      ap_flagged = community()
      {:ok, flagged} = CommonsPub.ActivityPub.Adapter.get_actor_by_username(ap_flagged.username)

      {:ok, flag} =
        CommonsPub.Flags.create(flagger, flagged, %{
          message: "this is not cool",
          is_local: true
        })

      assert {:ok, activity} = Publisher.publish("create", flag)
    end

    test "it flags a collection" do
      flagger = fake_user!()
      ap_flagged = collection()
      {:ok, flagged} = CommonsPub.ActivityPub.Adapter.get_actor_by_username(ap_flagged.username)

      {:ok, flag} =
        CommonsPub.Flags.create(flagger, flagged, %{
          message: "this is not cool",
          is_local: true
        })

      assert {:ok, activity} = Publisher.publish("create", flag)
    end

    test "it flags a comment" do
      actor = fake_user!()
      commented_actor = fake_user!()
      thread = fake_thread!(actor, commented_actor)
      comment = fake_comment!(actor, thread)
      # Comment needs to be published before the flag can be federated
      Publisher.publish("create", comment)

      {:ok, flag} =
        CommonsPub.Flags.create(commented_actor, comment, %{
          message: "this is not cool",
          is_local: true
        })

      assert {:ok, activity} = Publisher.publish("create", flag)
    end

    test "it flags a resource" do
      actor = fake_user!()
      community = fake_community!(actor)
      collection = fake_collection!(actor, community)
      resource = fake_resource!(actor, collection)
      flag_actor = fake_user!()
      Publisher.publish("create", resource)

      {:ok, flag} =
        CommonsPub.Flags.create(flag_actor, resource, %{
          message: "this is not cool",
          is_local: true
        })

      assert {:ok, activity} = Publisher.publish("create", flag)
    end
  end

  describe "likes" do
    test "it likes a comment" do
      actor = fake_user!()
      commented_actor = fake_user!()
      thread = fake_thread!(actor, commented_actor)
      comment = fake_comment!(actor, thread)
      # Comment needs to be published before it can be liked
      Publisher.publish("create", comment)

      {:ok, like} =
        CommonsPub.Likes.create(commented_actor, comment, %{is_public: true, is_local: true})

      assert {:ok, like_activity, object} = Publisher.publish("create", like)
      assert like_activity.data["object"] == object.data["id"]
    end

    test "it unlikes a comment" do
      actor = fake_user!()
      commented_actor = fake_user!()
      thread = fake_thread!(actor, commented_actor)
      comment = fake_comment!(actor, thread)
      # Comment needs to be published before it can be liked
      Publisher.publish("create", comment)

      {:ok, like} =
        CommonsPub.Likes.create(commented_actor, comment, %{is_public: true, is_local: true})

      Publisher.publish("create", like)
      # No context function for unliking
      assert {:ok, unlike_activity, like_activity, object} = Publisher.publish("delete", like)
      assert like_activity.data["object"] == object.data["id"]
      assert unlike_activity.data["object"] == like_activity.data
    end
  end

  describe "updating actors" do
    test "it works for users" do
      actor = fake_user!()
      assert {:ok, activity} = Publisher.publish("update", actor)
    end

    test "it works for communities" do
      actor = fake_user!() |> fake_community!()
      assert {:ok, activity} = Publisher.publish("update", actor)
    end

    test "it works for collections" do
      user = fake_user!()
      comm = fake_community!(user)
      actor = fake_collection!(user, comm)
      assert {:ok, activity} = Publisher.publish("update", actor)
    end
  end

  describe "deleting actors" do
    test "it works for users" do
      actor = fake_user!()
      assert {:ok, activity} = Publisher.publish("delete", actor)
    end

    test "it works for communities" do
      actor = fake_user!() |> fake_community!()
      assert {:ok, activity} = Publisher.publish("delete", actor)
    end

    test "it works for collections" do
      user = fake_user!()
      comm = fake_community!(user)
      actor = fake_collection!(user, comm)
      assert {:ok, activity} = Publisher.publish("delete", actor)
    end
  end
end
