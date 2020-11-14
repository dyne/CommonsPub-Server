# SPDX-License-Identifier: AGPL-3.0-only
defmodule CommonsPub.GraphQL.PageInfo do
  @moduledoc """
  Information about this page's relation to a larger result set
  """
  @enforce_keys ~w(start_cursor end_cursor has_previous_page has_next_page)a
  defstruct @enforce_keys

  alias CommonsPub.GraphQL.PageInfo

  @type t :: %PageInfo{
          start_cursor: binary | nil,
          end_cursor: binary | nil,
          has_previous_page: true | false | nil,
          has_next_page: true | false | nil
        }

  def new(start_cursor, end_cursor, has_previous_page, has_next_page) do
    %PageInfo{
      start_cursor: start_cursor,
      end_cursor: end_cursor,
      has_previous_page: has_previous_page,
      has_next_page: has_next_page
    }
  end
end
