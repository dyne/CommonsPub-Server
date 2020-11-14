defmodule CommonsPub.Web.GraphQL.QueryHelper do
  @moduledoc """
  Helpful functions for preparing to query or test Absinthe applications.

  These functions make it trivially easy to generate very large, comprehensive queries for our
  types in Absinthe that will resolve every field in that type (and any number of subtypes as
  well to a given level of depth)

  Adapted from https://github.com/devonestes/assertions (MIT license)
  """

  require Logger

  @spec run_query_id(any(), module(), atom(), non_neg_integer(), Keyword.t(), boolean()) ::
          String.t()
  def run_query_id(id, schema, type, nesting \\ 1, override_fun \\ nil, debug \\ nil) do

    q = query_with_id(schema, type, nesting, override_fun)

    with {:ok, go} <- Absinthe.run(q, schema, variables: %{"id" => id}) do

      maybe_debug(q, go, debug)

      go |> Map.get(:data) |> Map.get(Atom.to_string(type))

    else e ->
        maybe_debug(q, e, true)
        e
    end
  end

  @spec query_with_id(module(), atom(), non_neg_integer(), Keyword.t()) :: String.t()
  def query_with_id(schema, type, nesting \\ 1, override_fun \\ nil) do
    document = document_for(schema, type, nesting, override_fun)

    """
     query ($id: ID) {
       #{type}(id: $id) {
         #{document}
       }
     }
    """
  end

  @doc """
  Returns a document containing the fields in a type and any sub-types down to a limited depth of
  nesting (default `3`).

  This is helpful for generating a document to use for testing your GraphQL API. This function
  will always return all fields in the given type, ensuring that there aren't any accidental
  fields with resolver functions that aren't tested in at least some fashion.

  ## Example

      iex> document_for(:user, 2)

      ```
      name
      age
      posts {
        title
        subtitle
      }
      comments {
        body
      }
      ```

  """
  @spec document_for(module(), atom(), non_neg_integer(), Keyword.t()) :: String.t()
  def document_for(schema, type, nesting \\ 1, override_fun \\ nil) do
    schema
    |> fields_for(type, nesting)
    |> apply_overrides(override_fun)
    |> format_fields(type, 10, schema)
    |> List.to_string()
  end

  @doc """
  Returns all fields in a type and any sub-types down to a limited depth of nesting (default `3`).

  This is helpful for converting a struct or map into an expected response that is a bare map
  and which can be used in some of the other assertions below.
  """
  @spec fields_for(module(), atom(), non_neg_integer()) :: list(fields) | atom()
        when fields: atom() | {atom(), list(fields)}
  def fields_for(schema, %{of_type: type}, nesting) do
    # We need to unwrap non_null and list sub-fields
    fields_for(schema, type, nesting)
  end

  def fields_for(schema, type, nesting) do
    type
    |> schema.__absinthe_type__()
    |> get_fields(schema, nesting)
  end

  # We don't include any other objects in the list when we've reached the end of our nesting,
  # otherwise the resulting document would be invalid because we need to select sub-fields of
  # all objects.
  def get_fields(%{fields: _}, _, 0) do
    :reject
  end

  # We can't use the struct expansion directly here, because then it becomes a compile-time
  # dependency and will make compilation fail for projects that doesn't use Absinthe.
  def get_fields(%struct{fields: fields} = type, schema, nesting)
      when struct == Absinthe.Type.Interface do
    interface_fields =
      Enum.reduce(fields, [], fn {_, value}, acc ->
        case fields_for(schema, value.type, nesting - 1) do
          :reject -> acc
          :scalar -> [String.to_atom(value.name) | acc]
          list -> [{String.to_atom(value.name), list} | acc]
        end
      end)

    implementors = Map.get(schema.__absinthe_interface_implementors__(), type.identifier)

    implementor_fields =
      Enum.map(implementors, fn type ->
        {type, fields_for(schema, type, nesting) -- interface_fields -- [:__typename]}
      end)

    {interface_fields, implementor_fields}
  end

  def get_fields(%struct{types: types}, schema, nesting) when struct == Absinthe.Type.Union do
    {[], Enum.map(types, &{&1, fields_for(schema, &1, nesting)})}
  end

  def get_fields(%{fields: fields}, schema, nesting) do
    Enum.reduce(fields, [], fn {_, value}, acc ->
      case fields_for(schema, value.type, nesting - 1) do
        :reject -> acc
        :scalar -> [String.to_atom(value.name) | acc]
        list when is_list(list) -> [{String.to_atom(value.name), list} | acc]
        tuple -> [{String.to_atom(value.name), tuple} | acc]
      end
    end)
  end

  def get_fields(_, _, _) do
    :scalar
  end

  def format_fields({interface_fields, implementor_fields}, _, 10, schema) do
    interface_fields =
      interface_fields
      |> Enum.reduce({[], 12}, &do_format_fields(&1, &2, schema))
      |> elem(0)

    implementor_fields =
      implementor_fields
      |> Enum.map(fn {type, fields} ->
        type_info = schema.__absinthe_type__(type)
        [_ | rest] = format_fields(fields, type, 12, schema)
        fields = ["...on #{type_info.name} {\n" | rest]
        [padding(12), fields]
      end)

    Enum.reverse([implementor_fields | interface_fields])
  end

  def format_fields(fields, _, 10, schema) do
    fields =
      fields
      |> Enum.reduce({[], 12}, &do_format_fields(&1, &2, schema))
      |> elem(0)

    Enum.reverse(fields)
  end

  def format_fields({interface_fields, implementor_fields}, type, left_pad, schema)
      when is_list(interface_fields) do
    interface_fields =
      interface_fields
      |> Enum.reduce({["#{camelize(type)} {\n"], left_pad + 2}, &do_format_fields(&1, &2, schema))
      |> elem(0)

    implementor_fields =
      implementor_fields
      |> Enum.map(fn {type, fields} ->
        type_info = schema.__absinthe_type__(type)
        [_ | rest] = format_fields(fields, type, left_pad + 2, schema)
        fields = ["...on #{type_info.name} {\n" | rest]
        [padding(left_pad + 2), fields]
      end)

    Enum.reverse(["}\n", padding(left_pad), implementor_fields | interface_fields])
  end

  def format_fields(fields, type, left_pad, schema) do
    fields =
      fields
      |> Enum.reduce({["#{camelize(type)} {\n"], left_pad + 2}, &do_format_fields(&1, &2, schema))
      |> elem(0)

    Enum.reverse(["}\n", padding(left_pad) | fields])
  end

  def do_format_fields({type, sub_fields}, {acc, left_pad}, schema) do
    {[format_fields(sub_fields, type, left_pad, schema), padding(left_pad) | acc], left_pad}
  end

  def do_format_fields(type, {acc, left_pad}, _) do
    {["\n", camelize(type), padding(left_pad) | acc], left_pad}
  end

  def apply_overrides(fields, override_fun) when is_function(override_fun) do
    for n <- fields, do: override_fun.(n)
  end

  def apply_overrides(fields, _) do
    fields
  end

  # utils - TODO: move to generic module
  def padding(0), do: ""
  def padding(left_pad), do: Enum.map(1..left_pad, fn _ -> " " end)

  def camelize(type), do: Absinthe.Utils.camelize(to_string(type), lower: true)

  def maybe_debug(q, %{errors: errors} = obj, _) do
    Logger.warn("The below GraphQL query had some errors in the response:")
    IO.inspect(errors: errors)
    maybe_debug(q, Map.get(obj, :data), true)
  end

  def maybe_debug(q, obj, debug) do
    if(debug || CommonsPub.Config.get([:logging, :tests_output_graphql])) do
      IO.inspect(graphql_query: q)
      IO.inspect(graphql_response: obj)
    end
  end
end
