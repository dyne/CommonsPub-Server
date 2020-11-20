defmodule Modularity.Module.Extend do
  defmacro extends(module) do
    require Logger

    module = Macro.expand(module, __CALLER__)

    Logger.info("[Modularity.Module.Extend] Extending module #{inspect(module)}")

    functions = module.__info__(:functions)

    signatures =
      Enum.map(functions, fn {name, arity} ->
        args =
          if arity == 0 do
            []
          else
            Enum.map(1..arity, fn i ->
              {String.to_atom(<<?x, ?A + i - 1>>), [], nil}
            end)
          end

        {name, [], args}
      end)

    zipped = List.zip([signatures, functions])

    for sig_func <- zipped do
      quote do
        defdelegate unquote(elem(sig_func, 0)), to: unquote(module)
        defoverridable unquote([elem(sig_func, 1)])
      end
    end
  end
end
