defmodule CommonsPub.Utils.TrendyExtended do
   require Modularity.Module.Extend
   Modularity.Module.Extend.extends CommonsPub.Utils.Trendy

   def some(count_or_range \\ 1, fun) do
      require Logger
      Logger.info("Selecting #{count_or_range} random thing(s) returned by function #{inspect fun}")
      # call function from original module:
      super(count_or_range, fun)
   end
end
