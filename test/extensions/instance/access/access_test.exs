# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.AccessTest do
  use CommonsPub.DataCase, async: true

  import CommonsPub.Utils.Simulation
  alias Ecto.Changeset
  alias CommonsPub.Common.NotFoundError
  alias CommonsPub.Utils.Simulation
  alias CommonsPub.Access

  alias CommonsPub.Access.{
    TokenExpiredError,
    TokenNotFoundError,
    UserEmailNotConfirmedError,
    RegisterEmailDomainAccess,
    RegisterEmailAccess
  }

  defp strip(user),
    do:
      Map.drop(user, [
        :character,
        :email_confirm_tokens,
        :auth,
        :user,
        :local_user,
        :is_disabled,
        :is_public
      ])

  describe "CommonsPub.Access.create_register_email_domain/1" do
    test "can be found with find_register_email_domain after success" do
      Repo.transaction(fn ->
        domain = Simulation.domain()

        assert {:ok, %RegisterEmailDomainAccess{} = wl} =
                 Access.create_register_email_domain(domain)

        assert wl.domain == domain
        assert {:ok, wl} == Access.find_register_email_domain(domain)
      end)
    end

    test "fails helpfully with invalid data" do
      Repo.transaction(fn ->
        invalid = Simulation.email()
        assert {:error, %Changeset{} = cs} = Access.create_register_email_domain(invalid)
        assert [{:domain, {"is of the wrong format", [validation: :format]}}] == cs.errors
      end)
    end
  end

  describe "CommonsPub.Access.create_register_email/1" do
    test "can be found with find_register_email after success" do
      Repo.transaction(fn ->
        email = Simulation.email()
        assert {:ok, %RegisterEmailAccess{} = wl} = Access.create_register_email(email)
        assert wl.email == email
        assert {:ok, wl} == Access.find_register_email(email)
      end)
    end

    # TODO: validate emails better
    test "fails helpfully with invalid data" do
      Repo.transaction(fn ->
        invalid = Simulation.icon()
        assert {:error, %Changeset{} = cs} = Access.create_register_email(invalid)
        assert [email: {"is of the wrong format", [validation: :format]}] == cs.errors
      end)
    end
  end

  describe "CommonsPub.Access.list_register_email_domains/0" do
    test "returns the correct data" do
      Repo.transaction(fn ->
        assert [] == Access.list_register_email_domains()
        a = fake_register_email_domain_access!()
        b = fake_register_email_domain_access!()
        assert ret = Access.list_register_email_domains()
        assert is_list(ret)
        assert Enum.sort([a, b]) == Enum.sort(ret)
      end)
    end
  end

  describe "CommonsPub.Access.list_register_emails/0" do
    test "returns the correct data" do
      Repo.transaction(fn ->
        assert [] == Access.list_register_emails()
        a = fake_register_email_access!()
        b = fake_register_email_access!()
        assert ret = Access.list_register_emails()
        assert is_list(ret)
        assert Enum.sort([a, b]) == Enum.sort(ret)
      end)
    end
  end

  describe "CommonsPub.Access.is_register_accessed?/1" do
    test "returns true when the email's domain is accessed" do
      Repo.transaction(fn ->
        domain = fake_register_email_domain_access!().domain
        email = Simulation.email_user() <> "@" <> domain
        assert true == Access.is_register_accessed?(email)
      end)
    end

    test "returns true when the email is accessed" do
      Repo.transaction(fn ->
        email = fake_register_email_access!().email
        assert true == Access.is_register_accessed?(email)
      end)
    end

    test "returns false when no access pertains to the email" do
      Repo.transaction(fn ->
        assert false == Access.is_register_accessed?(Simulation.email())
      end)
    end
  end

  describe "CommonsPub.Access.hard_delete!/1" do
    test "raises :function_clause when given input of the wrong type" do
      Repo.transaction(fn ->
        assert :function_clause = catch_error(Access.hard_delete(Simulation.ulid()))
      end)
    end

    # test "returns a DeletionError passing a deleted model" do
    #   Repo.transaction(fn ->
    #     wl = fake_register_email_domain_access!()
    #     assert {:ok, deleted(wl)} == Access.hard_delete(wl)
    #     assert {:error, e} = Access.hard_delete(wl)
    #     assert was_already_deleted?(e)
    #   end)
    # end

    test "can successfully delete a RegisterEmailDomainAccess" do
      Repo.transaction(fn ->
        wl = fake_register_email_domain_access!()
        assert deleted(wl) == Access.hard_delete!(wl)
        assert {:error, %NotFoundError{} = e} = Access.find_register_email_domain(wl.domain)
      end)
    end

    test "can successfully delete a RegisterEmailAccess" do
      Repo.transaction(fn ->
        wl = fake_register_email_access!()
        assert deleted(wl) == Access.hard_delete!(wl)
        assert {:error, %NotFoundError{} = e} = Access.find_register_email(wl.email)
      end)
    end

    test "throws a DeletionError passing a deleted model" do
      Repo.transaction(fn ->
        wl = fake_register_email_domain_access!()
        assert {:ok, deleted(wl)} == Access.hard_delete(wl)
        assert e = catch_throw(Access.hard_delete!(wl))
      end)
    end

    test "ok for a valid token" do
      user = fake_user!(%{}, confirm_email: true)
      token = fake_token!(user)
      assert :ok == Access.verify_token(token)
    end

    test "errors for an expired token" do
      user = fake_user!(%{}, confirm_email: true)
      token = fake_token!(user)
      then = DateTime.add(token.created_at, 3600 * 24 * 15, :second)
      assert {:error, %TokenExpiredError{}} = Access.verify_token(token, then)
    end
  end

  describe "CommonsPub.Access.fetch_token_and_user/1" do
    test "works" do
      user = fake_user!(%{}, confirm_email: true)
      token = fake_token!(user)
      assert token.user_id == user.id
      assert {:ok, token2} = Access.fetch_token_and_user(token.id)
      assert strip(token) == strip(token2)
      assert strip(user) == strip(token2.user)
    end

    test "fails with an invalid token" do
      user = fake_user!(%{}, confirm_email: true)
      token = fake_token!(user)
      assert token.user_id == user.id
      assert {:error, error} = Access.fetch_token_and_user(token.id <> token.id)
      assert %TokenNotFoundError{} = error
    end
  end

  describe "CommonsPub.Access.hard_delete/1" do
    test "works with a Token" do
      user = fake_user!(%{}, confirm_email: true)
      token = fake_token!(user)
      {:ok, token2} = Access.hard_delete(token)
      assert deleted(token) == token2
      assert {:error, %NotFoundError{}} = Access.fetch_token_and_user(token.id)
    end

    # test "works with an Authorization" do
    #   user = fake_user!(%{}, confirm_email: true)
    #   assert {:ok, auth} = OAuth.create_auth(user)
    #   assert {:ok, auth2} = OAuth.hard_delete(auth)
    #   assert {:error, %NotFoundError{key: auth.id}} == OAuth.fetch_auth(auth.id)
    # end
  end

  describe "CommonsPub.OAuth.verify_user" do
    test "ok for a valid user" do
      user = fake_user!(%{}, confirm_email: true)
      assert :ok == Access.verify_user(user)
    end

    test "errors for a user without a confirmed email" do
      user = fake_user!(%{}, confirm_email: false)
      assert {:error, %UserEmailNotConfirmedError{}} = Access.verify_user(user)
    end
  end
end
