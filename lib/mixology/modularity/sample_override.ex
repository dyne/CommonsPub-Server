# start by archiving the old module
Modularity.Module.Override.clone(CommonsPub.Utils.Simulation, Original.CommonsPub.Utils.Simulation)

defmodule CommonsPub.Utils.Simulation do
  require Modularity.Module.Extend
  alias Original.CommonsPub.Utils.Simulation, as: Original

  # extend the archived module
  Modularity.Module.Extend.extends Original

  ####
  # Redefine existing functions, or add new ones:
  ####

  # example of straight up replacing a function
  def name(), do: Faker.Person.last_name()

  # example of modifying the input of a function
  # def maybe_one_of(list), do: list ++ [""] |> Original.maybe_one_of()

  # example of modifying the output of a function
  def location(), do: Original.location() |> String.replace(",", " -")

end
