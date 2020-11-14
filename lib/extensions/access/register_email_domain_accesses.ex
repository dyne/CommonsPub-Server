# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Access.RegisterEmailDomainAccesses do
  alias CommonsPub.{Common, Repo}
  alias CommonsPub.Access.{RegisterEmailDomainAccess, RegisterEmailDomainAccessesQueries}

  def one(filters) do
    RegisterEmailDomainAccessesQueries.query(RegisterEmailDomainAccess, filters)
    |> Repo.single()
  end

  def many(filters \\ []) do
    query = RegisterEmailDomainAccessesQueries.query(RegisterEmailDomainAccess, filters)
    {:ok, Repo.all(query)}
  end

  def create(domain) do
    changeset = RegisterEmailDomainAccess.create_changeset(%{domain: domain})

    with {:error, _changeset} <- Repo.insert(changeset),
         do: {:error, "Domain already allowlisted"}
  end

  def soft_delete(%RegisterEmailDomainAccess{} = it), do: Common.Deletion.soft_delete(it)
end
