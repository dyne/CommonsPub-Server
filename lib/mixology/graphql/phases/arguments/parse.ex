# this code is taken from absinthe
defmodule CommonsPub.Web.GraphQL.Phase.Arguments.Parse do
  @moduledoc false

  # Special handling for types that are lying about being scalar

  alias Absinthe.Blueprint
  alias Absinthe.Blueprint.Input.{Integer, List, Null, String, Value}
  alias Absinthe.Type.Scalar
  alias CommonsPub.Web.GraphQL.Cursor
  use Absinthe.Phase

  def run(input, _options \\ []) do
    result = Blueprint.prewalk(input, &handle_node/1)
    {:ok, result}
  end

  defp handle_node(%{normalized: nil} = node), do: node

  defp handle_node(
         %Value{
           schema_node: %Scalar{identifier: :cursor},
           normalized: %List{items: items}
         } = node
       ),
       do: handle_list(node, items)

  defp handle_node(
         %Value{
           schema_node: %Scalar{identifier: :cursor},
           normalized: %{__struct__: struct, value: value}
         } = node
       )
       when struct in [Integer, String] do
    Map.merge(node, %{normalized: nil, data: %Cursor{data: value}})
  end

  defp handle_node(node), do: node

  defp handle_list(node, items) do
    case Enum.reduce_while(items, [], &handle_list_item/2) do
      :error -> failure(node)
      values -> success(node, Enum.reverse(values))
    end
  end

  defp handle_list_item(%Value{normalized: %{__struct__: struct, value: value}}, acc)
       when struct in [Integer, String, Null] do
    {:cont, [value | acc]}
  end

  defp handle_list_item(_, _), do: {:halt, :error}

  defp failure(node) do
    Map.merge(node, %{normalized: nil, flags: %{bad_parse: __MODULE__}})
  end

  defp success(node, data) do
    Map.merge(node, %{normalized: nil, data: data})
  end
end
