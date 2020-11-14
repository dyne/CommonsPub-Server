defmodule CommonsPub.Web.GraphQL.Middleware.Debug do
  alias Absinthe.Resolution

  def call(resolution, :start) do
    path = Enum.join(Resolution.path(resolution), ".")

    IO.puts("""
    ==========DEBUG==========
    starting: #{path}
    source: #{inspect(resolution.source, pretty: true)}
    -------------------------
    """)

    %{resolution | middleware: resolution.middleware ++ [{__MODULE__, {:finish, path}}]}
  end

  def call(resolution, {:finish, path}) do
    IO.puts("""
    ==========DEBUG==========
    resolved: #{path}
    value: #{inspect(resolution.value, pretty: true)}
    -------------------------
    """)

    resolution
  end
end
