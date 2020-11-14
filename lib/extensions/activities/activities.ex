# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Activities do
  alias CommonsPub.{
    # Activities,
    Common,
    Repo
  }

  alias CommonsPub.Activities.{Activity, Queries}
  alias CommonsPub.Users.User

  def one(filters \\ []), do: Repo.single(Queries.query(Activity, filters))

  def many(filters \\ []), do: {:ok, Repo.all(Queries.query(Activity, filters))}

  @doc """
  Create a new activity related to any context that participates in the meta
  abstraction.
  """
  @spec create(User.t(), %{context_id: binary}, map) ::
          {:ok, Activity.t()} | {:error, Changeset.t()}

  def create(nil, _, _) do
    # fail silently (activity must have a character)
    {:ok, nil}
  end

  def create(creator, context, %{} = attrs) do
    with {:ok, activity} <- insert(creator, context, attrs) do
      {:ok, %Activity{activity | context: context, creator: creator}}
    end
  end

  defp insert(creator, context, attrs) do
    Repo.insert(Activity.create_changeset(creator, context, attrs))
  end

  @doc """
  Update an already existing activity with the given attributes.
  """
  @spec update(User.t(), Activity.t(), map) :: {:ok, Activity.t()} | {:error, Changeset.t()}
  def update(%User{}, %Activity{} = activity, %{} = attrs),
    do: Repo.update(Activity.update_changeset(activity, attrs))

  def update_by(%User{} = _user, filters, updates) do
    Repo.update_all(Queries.query(Activity, filters), set: updates)
  end

  @spec soft_delete(User.t(), Activity.t()) :: {:ok, Activity.t()} | {:error, Changeset.t()}
  def soft_delete(%User{}, %Activity{} = activity), do: Common.Deletion.soft_delete(activity)

  def soft_delete_by(%User{} = user, filters) do
    update_by(user, [{:deleted, false} | filters], deleted_at: DateTime.utc_now())
    :ok
  end
end
