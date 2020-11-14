# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.Common.Query do
  import Ecto.Query

  def unroll(items, key \\ :context)
  def unroll(items, key) when is_list(items), do: Enum.map(items, &unroll(&1, key))
  def unroll({l, r}, key), do: %{l | key => r}

  def filter(q, {:username, username}) when is_binary(username) do
    where(q, [a], a.preferred_username == ^username)
  end

  def filter(q, {:username, usernames}) when is_list(usernames) do
    where(q, [a], a.preferred_username in ^usernames)
  end

  def order_by_recently_updated(query) do
    order_by(query, desc: :updated_at)
  end

  defmacro match_admin() do
    quote do
      %CommonsPub.Users.User{
        local_user: %CommonsPub.Users.LocalUser{is_instance_admin: true}
      }
    end
  end
end
