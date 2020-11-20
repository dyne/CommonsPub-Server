# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.CommonTest do
  use CommonsPub.DataCase, async: true
  use Oban.Testing, repo: CommonsPub.Repo
  require Ecto.Query
  import CommonsPub.Utils.Simulation

  setup do
    {:ok, %{user: fake_user!()}}
  end

  def fake_meta!() do
    user = fake_user!()
    community = fake_community!(user)
    collection = fake_collection!(user, community)
    resource = fake_resource!(user, collection)
    thread = fake_thread!(user, resource)
    comment = fake_comment!(user, thread)
    Faker.Util.pick([user, community, collection, resource, thread, comment])
  end

  # describe "paginate" do
  #   test "can take a limit and an offset", %{user: user} do
  #     users = [user] ++ for _ <- 1..4, do: fake_user!()

  #     users =
  #       Enum.sort_by(users, & &1.inserted_at, fn a, b -> :lt == DateTime.compare(a, b) end)

  #     query = Ecto.Query.from(_ in User)

  #     [first, second] =
  #       query
  #       |> Common.paginate(%{offset: 2, limit: 2})
  #       |> Repo.all()

  #     assert first.id == Enum.at(users, 2).id
  #     assert second.id == Enum.at(users, 3).id

  #     # no limit
  #     fetched =
  #       query
  #       |> Common.paginate(%{offset: 2})
  #       |> Repo.all()

  #     assert Enum.map(fetched, & &1.id) == users |> Enum.drop(2) |> Enum.map(& &1.id)

  #     # no offset
  #     fetched =
  #       query
  #       |> Common.paginate(%{limit: 2})
  #       |> Repo.all()

  #     assert Enum.map(fetched, & &1.id) == users |> Enum.take(2) |> Enum.map(& &1.id)

  #     # neither parameters
  #     fetched =
  #       query
  #       |> Common.paginate(%{})
  #       |> Repo.all()

  #     assert Enum.map(fetched, & &1.id) == users |> Enum.map(& &1.id)
  #   end
  # end

  # describe "tag/3" do
  #   test "creates a tag for any meta object", %{user: tagger} do
  #     tagged = fake_meta!()

  #     assert {:ok, tag} =
  #              Common.tag(tagger, tagged, Simulation.tag(%{is_public: true, name: "Testing"}))

  #     assert tag.published_at
  #     assert tag.name == "Testing"
  #   end

  #   test "fails to create a tag if attributes are missing", %{user: tagger} do
  #     tagged = fake_meta!()
  #     assert {:error, changeset} = Common.tag(tagger, tagged, %{})
  #     assert Keyword.get(changeset.errors, :name)
  #   end
  # end

  # describe "update_tag/2" do
  #   test "updates the attributes of an existing tag", %{user: tagger} do
  #     tagged = fake_meta!()
  #     assert {:ok, tag} = Common.tag(tagger, tagged, Simulation.tag(%{name: "Testy No.1"}))
  #     assert {:ok, updated_tag} = Common.update_tag(tag, %{name: "Testy Mc.Testface"})
  #     assert tag != updated_tag
  #   end

  #   test "fails to update if attributes are missing", %{user: tagger} do
  #     tagged = fake_meta!()
  #     assert {:error, changeset} = Common.tag(tagger, tagged, %{})
  #     assert Keyword.get(changeset.errors, :name)
  #   end
  # end

  # describe "untag/1" do
  #   test "removes a tag", %{user: tagger} do
  #     tagged = fake_meta!()
  #     assert {:ok, tag} = Common.tag(tagger, tagged, Simulation.tag())
  #     refute tag.deleted_at
  #     assert {:ok, tag} = Common.untag(tag)
  #     assert tag.deleted_at
  #   end
  # end
end
