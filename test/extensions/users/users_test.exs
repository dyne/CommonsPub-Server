# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.UsersTest do
  use CommonsPub.DataCase, async: true

  import CommonsPub.Utils.Simulation
  alias Ecto.Changeset
  alias CommonsPub.{Users, Access}
  alias CommonsPub.Access.NoAccessError
  alias CommonsPub.Common.NotFoundError

  alias CommonsPub.Users.{
    TokenAlreadyClaimedError,
    TokenExpiredError,
    User
  }

  alias CommonsPub.Utils.Simulation

  def assert_user_equal(user, attrs) do
    assert user.name == attrs.name
    assert user.character.preferred_username == attrs.preferred_username
    assert user.local_user.email == attrs.email
    assert user.local_user.wants_email_digest == attrs.wants_email_digest
    assert user.local_user.wants_notifications == attrs.wants_notifications
  end

  describe "one/1" do
    test "by id" do
      user = fake_user!()
      assert {:ok, fetched} = Users.one(preset: :character, id: user.id)
      assert fetched.id == user.id
      assert fetched.character.preferred_username
    end

    test "by username" do
      user = fake_user!()

      assert {:ok, fetched} =
               Users.one(preset: :character, username: user.character.preferred_username)

      assert fetched.id == user.id
      assert fetched.character.preferred_username
    end

    test "by email" do
      user = fake_user!()
      assert {:ok, fetched} = Users.one(preset: :local_user, email: user.local_user.email)
      assert fetched.id == user.id
      assert fetched.character.preferred_username
    end

    test "fails for missing" do
      assert {:error, %NotFoundError{}} = Users.one(id: Simulation.ulid())
    end
  end

  describe "register/1" do
    test "creates a user account with valid attrs when public registration is enabled" do
      Repo.transaction(fn ->
        attrs = Simulation.user()
        assert {:ok, user} = Users.register(attrs, public_registration: true)
        assert_user_equal(user, attrs)
        assert [token] = user.local_user.email_confirm_tokens
        assert nil == token.confirmed_at
      end)
    end

    test "creates a user account with valid attrs when email allowed" do
      Repo.transaction(fn ->
        attrs = Simulation.character(Simulation.user())
        assert {:ok, _} = Access.create_register_email(attrs.email)
        assert {:ok, user} = Users.register(attrs, public_registration: false)
        assert_user_equal(user, attrs)

        assert [token] = user.local_user.email_confirm_tokens
        assert nil == token.confirmed_at
      end)
    end

    test "creates a user account with valid attrs when domain is denied" do
      Repo.transaction(fn ->
        attrs = Simulation.character(Simulation.user())
        [_, domain] = String.split(attrs.email, "@", parts: 2)
        assert {:ok, _} = Access.create_register_email_domain(domain)
        assert {:ok, user} = Users.register(attrs, public_registration: false)
        assert_user_equal(user, attrs)

        assert [token] = user.local_user.email_confirm_tokens
        assert nil == token.confirmed_at
      end)
    end

    test "fails if the username is already taken" do
      Repo.transaction(fn ->
        assert user = fake_user!()

        attrs =
          %{preferred_username: user.character.preferred_username}
          |> Simulation.user()
          |> Simulation.character()

        assert {:error, "Username already taken"} =
                 Users.register(attrs, public_registration: true)
      end)
    end

    test "fails if the username is already taken with a different capitalisation" do
      Repo.transaction(fn ->
        assert user = fake_user!()

        attrs =
          %{preferred_username: String.upcase(user.character.preferred_username)}
          |> Simulation.user()
          |> Simulation.character()

        assert {:error, %Changeset{} = error} = Users.register(attrs, public_registration: true)
      end)
    end

    test "fails if the email is already taken" do
      Repo.transaction(fn ->
        assert user = fake_user!()

        attrs =
          %{email: user.local_user.email}
          |> Simulation.user()
          |> Simulation.character()

        assert {:error, %Changeset{} = error} = Users.register(attrs, public_registration: true)
      end)
    end

    test "fails if given invalid attributes" do
      Repo.transaction(fn ->
        invalid_attrs = Map.delete(Simulation.user(), :email)
        assert {:error, changeset} = Users.register(invalid_attrs, public_registration: true)
        assert Keyword.get(changeset.errors, :email)
      end)
    end

    test "fails if the user's email is not denied - email allowed" do
      Repo.transaction(fn ->
        attrs = Simulation.character(Simulation.user())

        assert {:error, %NoAccessError{}} = Users.register(attrs, public_registration: false)
      end)
    end
  end

  describe "claim_confirm_email_token/2" do
    test "confirms a user's email" do
      assert user = fake_user!()
      assert [token] = user.local_user.email_confirm_tokens
      assert {:ok, %User{} = user} = Users.claim_email_confirm_token(token.id)
      assert user.local_user.confirmed_at
    end

    test "will not confirm if the token is expired" do
      assert user = fake_user!()
      assert [token] = user.local_user.email_confirm_tokens
      assert then = DateTime.add(DateTime.utc_now(), 60 * 60 * 49, :second)

      assert {:error, %TokenExpiredError{} = error} =
               Users.claim_email_confirm_token(token.id, then)
    end

    test "will not claim twice" do
      assert user = fake_user!()
      assert [token] = user.local_user.email_confirm_tokens
      assert {:ok, %User{} = user} = Users.claim_email_confirm_token(token.id)

      assert {:error, %TokenAlreadyClaimedError{} = error} =
               Users.claim_email_confirm_token(token.id)
    end
  end

  describe "confirm_email/1" do
    test "sets the confirmed date" do
      Repo.transaction(fn ->
        assert user = fake_user!()
        assert user.local_user.confirmed_at == nil
        assert {:ok, user2} = Users.confirm_email(user)
        assert %DateTime{} = user2.local_user.confirmed_at
      end)
    end
  end

  describe "unconfirm_email/1" do
    test "unsets the confirmed date" do
      Repo.transaction(fn ->
        assert user = fake_user!()
        assert user.local_user.confirmed_at == nil

        assert {:ok, user2} = Users.confirm_email(user)
        assert %DateTime{} = user2.local_user.confirmed_at
        assert {:ok, user3} = Users.unconfirm_email(user)
        refute user3.local_user.confirmed_at
        assert timeless(user.local_user) == timeless(user3.local_user)
      end)
    end
  end

  describe "request_password_reset" do
    test "creates a reset password token for a valid user" do
      user = fake_user!()
      assert {:ok, token} = Users.request_password_reset(user)
      assert token.local_user_id == user.local_user_id
      assert token.expires_at
      refute token.reset_at
    end
  end

  describe "claim_password_reset" do
    test "claims a reset token and changes the password" do
      user = fake_user!()
      assert {:ok, token} = Users.request_password_reset(user)
      refute token.reset_at
      assert {:ok, _} = Users.claim_password_reset(token.id, "password")

      assert {:ok, updated_user} = Users.one([:default, id: user.id])
      assert updated_user.local_user.password_hash != user.local_user.password_hash
    end
  end

  describe "update/2" do
    test "updates attributes of user and relations" do
      user = fake_user!()
      attrs = Simulation.user()
      assert {:ok, user} = Users.update(user, attrs)
      assert user.name == attrs.name
      assert user.local_user.email == attrs.email
      assert user.local_user.wants_email_digest == attrs.wants_email_digest
    end
  end

  describe "soft_delete/1" do
    test "updates the deletion timestamp" do
      user = fake_user!()
      refute user.deleted_at
      assert {:ok, user} = Users.soft_delete(user, user)
      assert user = Users.preload(user)
      assert user.deleted_at
      assert user.local_user.deleted_at
    end
  end

  describe "make_instance_admin/1" do
    test "changes the admin status of a user" do
      user = fake_user!()
      refute user.local_user.is_instance_admin
      assert {:ok, user} = Users.make_instance_admin(user)
      assert user.local_user.is_instance_admin
    end
  end

  describe "unmake_instance_admin/1" do
    test "removes admin status from a user" do
      user = fake_user!()
      assert {:ok, user} = Users.make_instance_admin(user)
      assert user.local_user.is_instance_admin
      assert {:ok, user} = Users.unmake_instance_admin(user)
      refute user.local_user.is_instance_admin
    end
  end

  # describe "user flags" do
  #   test "works" do
  #     character = Fcharactery.character()
  #     character_id = local_id(character)
  #     user = Fcharactery.character()
  #     user_id = local_id(user)

  #     assert [] = Users.all_flags(character)

  #     {:ok, _activity} = Users.flag(character, user, %{reason: "Terrible joke"})

  #     assert [flag] = Users.all_flags(character)
  #     assert flag.flagged_object_id == user_id
  #     assert flag.flagging_object_id == character_id
  #     assert flag.reason == "Terrible joke"
  #     assert flag.open == true
  #   end
  # end
end
