-- vim: set sw=2 sts=2 tw=79 cc=80 list listchars=trail\:·:
BestCompanion = {}

BestCompanion.name = "BestCompanion"

function BestCompanion.Initialize()
  -- Nothing to do... yet
end

function BestCompanion.OnAddOnLoaded (event, addonName)
  if addonName == BestCompanion.name then
    BestCompanion.Initialize()
    EVENT_MANAGER:UnregisterForEvent (BestCompanion.name, EVENT_ADD_ON_LOADED) 
  end
end

EVENT_MANAGER:RegisterForEvent (BestCompanion.name, EVENT_ADD_ON_LOADED, BestCompanion.OnAddOnLoaded)

EVENT_MANAGER:RegisterForEvent (BestCompanion.name, EVENT_PLAYER_ACTIVATED, function()
    d("Hello Nirn!")
  end)
