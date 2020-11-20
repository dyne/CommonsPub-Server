# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.CharactersTest do
  use CommonsPub.DataCase, async: true

  import CommonsPub.Utils.Simulation
  alias CommonsPub.Repo

  alias CommonsPub.Characters

  # alias CommonsPub.Users

  alias CommonsPub.Common.NotFoundError
  alias CommonsPub.Utils.Simulation

  defp assert_character_equal(character, attrs) do
    assert character.canonical_url == attrs[:canonical_url]
    assert character.preferred_username == attrs[:preferred_username]
    assert character.signing_key == attrs[:signing_key]
  end

  describe "one" do
    test "returns an item by ID" do
      character = fake_character!()
      assert {:ok, fetched} = Characters.one(id: character.id)
      assert character == fetched
    end

    test "returns an item by username" do
      character = fake_character!()
      assert {:ok, fetched} = Characters.one(username: character.preferred_username)
      assert character == fetched
    end

    test "fails if item is missing" do
      assert {:error, %NotFoundError{}} = Characters.one(id: Simulation.ulid())
    end
  end

  describe "is_username_available?" do
    test "returns true if username is unused" do
      assert Characters.is_username_available?(Simulation.preferred_username())
    end

    test "returns false if username is used" do
      character = fake_character!()
      refute Characters.is_username_available?(character.preferred_username)
    end
  end

  describe "create" do
    test "creates a new character with a revision" do
      Repo.transaction(fn ->
        attrs = Simulation.character()
        character = fake_character!(attrs)
        assert_character_equal(character, attrs)
      end)
    end

    # test "drops invalid characters from preferred_username" do
    #  Repo.transaction(fn ->
    #    attrs = Simulation.character(%{preferred_username: "character&name"})
    #    assert {:ok, character} = Characters.create(attrs)
    #    assert character.preferred_username == "actorname"
    #  end)
    # end

    test "doesn't drop allowed characters from preferred_username" do
      Repo.transaction(fn ->
        attrs =
          Simulation.character(%{preferred_username: "character-name_underscore@instance.url"})

        peer = fake_peer!()
        character = fake_character!(Map.put(attrs, :peer_id, peer.id))

        assert character.preferred_username == "character-name_underscore@instance.url"
      end)
    end

    test "returns an error if there are missing required attributes" do
      Repo.transaction(fn ->
        invalid_attrs = Map.merge(Simulation.user(), %{name: nil})
        assert {:error, changeset} = fake_user!(invalid_attrs)
        assert Keyword.get(changeset.errors, :name)
      end)
    end

    test "returns an error if the username is duplicated" do
      Repo.transaction(fn ->
        character = fake_character!()

        assert {:error, errors} =
                 %{preferred_username: character.preferred_username}
                 |> Simulation.user()
                 |> fake_character!()

        assert errors == "Username already taken"
      end)
    end
  end

  describe "update" do
    test "updates an existing character with valid attributes" do
      Repo.transaction(fn ->
        user = fake_user!()
        original_attrs = Simulation.character()

        character = fake_character!(original_attrs)

        updated_attrs =
          original_attrs
          |> Map.take(~w(preferred_username signing_key)a)
          |> Simulation.character()

        assert {:ok, character} = Characters.update(user, character, updated_attrs)
        assert_character_equal(character, updated_attrs)
      end)
    end
  end
end
