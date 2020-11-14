defmodule ModuleOverride do
  @doc """
  Clone the existing module under a new name
  """
  def archive_module(module_source_file, extending_module) do
    Code.ensure_compiled(extending_module)

    with {:ok, f} <- File.read(module_source_file) do
      Code.eval_string(String.replace(f, "defmodule ", "defmodule ModuleOverride."))
    end
  end
end
