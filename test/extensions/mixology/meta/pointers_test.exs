# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Meta.PointersTest do
  use ExUnit.Case, async: true

  import ExUnit.Assertions
  import CommonsPub.Utils.Simulation
  alias CommonsPub.{Access, Repo}

  alias CommonsPub.Meta.{
    Pointers,
    TableNotFoundError
  }

  alias CommonsPub.Peers.Peer

  describe "forge!" do
    setup do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(CommonsPub.Repo)
      {:ok, %{}}
    end

    test "forges a pointer for a peer" do
      peer = fake_peer!()
      pointer = Pointers.forge!(peer)
      assert pointer.id == peer.id
      assert pointer.pointed == peer
      assert pointer.table_id == pointer.table.id
      assert pointer.table.table == "mn_peer"
    end

    test "forges a pointer for a user" do
      user = fake_user!()
      pointer = Pointers.forge!(user)
      assert pointer.id == user.id
      assert pointer.pointed == user
      assert pointer.table_id == pointer.table.id
      assert pointer.table.table == "mn_user"
    end

    # TODO: others
    # @tag :skip
    # test "forges a pointer for a " do
    # end

    test "throws TableNotFoundError when given a non-meta table" do
      table = %Access.Token{}

      assert %TableNotFoundError{table: Access.Token} ==
               catch_throw(Pointers.forge!(table))
    end
  end

  describe "follow" do
    setup do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(CommonsPub.Repo)
      {:ok, %{}}
    end

    test "follows pointers" do
      Repo.transaction(fn ->
        assert peer = fake_peer!()
        assert pointer = Pointers.one!(id: peer.id)
        assert table = Pointers.table!(pointer)
        assert table.table == "mn_peer"
        assert table.schema == Peer
        assert table.id == pointer.table_id
        peer = Map.drop(peer, [:is_disabled])
        assert peer2 = Pointers.follow!(pointer)
        assert Map.drop(peer2, [:is_disabled]) == peer
      end)
    end

    test "preload! can load one pointer" do
      Repo.transaction(fn ->
        assert peer = fake_peer!() |> Map.drop([:is_disabled])
        assert pointer = Pointers.one!(id: peer.id)
        assert table = Pointers.table!(pointer)
        assert table.table == "mn_peer"
        assert table.schema == Peer
        assert table.id == pointer.table_id
        assert pointer2 = Pointers.preload!(pointer)
        assert Map.drop(pointer2.pointed, [:is_disabled]) == peer
        assert pointer2.id == pointer.id
        assert pointer2.table_id == pointer.table_id
        assert [pointer3] = Pointers.preload!([pointer])
        assert pointer2 == pointer3
      end)
    end

    test "preload! can load many pointers" do
      Repo.transaction(fn ->
        assert peer = fake_peer!()
        assert peer2 = fake_peer!()
        assert pointer = Pointers.one!(id: peer.id)
        assert pointer2 = Pointers.one!(id: peer2.id)
        assert [pointer3, pointer4] = Pointers.preload!([pointer, pointer2])
        assert pointer3.id == pointer.id
        assert pointer4.id == pointer2.id
        assert pointer3.table_id == pointer.table_id
        assert pointer4.table_id == pointer2.table_id
        assert Map.drop(pointer3.pointed, [:is_disabled]) == Map.drop(peer, [:is_disabled])
        assert Map.drop(pointer4.pointed, [:is_disabled]) == Map.drop(peer2, [:is_disabled])
      end)
    end

    # TODO: merge antonis' work and figure out preloads
    test "preload! can load many pointers of many types" do
      Repo.transaction(fn ->
        peer = fake_peer!()
        user = fake_user!()
        comm = fake_community!(user)
        thread = fake_thread!(user, comm)
        comment = fake_comment!(user, thread)
        assert pointer = Pointers.one!(id: peer.id)
        assert pointer2 = Pointers.one!(id: comm.id)
        assert pointer3 = Pointers.one!(id: user.id)
        assert pointer4 = Pointers.one!(id: comment.id)

        assert [pointer5, pointer6, pointer7, pointer8] =
                 Pointers.preload!([pointer, pointer2, pointer3, pointer4])

        assert pointer5.id == pointer.id
        assert pointer6.id == pointer2.id
        assert pointer7.id == pointer3.id
        assert pointer8.id == pointer4.id
        assert Map.drop(pointer5.pointed, [:is_disabled]) == Map.drop(peer, [:is_disabled])

        assert Map.drop(pointer6.pointed, [:is_disabled, :is_public, :character]) ==
                 Map.drop(comm, [:is_disabled, :is_public, :character])

        pointed7 =
          Map.drop(pointer7.pointed, [
            :character,
            :local_user,
            :email_confirm_tokens,
            :is_disabled,
            :is_public,
            :is_deleted,
            :canonical_url,
            :is_local,
            :preferred_username
          ])

        user2 =
          Map.drop(user, [
            :character,
            :local_user,
            :email_confirm_tokens,
            :is_disabled,
            :is_public,
            :is_deleted,
            :canonical_url,
            :is_local,
            :preferred_username
          ])

        assert pointed7 == user2

        pointed8 =
          Map.drop(pointer8.pointed, [
            :is_hidden,
            :is_public,
            :thread
          ])

        pointed8 = Map.drop(comment, [:is_hidden, :is_public, :thread, :creator])
        comment2 = Map.drop(comment, [:is_hidden, :is_public, :thread, :creator])

        assert pointed8 == comment2
      end)
    end
  end
end
