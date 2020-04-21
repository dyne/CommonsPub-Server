# MoodleNet: Connecting and empowering educators worldwide
# Copyright © 2018-2020 Moodle Pty Ltd <https://moodle.com/moodlenet/>
# Contains code from Pleroma <https://pleroma.social/> and CommonsPub <https://commonspub.org/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule MoodleNetWeb.EmailView do
  @moduledoc """
  Email view
  """
  use MoodleNetWeb, :view

  def app_name(), do: Application.get_env(:moodle_net, :app_name)

end
