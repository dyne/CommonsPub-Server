defmodule CommonsPub.Workers.APPpublishWorkerTest do
  use CommonsPub.DataCase

  import ActivityPub.Factory
  import CommonsPub.Test.Faking
  alias CommonsPub.Workers.APPublishWorker

  describe "false locality checks" do
    test "it doesn't federate remote resource" do
      actor = actor()
      collection = collection()

      object = %{
        "name" => "resource",
        "url" => "http://www.guidetojapanese.org/grammar_guide.pdf",
        "actor" => actor.ap_id,
        "attributedTo" => actor.ap_id,
        "context" => collection.ap_id,
        "type" => "Document",
        "tag" => "GPL-v3",
        "summary" => "this is a resource",
        "icon" => "https://icon.store/picture.png"
      }

      params = %{
        actor: actor,
        to: ["https://www.w3.org/ns/activitystreams#Public"],
        object: object,
        context: collection.ap_id,
        additional: %{
          "cc" => [collection.data["followers"], actor.data["followers"]]
        },
        local: false
      }

      {:ok, activity} = ActivityPub.create(params)
      assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :ap_incoming)

      assert {:ok, resource} =
               CommonsPub.Repo.fetch_by(CommonsPub.Resources.Resource, %{
                 canonical_url: activity.object.data["id"]
               })

      assert :ignored = APPublishWorker.perform(%{args: %{"context_id" => resource.id, "op" => "create"}})
    end

    test "it doesn't federate remote communities" do
      community = community()
      {:ok, community} = CommonsPub.Communities.one([:default, username: community.username])

      assert :ignored = APPublishWorker.perform(%{args: %{"context_id" => community.id, "op" => "create"}})
    end

    test "it doesn't federate remote follows" do
      follower = actor()
      followed = fake_user!() |> fake_community!()
      {:ok, ap_followed} = ActivityPub.Actor.get_by_local_id(followed.id)
      {:ok, _} = ActivityPub.follow(follower, ap_followed, nil, false)
      assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :ap_incoming)
      {:ok, follower} = CommonsPub.ActivityPub.Adapter.get_actor_by_ap_id(follower.ap_id)
      {:ok, follow} = CommonsPub.Follows.one(creator: follower.id, context: followed.id)

      assert :ignored = APPublishWorker.perform(%{args: %{"context_id" => follow.id, "op" => "create"}})
    end
  end

  describe "true locality checks" do
    test "it does federate local comments" do
      user = fake_user!()
      community = fake_community!(user)
      thread = fake_thread!(user, community)
      comment = fake_comment!(user, thread, %{is_local: true})

      assert {:ok, _} = APPublishWorker.perform(%{args: %{"context_id" => comment.id, "op" => "create"}})
    end

    test "it does federate local resources" do
      user = fake_user!()
      community = fake_community!(user)
      collection = fake_collection!(user, community)
      resource = fake_resource!(user, collection)

      assert {:ok, _} = APPublishWorker.perform(%{args: %{"context_id" => resource.id, "op" => "create"}})
    end

    test "it does federate local communities" do
      community = fake_user!() |> fake_community!()

      assert {:ok, _} = APPublishWorker.perform(%{args: %{"context_id" => community.id, "op" => "create"}})
    end

    test "it does federate local collections" do
      user = fake_user!()
      community = fake_community!(user)
      collection = fake_collection!(user, community)

      assert {:ok, _} =
               APPublishWorker.perform(%{args: %{"context_id" => collection.id, "op" => "create"}})
    end

    test "it does federate local follows" do
      user = fake_user!()
      community = fake_user!() |> fake_community!()

      {:ok, follow} = CommonsPub.Follows.create(user, community, %{is_local: true})

      assert {:ok, _} = APPublishWorker.perform(%{args: %{"context_id" => follow.id, "op" => "create"}})
    end

    test "it does federate local likes" do
      user = fake_user!()
      community = fake_community!(user)
      user2 = fake_user!()
      thread = fake_thread!(user2, community)
      comment = fake_comment!(user2, thread, %{is_local: true})
      Oban.drain_queue(queue: :mn_ap_publish)

      {:ok, like} = CommonsPub.Likes.create(user, comment, %{is_local: true})
      # IO.inspect(like)

      assert {:ok, _, _} = APPublishWorker.perform(%{args: %{"context_id" => like.id, "op" => "create"}})
    end
  end

  describe "deletes" do
    test "/ federates an undo follow activity" do
      user = fake_user!()
      community = fake_user!() |> fake_community!()
      {:ok, follow} = CommonsPub.Follows.create(user, community, %{is_local: true})
      Oban.drain_queue(queue: :mn_ap_publish)
      {:ok, deleted_follow} = CommonsPub.Follows.soft_delete(user, follow)

      assert {:ok, activity} =
               APPublishWorker.perform(%{args: %{"context_id" => deleted_follow.id, "op" => "delete"}})

      assert activity.data["type"] == "Undo"
    end

    test "/ federates an undo like activity" do
      user = fake_user!()
      community = fake_community!(user)
      user2 = fake_user!()
      thread = fake_thread!(user2, community)
      comment = fake_comment!(user2, thread, %{is_local: true})
      Oban.drain_queue(queue: :mn_ap_publish)
      {:ok, like} = CommonsPub.Likes.create(user, comment, %{is_local: true})
      Oban.drain_queue(queue: :mn_ap_publish)
      {:ok, deleted_like} = CommonsPub.Likes.soft_delete(user, like)

      assert {:ok, activity, _, _} =
               APPublishWorker.perform(%{args: %{"context_id" => deleted_like.id, "op" => "delete"}})

      assert activity.data["type"] == "Undo"
    end

    test "user" do
      user = fake_user!()
      {:ok, _deleted} = CommonsPub.Users.soft_delete(user, user)

      assert {:ok, activity} =
               APPublishWorker.perform(%{args: %{"context_id" => user.id, "op" => "delete"}})

      assert activity.data["type"] == "Delete"
    end

    test "community" do
      user = fake_user!()
      comm = fake_community!(user)
      {:ok, _deleted} = CommonsPub.Communities.soft_delete(user, comm)

      assert {:ok, activity} =
               APPublishWorker.perform(%{args: %{"context_id" => comm.id, "op" => "delete"}})

      assert activity.data["type"] == "Delete"
    end

    test "collection" do
      user = fake_user!()
      comm = fake_community!(user)
      coll = fake_collection!(user, comm)
      {:ok, _deleted} = CommonsPub.Collections.soft_delete(user, coll)

      assert {:ok, activity} =
               APPublishWorker.perform(%{args: %{"context_id" => coll.id, "op" => "delete"}})

      assert activity.data["type"] == "Delete"
    end

    test "comment" do
      user = fake_user!()
      community = fake_community!(user)
      thread = fake_thread!(user, community)
      comment = fake_comment!(user, thread, %{is_local: true})
      Oban.drain_queue(queue: :mn_ap_publish)
      {:ok, _deleted} = CommonsPub.Threads.Comments.soft_delete(user, comment)

      assert {:ok, activity} =
               APPublishWorker.perform(%{args: %{"context_id" => comment.id, "op" => "delete"}})

      assert activity.data["type"] == "Delete"
    end

    test "resource" do
      user = fake_user!()
      community = fake_community!(user)
      collection = fake_collection!(user, community)
      resource = fake_resource!(user, collection)
      Oban.drain_queue(queue: :mn_ap_publish)
      {:ok, _deleted} = CommonsPub.Resources.soft_delete(user, resource)

      assert {:ok, activity} =
               APPublishWorker.perform(%{args: %{"context_id" => resource.id, "op" => "delete"}})

      assert activity.data["type"] == "Delete"
    end
  end

  describe "updates" do
    test "user" do
      user = fake_user!()
      {:ok, user} = CommonsPub.Users.update(user, %{name: "Cool Name"})

      assert {:ok, activity} =
               APPublishWorker.perform(%{args: %{"context_id" => user.id, "op" => "update"}})

      assert activity.data["type"] == "Update"
      assert activity.data["object"]["name"] == "Cool Name"
    end

    test "community" do
      user = fake_user!()
      comm = fake_community!(user)
      {:ok, comm} = CommonsPub.Communities.update(user, comm, %{name: "Cool Name"})

      assert {:ok, activity} =
               APPublishWorker.perform(%{args: %{"context_id" => comm.id, "op" => "update"}})

      assert activity.data["type"] == "Update"
      assert activity.data["object"]["name"] == "Cool Name"
    end

    test "collection" do
      user = fake_user!()
      comm = fake_community!(user)
      coll = fake_collection!(user, comm)
      {:ok, coll} = CommonsPub.Collections.update(user, coll, %{name: "Cool Name"})

      assert {:ok, activity} =
               APPublishWorker.perform(%{args: %{"context_id" => coll.id, "op" => "update"}})

      assert activity.data["type"] == "Update"
      assert activity.data["object"]["name"] == "Cool Name"
    end
  end

  describe "batch enqueue" do
    test "works" do
      require Ecto.Query
      ids = [Ecto.ULID.generate(), Ecto.ULID.generate(), Ecto.ULID.generate()]
      APPublishWorker.batch_enqueue("create", ids)
      res = CommonsPub.Repo.all(Ecto.Query.from(Oban.Job))
      assert length(res) == 3
      Enum.map(res, fn job -> assert job.args["op"] == "create" end)
    end
  end
end
