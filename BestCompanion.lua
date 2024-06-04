-- vim: set sw=2 sts=2 tw=79 cc=80 list listchars=trail\:·:
BestCompanion = {}
BestCompanion.name = "BestCompanion"

-- generalized reference
local addon = BestCompanion

local companions = {
  [9245] = "Bastian Hallix",
  [9353] = "Mirri Elendis",
  [9911] = "Ember",
  [9912] = "Isobel Veloise",
  [11113] = "Sharp-as-Night",
  [11114] = "Azandar al-Cybiades",
}

function addon.Initialize()
  -- Nothing to do... yet
end

function addon.OnAddOnLoaded (event, addonName)
  if addonName == addon.name then
    addon.Initialize()
    EVENT_MANAGER:UnregisterForEvent (addon.name, EVENT_ADD_ON_LOADED) 
  end
end

EVENT_MANAGER:RegisterForEvent (addon.name, EVENT_ADD_ON_LOADED, addon.OnAddOnLoaded)

EVENT_MANAGER:RegisterForEvent (addon.name, EVENT_PLAYER_ACTIVATED,
function()
  for idx = 1, GetTotalCollectiblesByCategoryType (COLLECTIBLE_CATEGORY_TYPE_COMPANION) do
    local id = GetCollectibleIdFromType (COLLECTIBLE_CATEGORY_TYPE_COMPANION, idx)
    local name, _, _, _, unlocked = GetCollectibleInfo (id)
    -- d(" * companion " .. id .. ": " .. name .. (unlocked and "" or " (locked)") )
    -- TODO: find introquest status
  end
end)

EVENT_MANAGER:RegisterForEvent (addon.name, EVENT_CRAFTING_STATION_INTERACT,
function(event, station)
  -- TODO: save active companion and resummon after crafting
  -- TODO: only for provisioning
  -- TODO: wrap in check if(Mirri is unlocked)
  d("Interacting with crafting station " .. GetCraftingSkillName (GetCraftingInteractionType()))
  local wait = 0
  zo_callLater(function()
    UseCollectible(9353)
  end, wait)
  -- TODO: Isobel for blacksmithing
  -- TODO: Sharp for alchemy
end)

EVENT_MANAGER:RegisterForEvent (addon.name, EVENT_COMPANION_ACTIVATED,
function()
  local cid = GetActiveCompanionDefId()
  d("companion summoned " .. cid)
  -- Bastian = 1, Mirri = 2, Sharp = 8
end)
