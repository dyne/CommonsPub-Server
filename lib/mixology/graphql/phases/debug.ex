# this code is taken from absinthe
defmodule CommonsPub.Web.GraphQL.Phase.Debug do
  @moduledoc false

  # Special handling for types that are lying about being scalar

  alias Absinthe.Blueprint
  alias Absinthe.Blueprint.Input.Value
  alias Absinthe.Type.Scalar
  use Absinthe.Phase

  def run(input, _options \\ []) do
    result = Blueprint.prewalk(input, &handle_node/1)
    {:ok, result}
  end

  defp handle_node(%Value{schema_node: %Scalar{identifier: :cursor}} = node) do
    IO.inspect(debug: node)
    node
  end

  defp handle_node(node), do: node
end
