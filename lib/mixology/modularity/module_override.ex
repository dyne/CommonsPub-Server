defmodule Modularity.Module.Override do
  @moduledoc """
  Utility to clone a module under a new name
  """

  require Logger

  @doc """
  Clone the existing module under a new name
  """
  def clone(old_module, new_module) when is_atom(old_module) do
    Logger.info(
      "[Modularity.Module.Override] Cloning module #{module_name_string(old_module)} as #{
        module_name_string(new_module)
      }"
    )

    with {:module, _module} <- Code.ensure_compiled(old_module),
         module_source_file = old_module.module_info()[:compile][:source],
         {:ok, f} <- File.read(module_source_file) do
      Code.eval_string(
        String.replace(
          f,
          "defmodule #{module_name_string(old_module)}",
          "defmodule #{module_name_string(new_module)}"
        )
      )

      # returns name of archived module
      _new_module = String.to_existing_atom("Elixir.#{module_name_string(new_module)}")
    else
      e ->
        Logger.error("Could not find source of module #{old_module}: #{inspect(e)}")
        nil
    end
  end

  def clone(old_module, prefix) when is_binary(old_module),
    do: clone(String.to_existing_atom(old_module), prefix)

  def module_name_string(module), do: String.replace("#{module}", "Elixir.", "")
end
