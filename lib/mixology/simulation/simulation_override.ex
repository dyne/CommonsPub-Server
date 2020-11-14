alias CommonsPub.Utils.Simulation, as: ExtendingModule
alias ModuleOverride.CommonsPub.Utils.Simulation, as: ArchiveModule

ModuleOverride.archive_module(Path.dirname(__ENV__.file) <> "/simulation.ex", ExtendingModule)

defmodule ExtendingModule do
  require ModuleExtend
  ModuleExtend.extends(ArchiveModule)

  @moduledoc """
  (Re)define new or existing functions
  """

  # example of straight up replacing a function
  def name(), do: Faker.Person.last_name()

  # example of modifying the input of a function
  # def maybe_one_of(list), do: list ++ [""] |> ArchiveModule.maybe_one_of()

  # example of modifying the output of a function
  def location(), do: ArchiveModule.location() |> String.replace(",", " -")

end
