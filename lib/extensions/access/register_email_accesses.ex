# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Access.RegisterEmailAccesses do
  alias CommonsPub.{Common, Repo}
  alias CommonsPub.Access.{RegisterEmailAccess, RegisterEmailAccessesQueries}

  def one(filters) do
    Repo.single(RegisterEmailAccessesQueries.query(RegisterEmailAccess, filters))
  end

  def many(filters \\ []) do
    {:ok, Repo.all(RegisterEmailAccessesQueries.query(RegisterEmailAccess, filters))}
  end

  def create(email) do
    changeset = RegisterEmailAccess.create_changeset(%{email: email})

    with {:error, _changeset} <- Repo.insert(changeset),
         do: {:error, "Email already allowlisted"}
  end

  def soft_delete(%RegisterEmailAccess{} = it), do: Common.Deletion.soft_delete(it)
end
