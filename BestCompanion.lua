-- vim: set et ts=2 sw=2 sts=2 tw=79 cc=80 list listchars=trail\:·:
BestCompanion = {}
BestCompanion.name = "BestCompanion"

-- generalized reference
local addon = BestCompanion

local BASTIAN = 1
local MIRRI   = 2
local EMBER   = 5
local ISOBEL  = 6
local SHARP   = 8
local AZANDAR = 9

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
    -- d(addon.init_done)
  end
end)

function addon.summonCompanion (companionid, wait)
  if addon.Companions[companionid].unlocked and companionid ~= GetActiveCompanionDefId() then
    zo_callLater(function()
      UseCollectible (addon.Companions[companionid].id)
    end, wait)
  else
    -- TODO: alert if the companion is available but introquest hasn't been completed
  end
end

EVENT_MANAGER:RegisterForEvent (addon.name, EVENT_CRAFTING_STATION_INTERACT,
function(event, station)
  local wait = 0
  -- TODO: save active companion and resummon after crafting
  if GetCraftingInteractionType() == CRAFTING_TYPE_ALCHEMY then
    addon.summonCompanion (SHARP, wait)
  elseif GetCraftingInteractionType() == CRAFTING_TYPE_BLACKSMITHING then
    addon.summonCompanion (ISOBEL, wait)
  elseif GetCraftingInteractionType() == CRAFTING_TYPE_PROVISIONING then
    addon.summonCompanion (MIRRI, wait)
  end
end)

EVENT_MANAGER:RegisterForEvent (addon.name, EVENT_COMPANION_ACTIVATED,
function()
  local cid = GetActiveCompanionDefId()
  -- d("companion summoned " .. cid)
end)
