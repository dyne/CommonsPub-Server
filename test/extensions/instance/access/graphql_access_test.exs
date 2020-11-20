# SPDX-License-Identifier: AGPL-3.0-only

defmodule CommonsPub.Web.GraphQL.AccessTest do
  use CommonsPub.Web.ConnCase, async: true

  import CommonsPub.Utils.Simulation
  import CommonsPub.Web.Test.GraphQLFields
  import Grumble
  alias CommonsPub.Utils.Simulation
  alias CommonsPub.Access

  def email_access_fields(extra \\ []) do
    [:email, :created_at] ++ extra
  end

  def register_emails_query(options \\ []) do
    gen_query(:register_emails, &register_emails_subquery/1, options)
  end

  def register_emails_subquery(options \\ []) do
    gen_subquery(:register_emails, &email_access_fields/1, options)
  end

  def register_emails_page_query(options \\ []) do
    gen_query(:limit, &register_emails_page_subquery/1, [{:param_type, :int} | options])
  end

  def register_emails_page_subquery(options \\ []) do
    :limit
    |> page_subquery(:register_email_accesses, &email_access_fields/1, options)
  end

  def register_email_mutation(options \\ []) do
    [email: type!(:string)]
    |> gen_mutation(&register_email_submutation/1, options)
  end

  def register_email_submutation(options \\ []) do
    [email: var(:email)]
    |> gen_submutation(:create_register_email_access, &email_access_fields/1, options)
  end

  def delete_email_mutation(options \\ []) do
    [id: type!(:string)]
    |> gen_mutation(&delete_email_submutation/1, options)
  end

  def delete_email_submutation(options \\ []) do
    [id: var(:id)]
    |> gen_submutation(:delete_register_email_access, &email_access_fields/1, options)
  end

  def domain_access_fields(extra \\ []) do
    [:domain, :created_at] ++ extra
  end

  def register_domain_page_query(options \\ []) do
    gen_query(:limit, &register_domain_page_subquery/1, [{:param_type, :int} | options])
  end

  def register_domain_page_subquery(options \\ []) do
    :limit
    |> page_subquery(:register_email_domain_accesses, &domain_access_fields/1, options)
  end

  def register_domain_mutation(options \\ []) do
    [domain: type!(:string)]
    |> gen_mutation(&register_domain_submutation/1, options)
  end

  def register_domain_submutation(options \\ []) do
    [domain: var(:domain)]
    |> gen_submutation(:create_register_email_domain_access, &domain_access_fields/1, options)
  end

  def delete_domain_mutation(options \\ []) do
    [id: type!(:string)]
    |> gen_mutation(&delete_domain_submutation/1, options)
  end

  def delete_domain_submutation(options \\ []) do
    [id: var(:id)]
    |> gen_submutation(:delete_register_email_domain_access, &domain_access_fields/1, options)
  end

  describe "register_email" do
    test "allows access by email" do
      user = fake_user!(%{is_instance_admin: true})
      conn = user_conn(user)

      q = register_email_mutation()
      vars = %{email: Simulation.email()}
      assert email_access = grumble_post_key(q, conn, :create_register_email_access, vars)
      assert email_access["email"] == vars[:email]
      assert email_access["createdAt"]
    end

    test "fails if access already exists" do
      user = fake_user!(%{is_instance_admin: true})
      conn = user_conn(user)

      assert {:ok, email_access} = Access.create_register_email(Simulation.email())

      q = register_email_mutation()

      assert [
               %{
                 "locations" => [%{"column" => 3, "line" => 2}],
                 "message" => "Email already allowlisted",
                 "path" => ["createRegisterEmailAccess"]
               }
             ] = grumble_post_errors(q, conn, %{email: email_access.email})
    end

    test "fails if user is not an admin" do
      user = fake_user!()
      conn = user_conn(user)

      q = register_email_mutation()

      assert [
               %{
                 "code" => "unauthorized",
                 "locations" => [%{"column" => 3, "line" => 2}],
                 "message" => "You do not have permission to do this.",
                 "path" => ["createRegisterEmailAccess"],
                 "status" => 403
               }
             ] = grumble_post_errors(q, conn, %{email: Simulation.email()})
    end

    test "deletes an email" do
      user = fake_admin!()
      conn = user_conn(user)

      assert {:ok, email_access} = Access.create_register_email(Simulation.email())

      q = delete_email_mutation()

      assert deleted_access =
               grumble_post_key(q, conn, :delete_register_email_access, %{id: email_access.id})

      assert email_access.email == deleted_access["email"]
      assert {:error, _} = Access.find_register_email(email_access.email)
    end

    test "errors when deleter is not an admin" do
      user = fake_user!()
      conn = user_conn(user)

      assert {:ok, email_access} = Access.create_register_email(Simulation.email())

      q = delete_email_mutation()

      assert [
               %{
                 "code" => "unauthorized",
                 "locations" => [%{"column" => 3, "line" => 2}],
                 "message" => "You do not have permission to do this.",
                 "path" => ["deleteRegisterEmailAccess"],
                 "status" => 403
               }
             ] = grumble_post_errors(q, conn, %{id: email_access.id})
    end

    test "retrieves page of emails" do
      user = fake_admin!()
      conn = user_conn(user)

      for email <- [Simulation.email(), Simulation.email(), Simulation.email()] do
        Access.create_register_email(email)
      end

      q = register_emails_page_query()
      assert page = grumble_post_key(q, conn, :register_email_accesses, %{limit: 10})
      assert page["totalCount"] == 3
    end

    test "returns an empty page if user is not admin" do
      user = fake_user!()
      conn = user_conn(user)

      for email <- [Simulation.email(), Simulation.email(), Simulation.email()] do
        Access.create_register_email(email)
      end

      q = register_emails_page_query()
      assert page = grumble_post_key(q, conn, :register_email_accesses, %{limit: 10})
      assert page["totalCount"] == 0
    end
  end

  describe "register_domain" do
    test "allows access by domain" do
      user = fake_user!(%{is_instance_admin: true})
      conn = user_conn(user)

      q = register_domain_mutation()
      vars = %{domain: Simulation.domain()}
      assert domain_access = grumble_post_key(q, conn, :create_register_email_domain_access, vars)
      assert domain_access["domain"] == vars[:domain]
      assert domain_access["createdAt"]
    end

    test "fails if domain already exists" do
      user = fake_user!(%{is_instance_admin: true})
      conn = user_conn(user)

      assert {:ok, domain_access} = Access.create_register_email_domain(Simulation.domain())

      q = register_domain_mutation()

      assert [
               %{
                 "locations" => [%{"column" => 3, "line" => 2}],
                 "message" => "Domain already allowlisted",
                 "path" => ["createRegisterEmailDomainAccess"]
               }
             ] = grumble_post_errors(q, conn, %{domain: domain_access.domain})
    end

    test "fails if user is not an admin" do
      user = fake_user!()
      conn = user_conn(user)

      q = register_domain_mutation()

      assert [
               %{
                 "code" => "unauthorized",
                 "locations" => [%{"column" => 3, "line" => 2}],
                 "message" => "You do not have permission to do this.",
                 "path" => ["createRegisterEmailDomainAccess"],
                 "status" => 403
               }
             ] = grumble_post_errors(q, conn, %{domain: Simulation.domain()})
    end

    test "deletes a domain" do
      user = fake_admin!()
      conn = user_conn(user)

      assert {:ok, domain_access} = Access.create_register_email_domain(Simulation.domain())

      q = delete_domain_mutation()

      assert deleted_access =
               grumble_post_key(q, conn, :delete_register_email_domain_access, %{
                 id: domain_access.id
               })

      assert domain_access.domain == deleted_access["domain"]
      assert {:error, _} = Access.find_register_email_domain(domain_access.domain)
    end

    test "errors when deleter is not an admin" do
      user = fake_user!()
      conn = user_conn(user)

      assert {:ok, domain_access} = Access.create_register_email_domain(Simulation.domain())

      q = delete_domain_mutation()

      assert [
               %{
                 "code" => "unauthorized",
                 "locations" => [%{"column" => 3, "line" => 2}],
                 "message" => "You do not have permission to do this.",
                 "path" => ["deleteRegisterEmailDomainAccess"],
                 "status" => 403
               }
             ] = grumble_post_errors(q, conn, %{id: domain_access.id})
    end

    test "retrieves page of domains" do
      user = fake_admin!()
      conn = user_conn(user)

      for domain <- [Simulation.domain(), Simulation.domain(), Simulation.domain()] do
        Access.create_register_email_domain(domain)
      end

      q = register_domain_page_query()
      assert page = grumble_post_key(q, conn, :register_email_domain_accesses, %{limit: 10})
      assert page["totalCount"] == 3
    end

    test "returns an empty page if user is not an admin" do
      user = fake_user!()
      conn = user_conn(user)

      for domain <- [Simulation.domain(), Simulation.domain(), Simulation.domain()] do
        Access.create_register_email_domain(domain)
      end

      q = register_domain_page_query()
      assert page = grumble_post_key(q, conn, :register_email_domain_accesses, %{limit: 10})
      assert page["totalCount"] == 0
    end
  end
end
