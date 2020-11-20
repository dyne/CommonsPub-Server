
defmodule CommonsPub.ActivityPub.IntegrationTest do
  use CommonsPub.Web.ConnCase
  import ActivityPub.Factory
  import CommonsPub.Utils.Simulation
  import Tesla.Mock
  alias CommonsPub.ActivityPub.Adapter

  setup do
    mock(fn
      %{method: :post} -> %Tesla.Env{status: 200}
    end)

    :ok
  end

  describe "adapter integration" do
    test "serve AP actor" do
      user = fake_user!()

      conn =
        build_conn()
        |> get("/pub/actors/#{user.character.preferred_username}")
        |> response(200)
        |> Jason.decode!

        assert conn["preferredUsername"] == user.character.preferred_username
        assert conn["name"] == user.name
        assert conn["summary"] == user.summary
    end

    test "get external followers" do
      actor_1 = actor()
      actor_2 = actor()
      user = fake_user!()
      {:ok, ap_user} = Adapter.get_actor_by_id(user.id)

      ActivityPub.follow(actor_1, ap_user, nil, false)
      ActivityPub.follow(actor_2, ap_user, nil, false)
      Oban.drain_queue(queue: :ap_incoming)
      {:ok, followers} = ActivityPub.Actor.get_external_followers(ap_user)
      assert length(followers) == 2
    end

    test "publish to followers" do
      community = fake_user!() |> fake_community!()
      actor_1 = actor()
      actor_2 = actor()
      {:ok, ap_community} = ActivityPub.Actor.get_by_local_id(community.id)

      ActivityPub.follow(actor_1, ap_community, nil, false)
      ActivityPub.follow(actor_2, ap_community, nil, false)
      Oban.drain_queue(queue: :ap_incoming)

      activity =
        insert(:note_activity, %{
          actor: ap_community,
          data_attrs: %{"cc" => [ap_community.data["followers"]]}
        })

      assert :ok == ActivityPubWeb.Publisher.publish(ap_community, activity)
      assert %{failure: 0, success: 2} = Oban.drain_queue(queue: :federator_outgoing)
    end
  end
end
