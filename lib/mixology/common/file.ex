# SPDX-License-Identifier: AGPL-3.0-only

defmodule CommonsPub.Utils.File do
  @moduledoc """
  Utilities for working with files and URLs
  """

  @doc """
  Returns true if the given `filepath` contains one of the
  extensions in `allowed_exts`.

  Note that the comparison is case-insensitive.
  """
  @spec has_extension?(binary, [binary]) :: boolean
  def has_extension?(filepath, allowed_exts) do
    allowed_exts
    |> Enum.map(fn ext -> ".#{ext}" end)
    |> Enum.member?(extension(filepath))
  end

  @doc """
  Return the file extension of the given `filepath` in lowercase.
  """
  @spec extension(binary) :: binary
  def extension(filepath) do
    filepath |> Path.extname() |> String.downcase()
  end

  @doc """
  Return the base name of a full file path without the extension.

  ## Example

  iex> basename("some/path/file.txt")
  "file"
  """
  @spec basename(binary) :: binary
  def basename(filepath) do
    case extension(filepath) do
      "" -> Path.basename(filepath)
      ext -> Path.basename(filepath, ext)
    end
  end

  # Taken from https://github.com/stavro/arc/blob/master/lib/arc/file.ex
  @doc """
  Generate a path in the OS temporary directory.

  If a file is supplied, the extension of the file name is preserved.
  """
  @spec generate_temporary_path(file :: any) :: binary
  def generate_temporary_path(file \\ nil) do
    extension = extension((file && file.path) || "")

    filename =
      :crypto.strong_rand_bytes(20)
      |> Base.encode32()
      |> Kernel.<>(extension)

    Path.join(System.tmp_dir(), filename)
  end

  def ensure_valid_url(url) when is_binary(url), do: ensure_valid_url(URI.parse(url))
  def ensure_valid_url(_uri = %URI{host: nil}), do: ""
  def ensure_valid_url(_uri = %URI{host: ""}), do: ""
  def ensure_valid_url(uri = %URI{scheme: nil}), do: ensure_valid_url("http://#{to_string(uri)}")
  def ensure_valid_url(uri = %URI{path: nil}), do: ensure_valid_url("#{to_string(uri)}/")
  def ensure_valid_url(%URI{} = uri), do: uri |> URI.to_string()
  def ensure_valid_url(_), do: ""

  def fix_relative_url("", _), do: nil

  def fix_relative_url(url, original_url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: nil} -> URI.merge(original_url, url) |> to_string()
      _ -> url
    end
  end

  def fix_relative_url(nil, _), do: nil

  def validate_uri(%URI{scheme: scheme, host: host}) do
    if scheme in ["http", "https"] and not is_nil(host) do
      :ok
    else
      {:error, :invalid_uri_format}
    end
  end
end
