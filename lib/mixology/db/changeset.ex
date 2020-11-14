# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Common.Changeset do
  @moduledoc "Helper functions for changesets"

  alias Ecto.Changeset
  alias Ecto.ULID

  # alias CommonsPub.Locales
  alias CommonsPub.Mail.Checker

  @doc "Generates the primary ID for an object, and sets the canonical URL based on that"
  def cast_object(changeset) do
    cast_object(changeset, Changeset.get_field(changeset, :canonical_url))
  end

  defp cast_object(cs, x) when not is_nil(x), do: cs

  defp cast_object(cs, _) do
    id = ULID.generate()
    Changeset.put_change(cs, :id, id)
    Changeset.put_change(cs, :canonical_url, ActivityPub.Utils.object_url(%{id: id}))
  end

  @doc "Validates a country code is one of the ones we know about"
  def validate_country_code(changeset, field) do
    Changeset.validate_change(changeset, field, fn _, code ->
      case CommonsPub.Locales.country(code) do
        {:ok, _} -> []
        _ -> [{field, "must be a recognised country code"}]
      end
    end)
  end

  @doc "Validates a language code is one of the ones we know about"
  def validate_language_code(changeset, field) do
    Changeset.validate_change(changeset, field, fn _, code ->
      case CommonsPub.Locales.language(code) do
        {:ok, _} -> []
        _ -> [{field, "must be a recognised language code"}]
      end
    end)
  end

  @spec validate_http_url(Changeset.t(), atom) :: Changeset.t()
  @doc "Validates that a URL uses HTTP(S) and has a correct format."
  def validate_http_url(changeset, field) do
    Changeset.validate_change(changeset, field, fn ^field, url ->
      if valid_http_uri?(URI.parse(url)) do
        []
      else
        [{field, "has an invalid URL format"}]
      end
    end)
  end

  defp valid_http_uri?(%URI{scheme: scheme, host: host}) do
    scheme in ["http", "https"] && not is_nil(host)
  end

  @spec validate_email(Changeset.t(), atom) :: Changeset.t()
  @doc "Validates an email for correctness"
  def validate_email(changeset, field) do
    with {:ok, email} <- Changeset.fetch_change(changeset, field),
         {:error, reason} <- Checker.validate_email(email) do
      message = validate_email_message(reason)
      Changeset.add_error(changeset, field, message, validation: reason)
    else
      _ -> changeset
    end
  end

  @spec validate_email_domain(Changeset.t(), atom) :: Changeset.t()
  def validate_email_domain(changeset, field) do
    with {:ok, domain} <- Changeset.fetch_change(changeset, field),
         {:error, reason} <- Checker.validate_domain(domain) do
      message = validate_email_message(reason)
      Changeset.add_error(changeset, field, message, validation: reason)
    else
      _ -> changeset
    end
  end

  defp validate_email_message(:format), do: "is of the wrong format"
  defp validate_email_message(:mx), do: "failed an MX record check"

  @spec validate_not_expired(Changeset.t(), DateTime.t(), atom, binary) :: Changeset.t()
  @doc "Validates that the entity has not expired"
  def validate_not_expired(
        cs,
        now \\ DateTime.utc_now(),
        column \\ :expires_at,
        message \\ "expired"
      ) do
    case Changeset.fetch_field(cs, column) do
      {_, time} ->
        case DateTime.compare(time, now) do
          :gt -> cs
          _ -> Changeset.add_error(cs, column, message)
        end
    end
  end

  @doc "Creates a changeset for claiming an entity"
  def claim_changeset(it, column \\ :claimed_at, error \\ "was already claimed"),
    do: soft_delete_changeset(it, column, error)

  #  @spec soft_delete_changeset(Changeset.t(), atom, any) :: Changeset.t()
  @doc "Creates a changeset for deleting an entity"
  def soft_delete_changeset(it, column \\ :deleted_at, error \\ "was already deleted") do
    cs = Changeset.cast(it, %{}, [])

    case Changeset.fetch_field(cs, column) do
      :error -> Changeset.change(cs, [{column, DateTime.utc_now()}])
      {_, nil} -> Changeset.change(cs, [{column, DateTime.utc_now()}])
      {_, _} -> Changeset.add_error(cs, column, error)
    end
  end

  @spec change_public(Changeset.t()) :: Changeset.t()
  @doc "Keeps published_at in accord with is_public"
  def change_public(%Changeset{} = changeset),
    do: change_synced_timestamp(changeset, :is_public, :published_at)

  @spec change_muted(Changeset.t()) :: Changeset.t()
  @doc "Keeps muted_at in accord with is_muted"
  def change_muted(%Changeset{} = changeset),
    do: change_synced_timestamp(changeset, :is_muted, :muted_at)

  @spec change_disabled(Changeset.t()) :: Changeset.t()
  @doc "Keeps disabled_at in accord with is_disabled"
  def change_disabled(%Changeset{} = changeset),
    do: change_synced_timestamp(changeset, :is_disabled, :disabled_at)

  @spec change_synced_timestamp(Changeset.t(), atom, atom) :: Changeset.t()
  @doc """
  If a changeset includes a change to `bool_field`, we ensure that the
  `timestamp` field is updated if required. In the case of true, this
  means setting it to now if it is null and in the case of false, this
  means setting it to null if it is not null.
  """
  def change_synced_timestamp(changeset, bool_field, timestamp_field) do
    bool_val = Changeset.fetch_change(changeset, bool_field)
    timestamp_val = Changeset.fetch_field(changeset, timestamp_field)

    case {bool_val, timestamp_val} do
      {{:ok, true}, {:data, value}} when not is_nil(value) ->
        changeset

      {{:ok, true}, _} ->
        Changeset.change(changeset, [{timestamp_field, DateTime.utc_now()}])

      {{:ok, false}, {:data, value}} when not is_nil(value) ->
        Changeset.change(changeset, [{timestamp_field, nil}])

      _ ->
        changeset
    end
  end

  @spec change_synced_timestamps(Changeset.t(), atom, atom, atom, atom) :: Changeset.t()
  @doc """
  If a changeset includes a change to `bool_field`, we change two
  timestamps columns (representing activated and deactivated) so that
  only one is set to a non-null value at a time.
  """
  def change_synced_timestamps(changeset, bool_field, on_field, off_field, default \\ true)

  def change_synced_timestamps(changeset, bool_field, on_field, off_field, default)
      when is_atom(bool_field) and is_atom(on_field) and
             is_atom(off_field) and is_boolean(default) do
    case Changeset.fetch_change(changeset, bool_field) do
      {:ok, val} ->
        case val do
          true ->
            changeset
            |> Changeset.put_change(on_field, DateTime.utc_now())
            |> Changeset.put_change(off_field, nil)

          false ->
            changeset
            |> Changeset.put_change(on_field, nil)
            |> Changeset.put_change(off_field, DateTime.utc_now())
        end

      :error ->
        case Changeset.fetch_field(changeset, bool_field) do
          {:changes, _} ->
            changeset

          {:data, _} ->
            changeset

          :error ->
            cs = Changeset.put_change(changeset, bool_field, default)
            change_synced_timestamps(cs, bool_field, on_field, off_field, default)
        end
    end
  end

  def validate_exactly_one(changeset, [column | _] = columns, message) do
    sum =
      Enum.reduce(columns, 0, fn field, acc ->
        if is_nil(Changeset.get_field(changeset, field)),
          do: acc,
          else: acc + 1
      end)

    if sum == 1,
      do: changeset,
      else: Changeset.add_error(changeset, column, message)
  end
end
