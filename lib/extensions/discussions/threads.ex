# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Threads do
  alias CommonsPub.{Common, Feeds, Follows, Repo}
  # alias CommonsPub.FeedPublisher
  alias CommonsPub.Threads.{Comments, Thread, Queries}
  alias CommonsPub.Users.User

  def cursor(:created), do: &[&1.id]

  # FIXME
  # def cursor(:last_comment), do: &[&1.id]

  def cursor(:followers), do: &[&1.follower_count, &1.id]

  def test_cursor(:created), do: &[&1["id"]]
  def test_cursor(:followers), do: &[&1["followerCount"], &1["id"]]

  def one(filters), do: Repo.single(Queries.query(Thread, filters))

  def many(filters \\ []), do: {:ok, Repo.all(Queries.query(Thread, filters))}

  @doc "Create a thread with a first comment. You usually want this rather than creating a thread on its own."
  def create_with_comment(creator, attrs, context \\ nil)

  def create_with_comment(creator, attrs, nil) do
    Repo.transact_with(fn ->
      with {:ok, thread} <- create(creator, attrs) do
        Comments.create(creator, thread, attrs)
      end
    end)
  end

  def create_with_comment(creator, attrs, context) do
    Repo.transact_with(fn ->
      with {:ok, thread} <- create(creator, context, attrs) do
        Comments.create(creator, thread, attrs)
      end
    end)
  end

  @spec create(User.t(), map, context :: any) :: {:ok, Thread.t()} | {:error, Changeset.t()}
  def create(creator, attrs, context \\ nil)

  def create(%User{} = creator, attrs, context) when not is_nil(context) do
    Repo.transact_with(fn ->
      with {:ok, feed} <- Feeds.create(),
           attrs = Map.put(attrs, :outbox_id, feed.id),
           {:ok, thread} <- insert(creator, attrs, context) do
        {:ok, thread}
      end
    end)
  end

  @spec create(User.t(), map) :: {:ok, Thread.t()} | {:error, Changeset.t()}
  def create(%User{} = creator, attrs, _) do
    Repo.transact_with(fn ->
      with {:ok, feed} <- Feeds.create(),
           attrs = Map.put(attrs, :outbox_id, feed.id),
           {:ok, thread} <- insert(creator, attrs) do
        {:ok, thread}
      end
    end)
  end

  defp insert(creator, attrs, context) do
    Repo.insert(Thread.create_changeset(creator, attrs, context))
  end

  defp insert(creator, attrs) do
    Repo.insert(Thread.create_changeset(creator, attrs))
  end

  @doc """
  Update the attributes of a thread.
  """
  @spec update(User.t(), Thread.t(), map) :: {:ok, Thread.t()} | {:error, Changeset.t()}
  def update(%User{}, %Thread{} = thread, attrs) do
    Repo.transact_with(fn ->
      with {:ok, thread} <- Repo.update(Thread.update_changeset(thread, attrs)) do
        {:ok, thread}
      end
    end)
  end

  def update_by(%User{}, filters, updates) do
    Repo.update_all(Queries.query(Thread, filters), set: updates)
  end

  @spec soft_delete(User.t(), Thread.t()) :: {:ok, Thread.t()} | {:error, Changeset.t()}
  def soft_delete(%User{} = user, %Thread{} = thread) do
    Repo.transact_with(fn ->
      with {:ok, thread} <- Common.Deletion.soft_delete(thread),
           :ok <- chase_delete(user, thread.id) do
        {:ok, thread}
      end
    end)
  end

  def soft_delete_by(%User{} = user, filters) do
    with {:ok, _} <-
           Repo.transact_with(fn ->
             {_, ids} =
               update_by(user, [{:select, :id} | filters], deleted_at: DateTime.utc_now())

             chase_delete(user, ids)
           end),
         do: :ok
  end

  defp chase_delete(user, ids) do
    with :ok <- Comments.soft_delete_by(user, thread: ids) do
      Follows.soft_delete_by(user, context: ids)
    end
  end
end
