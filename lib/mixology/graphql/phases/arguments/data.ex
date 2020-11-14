defmodule CommonsPub.Web.GraphQL.Phase.Arguments.Data do
  @moduledoc false

  # Populate all arguments in the document with their provided data values:
  #
  # - If valid data is available for an argument, set the `Argument.t`'s
  #   `data_value` field to that value.
  # - If no valid data is available for an argument, set the `Argument.t`'s
  #   `data_value` to `nil`.
  # - When determining the value of the argument, mark any invalid nodes
  #   in the `Argument.t`'s `normalized_value` tree with `:invalid` and a
  #   reason.
  # - If non-null arguments are not provided (eg, a `Argument.t` is missing
  #   from `normalized_value`), add a stub `Argument.t` and flag it as
  #   `:invalid` and `:missing`.
  # - If non-null input fields are not provided (eg, an `Input.Field.t` is
  #   missing from `normalized_value`), add a stub `Input.Field.t` and flag it as
  #   `:invalid` and `:missing`.
  #
  # Note that the limited validation that occurs in this phase is limited to
  # setting the `data_value` to `nil`, adding flags to the `normalized_value`,
  # and building stub fields/arguments when missing values are required. Actual
  # addition of errors is handled by validation phases.

  alias Absinthe.Blueprint.Input.{Argument, List, Null, Object, Value}
  alias Absinthe.Blueprint.Document.Field
  alias Absinthe.{Blueprint}
  use Absinthe.Phase
  alias CommonsPub.Web.GraphQL.Cursor

  def run(input, _options \\ []) do
    # By using a postwalk we can worry about leaf nodes first (scalars, enums),
    # and then for list and objects merely grab the data values.
    result = Blueprint.postwalk(input, &handle_node/1)
    {:ok, result}
  end

  def handle_node(%Field{arguments: []} = node) do
    node
  end

  def handle_node(%Field{arguments: args} = node) do
    %{node | argument_data: Argument.value_map(args)}
  end

  def handle_node(%Argument{input_value: input} = node) do
    # IO.inspect(input: input)
    %{node | value: input.data}
  end

  def handle_node(%Value{data: %Cursor{data: _data}} = node) do
    # IO.inspect(data: data)
    node
  end

  def handle_node(%Value{normalized: %List{items: items}} = node) do
    data_list = for %{data: data} = item <- items, Value.valid?(item), do: data
    %{node | data: data_list}
  end

  def handle_node(%Value{normalized: %Object{fields: fields}} = node) do
    data =
      for field <- fields, include_field?(field), into: %{} do
        {field.schema_node.identifier, field.input_value.data}
      end

    %{node | data: data}
  end

  def handle_node(node), do: node

  defp include_field?(%{input_value: %{normalized: %Null{}}}), do: true
  defp include_field?(%{input_value: %{data: nil}}), do: false
  defp include_field?(_), do: true
end
