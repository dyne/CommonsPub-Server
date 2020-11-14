# SPDX-License-Identifier: AGPL-3.0-only
defmodule Mix.Tasks.CommonsPub.AllowEmail do
  use Mix.Task

  @usage "mix commons_pub.allow_email EMAIL"

  @shortdoc "Allow an address to allow login locally."
  @moduledoc """
  External developers do not typically have moodle email addresses and so need
  to whitelist their address when signing up on a local instance.

  Usage:

    $ #{@usage}
  """

  def run([email | _]) when is_binary(email) do
    Mix.Task.run("app.start")

    if CommonsPub.Access.is_register_accessed?(email) do
      Mix.shell().info("#{email} already allowed to sign up.")
    else
      {:ok, _} = CommonsPub.Access.create_register_email(email)
      Mix.shell().info("#{email} added to the allow list.")
    end
  end

  def run(_args),
    do:
      Mix.shell().error("""
      Invalid parameters.

      Usage:

        #{@usage}
      """)
end
