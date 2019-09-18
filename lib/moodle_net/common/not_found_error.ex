# MoodleNet: Connecting and empowering educators worldwide
# Copyright © 2018-2019 Moodle Pty Ltd <https://moodle.com/moodlenet/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule MoodleNet.Common.NotFoundError do
  @enforce_keys [:id]
  defstruct @enforce_keys

  @type t :: %__MODULE__{ id: term() }

  @spec new(term()) :: t()
  @doc "Create a new NotFoundError with the given id"
  def new(id), do: %__MODULE__{id: id}
end
