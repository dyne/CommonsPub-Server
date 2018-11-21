defmodule MoodleNet.Accounts do
  @moduledoc """
  The Accounts context.
  """

  # import Ecto.Query, warn: false
  alias MoodleNet.Repo
  alias Ecto.Multi

  alias MoodleNet.Accounts.{User, PasswordAuth}

  @doc """
  Creates a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs \\ %{}) do
    actor_attrs = attrs
                  |> Map.put("type", "Person")
                  |> Map.delete(:password)
                  |> Map.delete("password")
    {:ok, actor_entity} = ActivityPub.parse(actor_attrs)
    {:ok, actor_entity} = ActivityPub.SQL.persist(actor_entity)

    Multi.new()
    |> Multi.run(:actor, fn _, _ -> {:ok, actor_entity} end)
    |> Multi.run(:user, &(User.changeset(&2.actor[:local_id], attrs) |> &1.insert()))
    |> Multi.run(
      :password_auth,
      &(PasswordAuth.create_changeset(&2.user.id, attrs) |> &1.insert())
    )
    |> Repo.transaction()
  end

  def authenticate_by_email_and_pass(email, given_pass) do
    email
    |> user_and_password_auth_query()
    |> Repo.one()
    |> case do
      nil ->
        Comeonin.Pbkdf2.dummy_checkpw()
        {:error, :not_found}

      {user, password_auth} ->
        if Comeonin.Pbkdf2.checkpw(given_pass, password_auth.password_hash),
          do: {:ok, user},
          else: {:error, :unauthorized}
    end
  end

  defp user_and_password_auth_query(email) do
    import Ecto.Query

    from(u in User,
      where: u.email == ^email,
      inner_join: p in PasswordAuth,
      on: p.user_id == u.id,
      select: {u, p}
    )
  end
end
