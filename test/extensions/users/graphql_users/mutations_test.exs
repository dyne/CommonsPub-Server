# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Web.GraphQL.Users.MutationsTest do
  use CommonsPub.Web.ConnCase, async: true
  import CommonsPub.Utils.Simulation
  import CommonsPub.Web.Test.GraphQLAssertions
  import CommonsPub.Web.Test.GraphQLFields
  import CommonsPub.Test.Faking
  alias CommonsPub.{Access, Users}

  describe "create_user" do
    test "Works for a guest with good inputs" do
      reg = registration_input()
      assert {:ok, _} = Access.create_register_email(reg["email"])
      q = create_user_mutation()

      me =
        grumble_post_key(q, json_conn(), :create_user, %{
          user: reg,
          icon: content_input(),
          image: content_input()
        })

      assert_me_created(reg, me)
    end

    test "Does not work for a logged in user" do
      alice = fake_user!()
      reg = registration_input()
      assert {:ok, _} = Access.create_register_email(reg["email"])
      q = create_user_mutation()
      assert_not_permitted(grumble_post_errors(q, user_conn(alice), %{user: reg}), ["createUser"])
    end

    test "Does not work for a taken preferred username" do
      alice = fake_user!()

      reg = registration_input(%{"preferredUsername" => alice.character.preferred_username})

      assert {:ok, _} = Access.create_register_email(reg["email"])
      q = create_user_mutation()
      grumble_post_errors(q, json_conn(), %{user: reg})
    end

    test "Does not work for a taken email" do
      alice = fake_user!()
      reg = registration_input(%{"email" => alice.local_user.email})
      assert {:ok, _} = Access.create_register_email(reg["email"])
      q = create_user_mutation()
      grumble_post_errors(q, json_conn(), %{user: reg})
    end
  end

  describe "update user" do
    test "Works for a logged in user" do
      alice = fake_user!()
      conn = user_conn(alice)
      profile = profile_update_input()
      q = update_profile_mutation()
      vars = %{profile: profile}
      me = grumble_post_key(q, conn, :update_profile, vars)
      assert_me_updated(profile, me)
    end

    test "Does not work for a guest" do
      q = update_profile_mutation()
      vars = %{profile: profile_update_input()}
      assert_not_logged_in(grumble_post_errors(q, json_conn(), vars), ["updateProfile"])
    end
  end

  describe "delete_self" do
    test "Works for a logged in user" do
      alice = fake_user!()
      conn = user_conn(alice)
      q = delete_self_mutation()
      assert true == grumble_post_key(q, conn, :delete_self, %{i_am_sure: true})
    end

    test "Does not work if you are unsure" do
      alice = fake_user!()
      conn = user_conn(alice)
      q = delete_self_mutation()
      grumble_post_errors(q, conn)
    end

    test "Does not work for a guest" do
      q = delete_self_mutation()

      assert_not_logged_in(grumble_post_errors(q, json_conn(), %{i_am_sure: true}), ["deleteSelf"])
    end
  end

  describe "reset_password_request" do
    test "Works for a guest" do
      alice = fake_user!()
      q = reset_password_request_mutation()
      vars = %{email: alice.local_user.email}
      assert true == grumble_post_key(q, json_conn(), :reset_password_request, vars)
      # TODO: check that an email is sent
    end

    test "Does not work for a user" do
      alice = fake_user!()
      conn = user_conn(alice)
      q = reset_password_request_mutation()
      vars = %{email: alice.local_user.email}
      assert_not_permitted(grumble_post_errors(q, conn, vars), ["resetPasswordRequest"])
      # TODO: check that an email is not sent
    end

    test "Does not work for an invalid email" do
      q = reset_password_request_mutation()
      vars = %{email: email()}
      assert_not_found(grumble_post_errors(q, json_conn(), vars), ["resetPasswordRequest"])
    end
  end

  describe "reset_password" do
    test "Works for a guest with a valid token" do
      alice = fake_user!()
      assert {:ok, %{id: token}} = Users.request_password_reset(alice)
      q = reset_password_mutation()
      vars = %{token: token, password: "password"}
      auth = assert_auth_payload(grumble_post_key(q, json_conn(), :reset_password, vars))
      assert_me(alice, auth.me)
    end

    test "Does not work with a used token" do
      alice = fake_user!()
      assert {:ok, %{id: token}} = Users.request_password_reset(alice)
      q = reset_password_mutation()
      vars = %{token: token, password: "password"}
      auth = assert_auth_payload(grumble_post_key(q, json_conn(), :reset_password, vars))
      assert_me(alice, auth.me)
      grumble_post_errors(q, json_conn(), vars)
    end

    test "Does not work for a user" do
      alice = fake_user!()
      conn = user_conn(alice)
      assert {:ok, %{id: token}} = Users.request_password_reset(alice)
      q = reset_password_mutation()
      vars = %{token: token, password: "password"}
      assert_not_permitted(grumble_post_errors(q, conn, vars), ["resetPassword"])
    end
  end

  describe "confirm_email" do
    test "Works for a guest with a valid token" do
      alice = fake_user!()
      [token] = alice.local_user.email_confirm_tokens
      q = confirm_email_mutation()
      vars = %{token: token.id}
      conn = json_conn()
      auth = assert_auth_payload(grumble_post_key(q, conn, :confirm_email, vars))
      assert_me(alice, auth.me)
    end

    test "Does not work with an authenticated user" do
      alice = fake_user!()
      [token] = alice.local_user.email_confirm_tokens
      q = confirm_email_mutation()
      vars = %{token: token.id}
      conn = user_conn(alice)
      assert_not_permitted(grumble_post_errors(q, conn, vars), ["confirmEmail"])
    end

    test "Fails with an invalid token" do
      q = confirm_email_mutation()
      vars = %{token: uuid()}
      assert_not_found(grumble_post_errors(q, json_conn(), vars), ["confirmEmail"])
    end
  end

  describe "create_session" do
    test "Works with a valid email and password" do
      alice = fake_user!(%{password: "password"}, confirm_email: true)
      q = create_session_mutation()
      vars = %{email: alice.local_user.email, password: "password"}
      auth = assert_auth_payload(grumble_post_key(q, json_conn(), :create_session, vars))
      assert_me(alice, auth.me)
    end

    test "Does not work with an unconfirmed email" do
      alice = fake_user!(%{password: "password"}, confirm_email: false)
      q = create_session_mutation()
      vars = %{email: alice.local_user.email, password: "password"}
      grumble_post_errors(q, json_conn(), vars)
    end
  end

  describe "delete_session" do
    test "Works with a logged in user" do
      user = fake_user!(%{password: "password"}, confirm_email: true)
      assert {:ok, token} = Access.create_token(user, "password")
      conn = token_conn(token)
      q = delete_session_mutation()
      assert true == grumble_post_key(q, conn, :delete_session)
    end

    test "Does not work for a guest" do
      q = delete_session_mutation()
      assert_not_logged_in(grumble_post_errors(q, json_conn()), ["deleteSession"])
    end
  end
end
