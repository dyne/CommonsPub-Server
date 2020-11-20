# SPDX-License-Identifier: AGPL-3.0-only
defmodule Organisation.OrganisationsTest do
  use CommonsPub.Web.ConnCase, async: true
  import CommonsPub.Utils.Simulation

  import Organisation.Simulate
  import Organisation.Test.Faking
  alias Organisation.Organisations

  describe "one" do
    test "fetches an existing organisation" do
      user = fake_user!()
      org = fake_organisation!(user)

      assert {:ok, fetched} = Organisations.one(id: org.id)
      assert_organisation(fetched)
    end
  end

  describe "create" do
    test "a user can create an org" do
      user = fake_user!()
      assert {:ok, org} = Organisations.create(user, organisation())
      assert_organisation(org)
      assert org.creator_id == user.id
    end

    test "a user can create an org for a context" do
      user = fake_user!()
      comm = fake_community!(user)
      assert {:ok, org} = Organisations.create(user, comm, organisation())
      assert_organisation(org)
      assert org.context_id == comm.id
    end

    test "fails with invalid parameters" do
      user = fake_user!()
      assert {:error, %Ecto.Changeset{}} = Organisations.create(user, %{})
    end
  end

  describe "update" do
    test "updates an existing org with new content" do
      user = fake_user!()
      org = fake_organisation!(user)
      assert {:ok, updated} = Organisations.update(user, org, organisation())
      assert_organisation(updated)
      assert org != updated
    end
  end

  # describe "soft_delete" do
  #   test "marks an exisitng org as deleted" do
  #     org = fake_user!() |> fake_organisation!()
  #     assert {:ok, org} = Organisations.soft_delete(org)
  #     assert_organisation(org)
  #     assert org.deleted_at
  #   end
  # end
end
