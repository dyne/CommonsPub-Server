# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.LikesTest do
  use CommonsPub.DataCase, async: true
  use Oban.Testing, repo: CommonsPub.Repo
  require Ecto.Query
  import CommonsPub.Utils.Simulation
  alias CommonsPub.Likes
  alias CommonsPub.Common.{DeletionError, NotFoundError}
  alias CommonsPub.Utils.Simulation

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
    Faker.Util.pick([user, community, collection, resource, comment])
  end

  def gen_likes(n, liker \\ fake_user!(), attrs \\ %{}) do
    for _ <- 1..n do
      liked = fake_meta!()
      assert {:ok, like} = Likes.create(liker, liked, Simulation.like(attrs))
      like
    end
  end

  def strip(like), do: Map.drop(like, [:is_public])

  def like_equal?(like, attrs) do
    strip(like) == strip(attrs)
  end

  describe "one" do
    test "by ID", %{user: liker} do
      liked = fake_meta!()
      assert {:ok, like} = Likes.create(liker, liked, Simulation.like())
      assert {:ok, fetched} = Likes.one(id: like.id)
      assert like_equal?(like, fetched)
    end

    test "by context ID", %{user: liker} do
      liked = fake_meta!()
      assert {:ok, like} = Likes.create(liker, liked, Simulation.like())
      assert {:ok, fetched} = Likes.one(context: liked.id)
      assert like_equal?(like, fetched)
    end

    test "by user", %{user: liker} do
      liked = fake_meta!()
      assert {:ok, like} = Likes.create(liker, liked, Simulation.like())
      assert {:ok, fetched} = Likes.one(user: liker)
      assert like_equal?(like, fetched)
    end

    test "private", %{user: liker} do
      liked = fake_meta!()
      assert {:ok, like} = Likes.create(liker, liked, Simulation.like(%{is_public: false}))
      assert {:ok, fetched} = Likes.one(published: true, id: like.id)
      assert like_equal?(like, fetched)
    end

    test "deleted", %{user: liker} do
      liked = fake_meta!()
      assert {:ok, like} = Likes.create(liker, liked, Simulation.like())
      assert {:ok, like} = Likes.soft_delete(liker, like)
      assert {:ok, fetched} = Likes.one(id: like.id)
      assert {:error, %NotFoundError{}} = Likes.one(deleted: false, id: like.id)
      assert like_equal?(like, fetched)
    end
  end

  describe "many" do
    test "list of all likes", %{user: liker} do
      likes = gen_likes(3, liker)
      assert {:ok, fetched} = Likes.many()
      assert Enum.map(fetched, &strip/1) == Enum.map(likes, &strip/1)
    end

    test "likes by user", %{user: liker} do
      liked = fake_meta!()
      {:ok, like} = Likes.create(liker, liked, Simulation.like())

      gen_likes(3)

      assert {:ok, [fetched]} = Likes.many(creator: liker.id)
      assert like_equal?(like, fetched)
    end

    test "likes by context", %{user: liker} do
      liked = fake_meta!()
      {:ok, like} = Likes.create(liker, liked, Simulation.like())

      gen_likes(3)

      assert {:ok, [fetched]} = Likes.many(context: liked.id)
      assert like_equal?(like, fetched)
    end

    test "filter deleted", %{user: liker} do
      liked = fake_meta!()
      {:ok, like} = Likes.create(liker, liked, Simulation.like())
      {:ok, _} = Likes.soft_delete(liker, like)

      likes = gen_likes(3)
      assert {:ok, fetched} = Likes.many(deleted: false)
      assert Enum.map(likes, &strip/1) == Enum.map(fetched, &strip/1)
    end

    # TODO: likes are always public
    # test "filter private", %{user: liker} do
    #   liked = fake_meta!()
    #   {:ok, like} = Likes.create(liker, liked, Simulation.like(%{is_public: false}))

    #   likes = gen_likes(3)

    #   assert {:ok, fetched} = Likes.many([:private])
    #   assert Enum.map(likes, &strip/1) == Enum.map(fetched, &strip/1)
    #   refute Enum.any?(likes, fn fetched -> like_equal?(like, fetched) end)
    # end
  end

  describe "create" do
    test "a user can like any meta object", %{user: liker} do
      liked = fake_meta!()
      assert {:ok, like} = Likes.create(liker, liked, Simulation.like())
      assert like.creator_id == liker.id
      assert like.context_id == liked.id
      assert like.published_at
    end
  end

  describe "update" do
    test "changes a like", %{user: liker} do
      liked = fake_meta!()
      assert {:ok, like} = Likes.create(liker, liked, Simulation.like())
      assert {:ok, updated} = Likes.update(liker, like, Simulation.like())
      refute like_equal?(like, updated)
    end
  end

  describe "soft_delete" do
    test "soft deletes a like", %{user: liker} do
      liked = fake_meta!()
      assert {:ok, like} = Likes.create(liker, liked, Simulation.like())
      refute like.deleted_at
      assert {:ok, undoed} = Likes.soft_delete(liker, like)
      assert undoed.deleted_at
    end

    test "fails if already deleted", %{user: liker} do
      liked = fake_meta!()
      assert {:ok, like} = Likes.create(liker, liked, Simulation.like())
      assert {:ok, deleted} = Likes.soft_delete(liker, like)
      assert {:error, %DeletionError{}} = Likes.soft_delete(liker, deleted)
    end
  end
end
