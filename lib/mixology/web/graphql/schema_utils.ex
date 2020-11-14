defmodule CommonsPub.Web.GraphQL.SchemaUtils do
  def hydrations_merge(hydrators) do
    Enum.reduce(hydrators, %{}, fn hydrate_fn, hydrated ->
      hydrate_merge(hydrated, hydrate_fn.())
    end)
  end

  defp hydrate_merge(a, b) do
    Map.merge(a, b, fn _, a, b -> Map.merge(a, b) end)
  end

  def context_types() do
    schemas = CommonsPub.Meta.TableService.list_pointable_schemas()

    Enum.reduce(schemas, [], fn schema, acc ->
      if CommonsPub.Config.module_enabled?(schema) and function_exported?(schema, :type, 0) and
           !is_nil(apply(schema, :type, [])) do
        Enum.concat(acc, [apply(schema, :type, [])])
      else
        acc
      end
    end)
  end
end
