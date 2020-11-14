# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Access do
  @moduledoc """
  The access system in general is related to authentication:
  * Creation and querying of session tokens
  * In closed-signup mode, maintains permitlists of emails and domains
  """

  alias Ecto.{Changeset, UUID}
  alias CommonsPub.{Common, Repo}
  alias CommonsPub.Common.NotFoundError

  alias CommonsPub.Access.{
    InvalidCredentialError,
    NoAccessError,
    RegisterEmailAccess,
    RegisterEmailDomainAccess,
    Token,
    TokenExpiredError,
    TokenNotFoundError,
    UserDisabledError,
    UserEmailNotConfirmedError
  }

  alias CommonsPub.Users.{LocalUser, User}
  import Ecto.Query

  @type access :: RegisterEmailDomainAccess.t() | RegisterEmailAccess.t()
  @type token :: Token.t()

  @spec create_register_email_domain(domain :: binary) ::
          {:ok, RegisterEmailDomainAccess.t()} | {:error, Changeset.t()}
  @doc "Permit registration with all emails at the provided domain"
  def create_register_email_domain(domain) do
    Repo.insert(RegisterEmailDomainAccess.create_changeset(%{domain: domain}))
  end

  @spec create_register_email(email :: binary) ::
          {:ok, RegisterEmailAccess.t()} | {:error, Changeset.t()}
  @doc "Permit registration with the provided email"
  def create_register_email(email) do
    Repo.insert(RegisterEmailAccess.create_changeset(%{email: email}))
  end

  @spec list_register_emails() :: [RegisterEmailAccess.t()]
  @doc "Retrieve all RegisterEmailAccess in the database"
  def list_register_emails(), do: Repo.all(RegisterEmailAccess)

  @spec list_register_email_domains() :: [RegisterEmailDomainAccess.t()]
  @doc "Retrieve all RegisterEmailDomainAccess in the database"
  def list_register_email_domains(), do: Repo.all(RegisterEmailDomainAccess)

  @spec hard_delete(access | token) :: {:ok, access} | {:error, Changeset.t()}
  @doc "Removes an access entry or token from the database"
  def hard_delete(%RegisterEmailDomainAccess{} = w), do: Common.Deletion.hard_delete(w)
  def hard_delete(%RegisterEmailAccess{} = w), do: Common.Deletion.hard_delete(w)
  def hard_delete(%Token{} = token), do: Common.Deletion.hard_delete(token)

  @spec hard_delete!(access | token) :: access
  @doc "Removes an access entry or token from the database or throws DeletionError"
  def hard_delete!(%RegisterEmailDomainAccess{} = w), do: Common.Deletion.hard_delete!(w)
  def hard_delete!(%RegisterEmailAccess{} = w), do: Common.Deletion.hard_delete!(w)
  def hard_delete!(%Token{} = token), do: Common.Deletion.hard_delete(token)

  @spec find_register_email(email :: binary()) ::
          {:ok, RegisterEmailAccess.t()} | {:error, NotFoundError.t()}
  @doc "Looks up a RegisterEmailAccess by email"
  def find_register_email(email),
    do: find_response(Repo.get_by(RegisterEmailAccess, email: email))

  @spec find_or_add_register_email(email :: binary()) ::
          {:ok, RegisterEmailAccess.t()} | {:error, Changeset.t()}
  @doc "Looks up a RegisterEmailAccess by email and creates it if it doesn't exist"
  def find_or_add_register_email(email) do
    case find_register_email(email) do
      {:ok, email} ->
        {:ok, email}

      {:error, _} ->
        create_register_email(email)
    end
  end

  @spec find_register_email_domain(domain :: binary()) ::
          {:ok, RegisterEmailDomainAccess.t()} | {:error, NotFoundError.t()}
  @doc "Looks up a RegisterEmailDomainAccess by domain"
  def find_register_email_domain(domain),
    do: find_response(Repo.get_by(RegisterEmailDomainAccess, domain: domain))

  defp find_response(nil), do: {:error, NotFoundError.new()}
  defp find_response(val), do: {:ok, val}

  @spec is_register_accessed?(email :: binary()) :: boolean()
  @doc "true if the user's email or the domain of the user's email is accessed"
  def is_register_accessed?(email) do
    with {:error, _} <- find_register_email(email),
         {:error, _} <- find_register_email_domain(email_domain(email)) do
      false
    else
      {:ok, _} -> true
    end
  end

  @doc ":ok if the user's email is accessed, else error tuple"
  def check_register_access(email) do
    if is_register_accessed?(email),
      do: :ok,
      else: {:error, NoAccessError.new()}
  end

  def fetch_token(id) when is_binary(id), do: Repo.fetch(Token, id)

  def delete_tokens_for_user(%User{id: user_id}) do
    from(t in Token, where: is_nil(t.deleted_at), where: t.user_id == ^user_id)
    |> Repo.delete_all()
  end

  @doc """
  Fetches a token along with the user it is linked to.

  Note: does not validate the validity of the token, you must do that afterwards.
  """
  @spec fetch_token_and_user(token :: binary) ::
          {:ok, %Token{}} | {:error, TokenNotFoundError.t()}
  def fetch_token_and_user(token) when is_binary(token) do
    # IO.inspect(fetch_token_and_user: token)

    case UUID.cast(token) do
      {:ok, token} -> Repo.single(fetch_token_and_user_query(token))
      :error -> {:error, TokenNotFoundError.new()}
    end
  end

  def fetch_token_and_user(token) do
    IO.inspect(fetch_token_and_user_not_binary: token)
    {:error, TokenNotFoundError.new()}
  end

  def fetch_token_and_user_query(token) do
    import Ecto.Query, only: [from: 2]

    from(t in Token,
      where: t.id == ^token,
      join: u in assoc(t, :user),
      join: lu in assoc(u, :local_user),
      join: chr in assoc(u, :character),
      preload: [user: {u, local_user: lu, character: chr}]
    )
  end

  @type token_create_error ::
          %InvalidCredentialError{}
          | %UserDisabledError{}
          | %UserEmailNotConfirmedError{}
          | Changeset.t({})
  @doc """
  Creates a token for a user if the conditions are met:
  * The password is correct
  * The user is not disabled
  * The user has confirmed their email address

  In all of these cases, a password check will be performed.
  """
  @spec create_token(User.t(), binary) :: {:ok, Token.t()} | {:error, token_create_error}

  def create_token(%User{local_user: %LocalUser{}} = user, password) do
    if Argon2.verify_pass(password, user.local_user.password_hash) do
      with :ok <- verify_user(user) do
        Repo.insert(Token.create_changeset(user))
      end
    else
      {:error, InvalidCredentialError.new()}
    end
  end

  # not really unsafe but don't use me outside of tests
  @doc false
  def unsafe_put_token(%User{} = user), do: Repo.insert(Token.create_changeset(user))

  @doc false
  def verify_user(%User{disabled_at: dis})
      when not is_nil(dis),
      do: {:error, UserDisabledError.new()}

  def verify_user(%User{local_user: %LocalUser{confirmed_at: confirmed}})
      when is_nil(confirmed),
      do: {:error, UserEmailNotConfirmedError.new()}

  def verify_user(%User{local_user: %LocalUser{}}), do: :ok

  @doc "Ensures that a token is valid (not expired)"
  def verify_token(token, now \\ DateTime.utc_now())

  def verify_token(%Token{} = token, %DateTime{} = now) do
    if :gt == DateTime.compare(token.expires_at, now),
      do: :ok,
      else: {:error, TokenExpiredError.new()}
  end

  defp email_domain(email) do
    [_, domain] = String.split(email, "@", parts: 2)
    domain
  end
end
