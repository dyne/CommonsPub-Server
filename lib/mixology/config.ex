# SPDX-License-Identifier: AGPL-3.0-only

defmodule CommonsPub.Config do
  defmodule Error do
    defexception [:message]
  end

  def get(key), do: get(key, nil)

  def get([key], default), do: get(key, default)

  def get([parent_key | keys], default) do
    case :commons_pub
         |> Application.get_env(parent_key)
         |> get_in(keys) do
      nil -> default
      any -> any
    end
  end

  def get(key, default) do
    Application.get_env(:commons_pub, key, default)
  end

  def get!(key) do
    value = get(key, nil)

    if value == nil do
      raise(Error, message: "Missing configuration value: #{inspect(key, pretty: true)}")
    else
      value
    end
  end

  def put([key], value), do: put(key, value)

  def put([parent_key | keys], value) do
    parent =
      CommonsPub.Config.get(parent_key, [])
      |> put_in(keys, value)

    Application.put_env(:commons_pub, parent_key, parent)
  end

  def put(key, value) do
    Application.put_env(:commons_pub, key, value)
  end

  def delete([key]), do: delete(key)

  def delete([parent_key | keys]) do
    {_, parent} =
      CommonsPub.Config.get(parent_key)
      |> get_and_update_in(keys, fn _ -> :pop end)

    Application.put_env(:commons_pub, parent_key, parent)
  end

  def delete(key) do
    Application.delete_env(:commons_pub, key)
  end

  def module_enabled?(mod) do
    # TODO: user-controlled disabling of extensions/modules
    Code.ensure_loaded?(mod)
  end
end
