-- vim: set et ts=2 sw=2 sts=2 tw=79 cc=80 list listchars=trail\:·:
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

function addon.prettyprint (ref, pre, post)
  if type (ref) == 'table' then
    local out = (pre or '') .. '{ '
      for k,v in pairs (ref) do
        out = out .. '['..k..'] = ' .. addon.prettyprint (v, pre) .. ','
      end
    return out .. '} '
  else
    return tostring (ref)
  end
end

function addon.Initialize()
  addon.player_activated = 0
  addon.Companions = {}
  -- GetActiveCompanionDefId returns integers from 1 up to 8 as of U42
  for i = 1, 10 do
    local cid = GetCompanionCollectibleId (i)
    if cid > 0 then
      local name, _, _, _, unlocked, _, active = GetCollectibleInfo (cid)
      local qid = GetCompanionIntroQuestId (cid)
      local qnm, _ = GetCompletedQuestInfo (qid)
      if not qnm then
        unlocked = false
      end
      addon.Companions[i] = { id = cid, name = name, unlocked = unlocked, active = active }
    end
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
  addon.player_activated = addon.player_activated + 1
  if addon.player_activated == 1 then
    d(addon.init_done)
    d(" * Companions: " .. addon.prettyprint (addon.Companions, '\n'))
  end
end)

function addon.summonCompanion (companionid, wait)
  if addon.Companions[companionid].unlocked then
    -- TODO: wrap in check if(companion not already active)
    zo_callLater(function()
      UseCollectible (addon.Companions[companionid].id)
    end, wait)
  else
    d("Companion " .. companionid .. " is not unlocked")
  end
end

EVENT_MANAGER:RegisterForEvent (addon.name, EVENT_CRAFTING_STATION_INTERACT,
function(event, station)
  local wait = 0
  -- TODO: save active companion and resummon after crafting
  if GetCraftingInteractionType() == CRAFTING_TYPE_ALCHEMY then
    addon.summonCompanion (8, wait)
  elseif GetCraftingInteractionType() == CRAFTING_TYPE_BLACKSMITHING then
    addon.summonCompanion (6, wait)
  elseif GetCraftingInteractionType() == CRAFTING_TYPE_PROVISIONING then
    addon.summonCompanion (2, wait)
  end
end)

EVENT_MANAGER:RegisterForEvent (addon.name, EVENT_COMPANION_ACTIVATED,
function()
  local cid = GetActiveCompanionDefId()
  -- d("companion summoned " .. cid)
  -- Bastian = 1, Mirri = 2, Ember = 5, Isobel = 6, Sharp = 8, Azandar = 9
end)
