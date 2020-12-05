# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Users do
  @moduledoc """
  A Context for dealing with Users.
  """
  require Logger

  alias CommonsPub.{
    Access,
    Activities,
    Blocks,
    Common,
    Communities,
    Collections,
    Features,
    Feeds,
    Flags,
    Follows,
    Likes,
    Repo,
    Resources,
    Threads
  }

  alias CommonsPub.Characters

  alias CommonsPub.Feeds.FeedSubscriptions
  alias CommonsPub.Mail.{Email, MailService}

  alias CommonsPub.Users.{
    EmailConfirmToken,
    LocalUser,
    ResetPasswordToken,
    TokenAlreadyClaimedError,
    TokenExpiredError,
    Queries,
    User
  }

  alias CommonsPub.Workers.APPublishWorker

  alias Ecto.Changeset

  def cursor(:created), do: &[&1.id]

  @deleted_user_id "REA11YVERYDE1ETED1DENT1TY1"
  def deleted_user_id(), do: @deleted_user_id

  def get!(email_or_username) do
    with {:ok, u} <- get(email_or_username) do
      u
    end
  end

  def get(email_or_username) do
    one(preset: :local_user, email_or_username: email_or_username)
  end

  def one(filters), do: Repo.single(Queries.query(User, filters))

  def many(filters \\ []), do: {:ok, Repo.all(Queries.query(User, filters))}

  @spec register(map, Keyword.t()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def register(attrs, opts \\ [])

  @doc """
  Registers a remote user
  """
  def register(%{peer_id: peer_id} = attrs, _opts) when not is_nil(peer_id) do
    Repo.transact_with(fn ->
      with {:ok, user} <- Repo.insert(User.register_changeset(attrs)),
           {:ok, character} <- CommonsPub.Characters.create(user, attrs, user) do
        CommonsPub.Search.Indexer.maybe_index_object(user)

        {:ok, %{user | character: character}}
      end
    end)
  end

  @doc """
  Registers a local user:
  1. Splits attrs into character and user fields
  2. Inserts user (because the access check isn't very good at crap emails yet)
  3. Checks the access
  4. Creates character, emails confirmation token

  This is controlled by options. An optional keyword list
  provided to this argument will be prepended to the application
  config under the path`[:commons_pub, CommonsPub.Users]`. Possible options:

  `:public_registration` - boolean, default false. if false, accesss will be checked
  """
  def register(attrs, opts) do
    # IO.inspect(register: attrs)
    # IO.inspect(register: opts)

    Repo.transact_with(fn ->
      with {:ok, local_user} <- insert_local_user(attrs),
           :ok <- maybe_check_register_access(local_user.email, opts),
           {:ok, user} <- Repo.insert(User.local_register_changeset(local_user, attrs)),
           {:ok, character} <- CommonsPub.Characters.create(user, attrs, user),
           {:ok, token} <- create_email_confirm_token(local_user) do
        user = %{
          user
          | character: character,
            local_user: %{local_user | email_confirm_tokens: [token]}
        }

        Logger.info("Sending confirmation token for user: #{token.id}")

        user
        |> Email.welcome(token)
        |> MailService.maybe_deliver_later()

        CommonsPub.Search.Indexer.maybe_index_object(user)

        {:ok, user}
      end
    end)
  end

  defp maybe_check_register_access(email, opts) do
    if should_check_register_access?(opts),
      do: Access.check_register_access(email),
      else: :ok
  end

  defp should_check_register_access?(opts) do
    opts = opts ++ CommonsPub.Config.get(__MODULE__, [])
    # IO.inspect(should_check_register_access: Keyword.get(opts, :public_registration, false))
    not Keyword.get(opts, :public_registration, false)
  end

  defp insert_local_user(attrs) do
    with {:ok, local_user} <- Repo.insert(LocalUser.register_changeset(attrs)) do
      {:ok, %{local_user | password: nil}}
    end
  end

  defp create_email_confirm_token(%LocalUser{} = local_user),
    do: Repo.insert(EmailConfirmToken.create_changeset(local_user))

  @doc "Uses an email confirmation token, returns ok/error tuple"
  @spec claim_email_confirm_token(token :: any, DateTime.t()) ::
          {:ok, User.t()} | {:error, Changeset.t()}
  def claim_email_confirm_token(token, now \\ DateTime.utc_now())

  def claim_email_confirm_token(token, %DateTime{} = now) when is_binary(token) do
    Repo.transact_with(fn ->
      with {:ok, token} <- Repo.fetch(EmailConfirmToken, token),
           :ok <- validate_token(token, :confirmed_at, now),
           {:ok, _} <- Repo.update(EmailConfirmToken.claim_changeset(token)),
           {:ok, user} <-
             one(
               join: :character,
               join: :local_user,
               preload: :all,
               local_user: token.local_user_id
             ),
           {:ok, user} <- confirm_email(user),
           :ok <- ap_publish("create", user) do
        {:ok, user}
      end
    end)
  end

  # use the email confirmation mechanism
  @doc """
  Verify a user's email address, allowing them to access their account.

  Note: this is for the benefit of the test suite. In normal use you
  should use the email confirmation mechanism.
  """
  @spec confirm_email(User.t()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def confirm_email(%User{} = user) do
    Repo.transact_with(fn ->
      with {:ok, local_user} <- Repo.update(LocalUser.confirm_email_changeset(user.local_user)) do
        user = preload_actor(%{user | local_user: local_user})
        {:ok, user}
      end
    end)
  end

  @spec unconfirm_email(User.t()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def unconfirm_email(%User{} = user) do
    cs = LocalUser.unconfirm_email_changeset(user.local_user)

    Repo.transact_with(fn ->
      with {:ok, local_user} <- Repo.update(cs) do
        user = preload_actor(%{user | local_user: local_user})
        {:ok, user}
      end
    end)
  end

  @spec request_password_reset(User.t()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def request_password_reset(%User{} = user) do
    cs = ResetPasswordToken.create_changeset(user.local_user)

    Repo.transact_with(fn ->
      with {:ok, token} <- Repo.insert(cs) do
        user
        |> Email.reset_password_request(token)
        |> MailService.maybe_deliver_later()

        {:ok, token}
      end
    end)
  end

  @spec claim_password_reset(token :: any, binary(), DateTime.t()) ::
          {:ok, User.t()} | {:error, Changeset.t()}
  def claim_password_reset(token, password, now \\ DateTime.utc_now())

  def claim_password_reset(token, password, %DateTime{} = now)
      when is_binary(password) do
    Repo.transact_with(fn ->
      with {:ok, token} <- Repo.fetch(ResetPasswordToken, token),
           :ok <- validate_token(token, :reset_at, now),
           {:ok, local_user} <- Repo.fetch(LocalUser, token.local_user_id),
           {:ok, user} <- one(preset: :local_user, local_user: token.local_user_id),
           {:ok, _token} <- Repo.update(ResetPasswordToken.claim_changeset(token)),
           {:ok, _} <- Repo.update(LocalUser.update_changeset(local_user, %{password: password})) do
        user = preload_actor(%{user | local_user: local_user})

        user
        |> Email.password_reset()
        |> MailService.maybe_deliver_later()

        {:ok, user}
      end
    end)
  end

  defp validate_token(token, claim_field, now) do
    cond do
      not is_nil(Map.fetch!(token, claim_field)) ->
        {:error, TokenAlreadyClaimedError.new()}

      :gt == DateTime.compare(now, token.expires_at) ->
        {:error, TokenExpiredError.new()}

      true ->
        :ok
    end
  end

  def update_by(filters, updates) do
    Repo.update_all(Queries.query(User, filters), set: updates)
  end

  @spec update(User.t(), map) :: {:ok, User.t()} | {:error, Changeset.t()}
  def update(%User{} = user, attrs) do
    Repo.transact_with(fn ->
      attrs =
        attrs
        |> Map.put(
          :summary,
          CommonsPub.HTML.parse_input(
            Map.get(
              attrs,
              "summary",
              Map.get(attrs, :summary, "")
            ),
            "text/markdown"
          )
        )

      with {:ok, user} <- Repo.update(User.update_changeset(user, attrs)),
           {:ok, character} <- Characters.update(user, user.character, attrs),
           {:ok, local_user} <- Repo.update(LocalUser.update_changeset(user.local_user, attrs)),
           :ok <- ap_publish("update", user) do
        user = %{user | local_user: local_user, character: character}

        CommonsPub.Search.Indexer.maybe_index_object(user)

        {:ok, user}
      end
    end)
  end

  # @spec update_remote(User.t(), map) :: {:ok, User.t()} | {:error, Changeset.t()}
  def update_remote(%User{} = user, attrs) do
    Repo.transact_with(fn ->
      with {:ok, user} <- Repo.update(User.update_changeset(user, attrs)),
           {:ok, character} <- Characters.update(user, user.character, attrs) do
        user = %{user | character: character}

        CommonsPub.Search.Indexer.maybe_index_object(user)

        {:ok, user}
      end
    end)
  end

  # remote user
  def soft_delete(_deleter, %User{local_user_id: nil} = user) do
    Repo.transact_with(fn ->
      with {:ok, user2} <- Common.Deletion.soft_delete(user) do
        # ap_publish("delete", user)
        chase_delete(user, user2)
        {:ok, user2}
      end
    end)
  end

  # local user
  def soft_delete(deleter, %User{} = user) do
    Repo.transact_with(fn ->
      with {:ok, user2} <- Common.Deletion.soft_delete(user),
           {:ok, local_user} <- Common.Deletion.soft_delete(user.local_user) do
        chase_delete(deleter, user2)
        ap_publish("delete", user)
        {:ok, %{user2 | local_user: local_user}}
      end
    end)
  end

  @delete_by_filters [select: :delete, deleted: false]

  def soft_delete_by(%User{} = user, filters) do
    with {:ok, _} <-
           Repo.transact_with(fn ->
             {_, ids} = update_by(@delete_by_filters ++ filters, deleted_at: DateTime.utc_now())

             with :ok <- chase_delete(user, ids) do
               ap_publish("delete", ids)
             end
           end),
         do: :ok
  end

  # TODO: some of these queries could be combined if we modified the queries modules
  defp chase_delete(user, users) do
    with :ok <- Characters.soft_delete_by(user, id: users),
         :ok <- Activities.soft_delete_by(user, creator: users),
         :ok <- Activities.soft_delete_by(user, context: users),
         :ok <- Blocks.soft_delete_by(user, creator: users),
         #  :ok <- Blocks.soft_delete_by(user, context: users),
         #  :ok <- Flags.soft_delete_by(user, context: users),
         :ok <- Follows.soft_delete_by(user, creator: users),
         :ok <- Follows.soft_delete_by(user, context: users),
         :ok <- Likes.soft_delete_by(user, creator: users),
         :ok <- Likes.soft_delete_by(user, context: users),
         :ok <- Threads.Comments.soft_delete_by(user, creator: users) do
      # Give away some things to the "deleted" user
      Communities.update_by(user, [creator: users], creator_id: @deleted_user_id)
      Collections.update_by(user, [creator: users], creator_id: @deleted_user_id)
      Resources.update_by(user, [creator: users], creator_id: @deleted_user_id)
      Features.update_by(user, [creator: users], creator_id: @deleted_user_id)
      # Flags.update_by(user, [creator: users], creator_id: @deleted_user_id)
      :ok
    end
  end

  # @spec make_instance_admin(User.t()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def make_instance_admin(%User{} = user) do
    cs = LocalUser.make_instance_admin_changeset(user.local_user)

    Repo.transact_with(fn ->
      with {:ok, local_user} <- Repo.update(cs) do
        user = preload_actor(%{user | local_user: local_user})
        {:ok, user}
      end
    end)
  end

  # @spec unmake_instance_admin(User.t()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def unmake_instance_admin(%User{} = user) do
    cs = LocalUser.unmake_instance_admin_changeset(user.local_user)

    Repo.transact_with(fn ->
      with {:ok, local_user} <- Repo.update(cs) do
        user = preload_actor(%{user | local_user: local_user})
        {:ok, user}
      end
    end)
  end

  def feed_subscriptions(%User{id: id}) do
    FeedSubscriptions.many(deleted: false, disabled: false, activated: true, subscriber: id)
  end

  def is_admin(%User{local_user: %LocalUser{is_instance_admin: val}}), do: val

  @spec preload(User.t(), Keyword.t()) :: User.t()
  def preload(user, opts \\ [])

  def preload(%User{} = user, opts) do
    Repo.preload(user, [:local_user, :character], opts)
  end

  def preload(u, _) do
    u
  end

  @spec preload_actor(User.t(), Keyword.t()) :: User.t()
  def preload_actor(%User{} = user, opts \\ []) do
    Repo.preload(user, :character, opts)
  end

  @spec preload_local_user(User.t(), Keyword.t()) :: User.t()
  def preload_local_user(%User{} = user, opts \\ []) do
    Repo.preload(user, :local_user, opts)
  end

  defp ap_publish(verb, users) when is_list(users) do
    APPublishWorker.batch_enqueue(verb, users)
    :ok
  end

  defp ap_publish(verb, %{character: %{peer_id: nil}} = user) do
    APPublishWorker.enqueue(verb, %{"context_id" => user.id})
    :ok
  end

  defp ap_publish(_, _), do: :ok

  def ap_receive_update(actor, data, creator \\ nil) do
    with {:ok, user} <-
           CommonsPub.Users.update_remote(actor, data) do
      {:ok, user}
    else
      {:error, e} -> {:error, e}
    end
  end

  @doc false
  def default_inbox_query_contexts() do
    CommonsPub.Config.get!(__MODULE__)
    |> Keyword.fetch!(:default_inbox_query_contexts)
  end

  @doc false
  def default_outbox_query_contexts() do
    CommonsPub.Config.get!(__MODULE__)
    |> Keyword.fetch!(:default_outbox_query_contexts)
  end

  def indexing_object_format(%CommonsPub.Users.User{} = user) do
    follower_count =
      case CommonsPub.Follows.FollowerCounts.one(context: user.id) do
        {:ok, struct} -> struct.count
        {:error, _} -> nil
      end

    icon = CommonsPub.Uploads.remote_url_from_id(user.icon_id)
    image = CommonsPub.Uploads.remote_url_from_id(user.image_id)
    url = CommonsPub.ActivityPub.Utils.get_actor_canonical_url(user)

    %{
      "index_type" => "User",
      "id" => user.id,
      "canonical_url" => url,
      "followers" => %{
        "total_count" => follower_count
      },
      "icon" => icon,
      "image" => image,
      "name" => user.name,
      "published_at" => user.published_at,
      "username" => CommonsPub.Characters.display_username(user),
      "summary" => Map.get(user, :summary),
      "index_instance" => CommonsPub.Search.Indexer.host(url)
    }
  end
end
