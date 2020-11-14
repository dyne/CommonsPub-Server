# require Logger
# alias CommonsPub.Utils.Simulation, as: Mod

# defmodule ModuleOrigin.Simulation do
#   @moduledoc """
#   Clone the existing module under a new name
#   """
#   Code.ensure_compiled(Mod)

#   for {func, arity} <- Mod.__info__(:functions) do
#     args = Macro.generate_arguments(arity, __MODULE__)

#     def unquote(func)(unquote_splicing(args)) do
#       Mod.unquote(func)(unquote_splicing(args))
#     rescue
#       Mod.Error -> handle_error()
#     end
#   end

#   def handle_error(), do: Logger.info("Error while overiding a module")

# end


# defmodule CommonsPub.Utils.Simulation do
#   @moduledoc """
#   (Re)define functions
#   """
#    require ModuleExtend
#    ModuleExtend.extends ModuleOrigin.Simulation

#    def location(), do: Faker.Address.country()

# end
