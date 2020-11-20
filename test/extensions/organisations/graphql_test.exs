# SPDX-License-Identifier: AGPL-3.0-only
defmodule Organisation.GraphQLTest do
  use CommonsPub.Web.ConnCase, async: true
  import CommonsPub.Web.Test.GraphQLAssertions
  import CommonsPub.Web.Test.GraphQLFields
  import CommonsPub.Utils.Simulation
  import CommonsPub.Utils.Simulation

  import Organisation.Simulate
  import Organisation.Test.Faking

  describe "organisation" do
    test "works for a logged in user" do
      alice = fake_user!()
      org = fake_organisation!(alice)

      vars = %{organisation_id: org.id}
      conn = user_conn(alice)
      q = organisation_query()

      assert_organisation(grumble_post_key(q, conn, :organisation, vars))
    end

    test "can be created with a context" do
    end

    test "does not work for a guest" do
    end
  end

  describe "organisation.icon" do
  end

  describe "organisation.creator" do
  end

  describe "organisation.context" do
  end
end
