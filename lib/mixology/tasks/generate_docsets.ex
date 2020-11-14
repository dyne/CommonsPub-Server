# SPDX-License-Identifier: AGPL-3.0-only
defmodule Mix.Tasks.CommonsPub.GenerateDocsets do
  use Mix.Task

  @usage "mix commons_pub.generate_docsets PATH"

  @shortdoc "Generate Dash-compatible docsets for the app and dependencies."
  @moduledoc """

  Usage:

    $ #{@usage}
  """

  def run([path | _]) when is_binary(path) do
    Mix.Task.run("docs")
    Mix.Task.run("app.start")

    DocsetApi.Builder.build("CommonsPub", "docs/exdoc", path)

    _configured_deps = Enum.map(CommonsPub.Mixfile.deps_list(), &dep_process(&1, path))
    # IO.inspect(configured_deps, limit: :infinity)
  end

  def run(_args),
    do:
      Mix.shell().error("""
      Invalid parameters.

      Usage:

        #{@usage}
      """)

  defp dep_process(dep, path) do
    lib = elem(dep, 0)

    DocsetApi.Builder.build(Atom.to_string(lib), path)
  end
end
