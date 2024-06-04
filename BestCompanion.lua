-- vim: set sw=2 sts=2 tw=79 cc=80 list listchars=trail\:·:
BestCompanion = {}

BestCompanion.name = "BestCompanion"

local companions = {
  [9245] = "Bastian Hallix",
  [9353] = "Mirri Elendis",
  [9911] = "Ember",
  [9912] = "Isobel Veloise",
  [11113] = "Sharp-as-Night",
  [11114] = "Azandar al-Cybiades",
}

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

EVENT_MANAGER:RegisterForEvent (BestCompanion.name, EVENT_PLAYER_ACTIVATED,
function()
  d("BC addon found companion collectibles:")
  for idx = 1, GetTotalCollectiblesByCategoryType (COLLECTIBLE_CATEGORY_TYPE_COMPANION) do
    local id = GetCollectibleIdFromType (COLLECTIBLE_CATEGORY_TYPE_COMPANION, idx)
    local name, _, _, _, unlocked = GetCollectibleInfo (id)
    -- d(" * companion " .. id .. ": " .. name .. (unlocked and "" or " (locked)") )
    -- TODO: find introquest status
  end
  d("That's all")
end)

EVENT_MANAGER:RegisterForEvent (BestCompanion.name, EVENT_CRAFTING_STATION_INTERACT,
function(event, station)
  d("Interacting with crafting station " .. GetCraftingSkillName (GetCraftingInteractionType()))
end)

EVENT_MANAGER:RegisterForEvent (BestCompanion.name, EVENT_COMPANION_ACTIVATED,
function()
  local cid = GetActiveCompanionDefId()
  d("companion summoned " .. cid)
end)
