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
local TANLORIN  = 12
local ZERITHVAR = 13

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
  -- GetActiveCompanionDefId returns integers from 1 up to 13 as of U44
  for i = 1, 20 do
    local cid = GetCompanionCollectibleId (i)
    if cid > 0 then
      -- Unlocked does not mean what you'd think...
      local name, _, _, _, unlocked, _, active = GetCollectibleInfo (cid)
      local qid = GetCompanionIntroQuestId (i)
      local introname, _ = GetCompletedQuestInfo (qid)
      -- zo_callLater(function()
      --  d(name .. " companiondefid " .. tostring(i) .. " unlocked: " .. tostring(unlocked))
      --  d("  intro: ".. tostring(introname) .. ", questid: " .. tostring(qid))
      --  end, 5)
      addon.Companions[i] = { id = cid, name = name, unlocked = unlocked,
        introdone = (introname ~= "" and true or false), active = active, nagplayer = true }
    end
  end

  addon.lastinteraction = {}
  addon.lastcompanion = false
  ZO_PreHook(RETICLE, "TryHandlingInteraction", function(event, possible, frametimeseconds)
    local action, name, blocked, owned, info, context, link, criminal =
      GetGameCameraInteractableActionInfo()
    if possible and action and 
      (action ~= addon.lastinteraction["action"] or name ~= addon.lastinteraction["name"]) then
      addon.lastinteraction = { action=action, name=name }
      -- Collect, Runestone
      -- Collect, Blessed Thistle/Bugloss/Columbine/Corn Flower/Mountain Flower
      --   /Nightshade/Nirnroot/Water Hyacinth/Wormwood
      -- Collect, Imp Stool/Luminous Russula/White Cap
      -- Collect, Pure Water
      -- Collect, Ebon Thread/Spidersilk
      -- Cut, Hickory/Yew
      -- Enter, Snugpod/...
      -- Examine, The Feast of Saint Coellicia IV
      -- Examine, Alchemist Delivery Crate
      -- Excavate, Dig Site
      -- Fish, Lake Fishing Hole
      -- Mine, Copper Seam/Dwarven Ore/Ebony Ore/Electrum Seam
      -- Open, Rawl'kha/Stormhold/Wayrest/...
      -- Pickpocket, Gellsoane
      -- Search, Bookshelf
      -- Search, Great Bear
      -- Search, Heavy Sack/Trunk
      -- Take, Butterfly/Dragonfly/Torchbug
      -- Talk, Mirri Elendis
      -- Use, Blueblood Wayshrine
      -- Use, Alchemy Station/Cooking Fire
      -- Use, Skyshard
      -- Use, Chest/Hidden Treasure

      local wait = 0

      if action == "Dig" and name == "Dirt Mound" then
        if addon.Companions[SHARP].introdone then
          addon.summonCompanion (SHARP, wait)
        else
          addon.summonCompanion (MIRRI, wait)
        end
      elseif action == "Loot" and name == "Psijic Portal" then
        addon.summonCompanion (BASTIAN, wait)
      elseif action == "Open" and name:match (' Refuge$') and GetActiveCompanionDefId() == ISOBEL then
        -- unsummon straight away
        -- we could summon Ember instead if she is available
        UseCollectible (addon.Companions[ISOBEL].id)
      elseif action == "Steal From" and (name == "Thieves Trove" or name == "Safebox") then
        addon.summonCompanion (MIRRI, wait)
      elseif action == "Take" and GetActiveCompanionDefId() == MIRRI and
        (name == "Butterfly" or name == "Torchbug" or name == "Worker Bee") then
        EndPendingInteraction()
        addon.lastinteraction = {}
        return true
      elseif action == "Unlock" and name == "Chest" then
        addon.summonCompanion (MIRRI, wait)
      else
        -- d("interaction: "..tostring(frametimeseconds)..": "..
        --   tostring(action)..", "..tostring(name)..", "..tostring(blocked)..", "..
        --   tostring(owned)..", "..tostring(info)..", "..tostring(context)..", "..
        --   tostring(link)..", "..tostring(criminal))
      end
    end
  end)

  SCENE_MANAGER:GetScene("lockpickKeyboard"):RegisterCallback("StateChange",
  function(old, new)
    if (new == SCENE_SHOWN) then
      -- TODO: find out if we can detect chest vs. something else here and move
      -- Mirri summoning, or otherwise just unsummon if it's Bastian
    end
  end)

  SCENE_MANAGER:GetScene("Scrying"):RegisterCallback("StateChange",
  function(old, new)
    if (new == SCENE_SHOWN) then
      addon.summonCompanion (BASTIAN, wait)
    end
  end)

  SCENE_MANAGER:GetScene("antiquityDigging"):RegisterCallback("StateChange",
  function(old, new)
    if (new == SCENE_SHOWN) then
      addon.summonCompanion (MIRRI, wait)
    end
  end)

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
  if addon.Companions[companionid].unlocked and addon.Companions[companionid].introdone
    and companionid ~= GetActiveCompanionDefId() then
    addon.lastcompanion = GetActiveCompanionDefId()
    if HasBlockedCompanion() then
      -- Full group, Cyro/IC, ...
      -- d("|BC| Companion blocked, cannot summon")
    else
      zo_callLater(function()
        UseCollectible (addon.Companions[companionid].id)
      end, wait)
    end
  elseif addon.Companions[companionid].unlocked and not addon.Companions[companionid].introdone then
    if addon.Companions[companionid].nagplayer then
      d(addon.Companions[companionid].name .. " is unlocked but you have not completed their quest")
      addon.Companions[companionid].nagplayer = false
    end
  else
    -- pass
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

EVENT_MANAGER:RegisterForEvent (addon.name, EVENT_END_CRAFTING_STATION_INTERACT,
function(event, station)
  -- 
end)

EVENT_MANAGER:RegisterForEvent (addon.name, EVENT_COMPANION_ACTIVATED,
function()
  local cid = GetActiveCompanionDefId()
  -- d("companion summoned " .. cid)
end)
