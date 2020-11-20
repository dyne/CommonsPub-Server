defmodule CommonsPub.PeersTest do
  use CommonsPub.DataCase
  alias CommonsPub.Peers
  # alias CommonsPub.Peers.Peer
  import CommonsPub.Utils.Simulation
  alias CommonsPub.Utils.Simulation

  describe "CRUD" do
    test "insertion and retrieval" do
      Repo.transaction(fn ->
        attrs = Simulation.peer()
        assert {:ok, peer} = Peers.create(attrs)
        assert {:ok, peer2} = Peers.fetch(peer.id)
        assert Map.drop(peer, [:is_disabled]) == Map.drop(peer2, [:is_disabled])
      end)
    end

    test "updates" do
      Repo.transaction(fn ->
        peer = fake_peer!()

        attrs =
          peer
          |> Map.from_struct()
          |> Map.delete(:ap_url_base)
          |> Simulation.peer()

        assert {:ok, peer2} = Peers.update(peer, attrs)
        assert peer2.id == peer.id
        assert peer2.ap_url_base == attrs[:ap_url_base]
      end)
    end

    # TODO: chasing? discuss.
    test "soft deletion" do
      Repo.transaction(fn ->
        :ok
        peer = fake_peer!()
        assert {:ok, peer2} = Peers.soft_delete(peer)
        assert was_updated_since?(peer2, peer)
        # no deleted() ? not actually deleted, is it? -- jjl
        assert timeless(peer2) == timeless(peer)
      end)
    end

    # TODO: chasing
    @tag :skip
    test "hard deletion" do
      Repo.transaction(fn -> :ok end)
    end
  end
end
