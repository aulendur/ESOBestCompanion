-- vim: set sw=2 sts=2 tw=79 cc=80 list listchars=trail\:·:
BestCompanion = {}
BestCompanion.name = "BestCompanion"

-- generalized reference
local addon = BestCompanion

--addon.Companions = {
--  [9245] = "Bastian Hallix",
--  [9353] = "Mirri Elendis",
--  [9911] = "Ember",
--  [9912] = "Isobel Veloise",
--  [11113] = "Sharp-as-Night",
--  [11114] = "Azandar al-Cybiades",
--}

function addon.Initialize()
  addon.player_activated = 0
  addon.Companions = {}
  -- GetActiveCompanionDefId returns integers from 1 up to 8 as of U42
  for i = 1, 10 do
    local cid = GetCompanionCollectibleId (i)
    local name, _, _, _, unlocked, _, active = GetCollectibleInfo (cid)
    addon.Companions[i] = { name = name, unlocked = unlocked, active = active }
  end
  -- TODO: register introquest complete event and update companion table
  addon.init_done = "Hello Nirn!"
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
  addon.player_activated = addon.player_activated + 1
  if addon.player_activated == 1 then
    d(addon.init_done)
  end
end)

function addon.summonCompanion (companionid, wait)
  -- TODO: wrap in check if(companion is unlocked)
  -- TODO: wrap in check if(companion not already active)
  zo_callLater(function()
    UseCollectible (companionid)
  end, wait)
end

EVENT_MANAGER:RegisterForEvent (addon.name, EVENT_CRAFTING_STATION_INTERACT,
function(event, station)
  local wait = 0
  -- TODO: save active companion and resummon after crafting
  if GetCraftingInteractionType() == CRAFTING_TYPE_ALCHEMY then
    addon.summonCompanion (11113, wait)
  elseif GetCraftingInteractionType() == CRAFTING_TYPE_BLACKSMITHING then
    addon.summonCompanion (9912, wait)
  elseif GetCraftingInteractionType() == CRAFTING_TYPE_PROVISIONING then
    addon.summonCompanion (9353, wait)
  end
end)

EVENT_MANAGER:RegisterForEvent (addon.name, EVENT_COMPANION_ACTIVATED,
function()
  local cid = GetActiveCompanionDefId()
  d("companion summoned " .. cid)
  -- Bastian = 1, Mirri = 2, Sharp = 8
end)
