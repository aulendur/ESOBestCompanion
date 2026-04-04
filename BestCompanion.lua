-- vim: set et ts=2 sw=2 sts=2 tw=79 cc=80 list listchars=trail\:�:
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

function addon.loadShalidorBooks()
  -- /script d(tostring(GetLoreBookIndicesFromBookId(0))) -- 0, 1, 10, 100 => nil, nil, nil, 3
  -- /script for i = 0, 20 do local name, num, cid = GetLoreCategoryInfo(i); if name then d(tostring(i, name, num, cid)); end; end
  -- Shalidor's library is i=1
  -- /script local n = 0; for i = 0, 6000 do local cat, coll, idx = GetLoreBookIndicesFromBookId(i); if cat == 1 then local title, _, _, id = GetLoreBookInfo (cat, coll, idx); d(i.."/"..id.." : "..title); n = n + 1; end; end; d("Total Shalidor books: "..n) -- total 297, highest id = 2293 Joseph the Intolerant
  for i = 0, 6339 do -- 6339 books listed in Lore Library tab as of U44
    local cat, coll, idx = GetLoreBookIndicesFromBookId(i)
    if cat == 1 then
      local title, _, _, id = GetLoreBookInfo (cat, coll, idx)
      assert (i==id, "BC: Mismatch between Shalidor book i and id")
      addon.ShalidorBooks[title] = id
    end
  end
end

function addon.Initialize()
  addon.player_activated = 0
  addon.Companions = {}
  addon.IntroQuests = {}
  addon.ShalidorBooks = {}
  addon.loadShalidorBooks()
  addon.earlylog = ""
  addon.maximumrapport = GetMaximumRapport()

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
        introdone = (introname ~= "" and true or false), active = active, nagplayer = true, rapport = 0 }
      -- /script for i = 1,20 do n,_ = GetQuestName(GetCompanionIntroQuestId(i)); if n~="" then d(i.." questname="..n); end; end
      local questname = GetQuestName (qid)
      if questname ~= "" then
        addon.IntroQuests[questname] = i
      end
    end
  end

  -- https://github.com/esoui/esoui/blob/c357b8171a6dabecd259a6d74dd3e96036f89a43/esoui/libraries/utility/zo_savedvars.lua#L11
  -- SV_TableName, SV_Version, SV_SubTable/namespace, SV_Defaults, SV_Profile, SV_DisplayName
  -- SV_Profile can be used to distinguish between realms (but also SV_SubTable)
  -- SV_DisplayName = @accountname by default, use fixed string for cross-account settings
  -- Possible to pass in per-account settings for per-character SV_Defaults
  -- local charSettings = ZO_SavedVars:NewCharacterId("BC_SVars", 1, "Settings", defaults, worldName)
  -- local accSettings = ZO_SavedVars:NewAccountWide("BC_SVars", 1, "Settings", defaults, worldName, nil)

  local worldName = GetWorldName()
  local charId = GetCurrentCharacterId()
  addon.SV = ZO_SavedVars:NewAccountWide("BC_SVars", 1, "Settings", {companionRapport={}}, worldName, nil)
  addon.SV.companionRapport[charId] = addon.SV.companionRapport[charId] or {}
  for id, comp in pairs(addon.Companions) do
    addon.SV.companionRapport[charId]["name"] = GetUnitName("player")
    if addon.SV.companionRapport[charId][id] ~= nil then
      -- addon.earlylog = addon.earlylog .. "|BC| Loaded saved rapport for "..comp.name..": "..tostring(addon.SV.companionRapport[charId][id]) .. "\n"
    end
    comp.rapport = addon.SV.companionRapport[charId][id] or comp.rapport or 0
  end

  addon.lastinteraction = {}
  addon.lastcompanion = false
  addon.unsummon = false
  ZO_PreHook(RETICLE, "TryHandlingInteraction", function(event, possible, frametimeseconds)
    local action, name, blocked, owned, info, context, link, criminal =
      GetGameCameraInteractableActionInfo()

    if HasPendingCompanion() then
      local pendingid = GetPendingCompanionDefId()
      --d("|BC| PendingCompanionDefId="..pendingid)
      if pendingid and pendingid == addon.getDesiredCompanionForInteraction (action, name) then
        EndPendingInteraction()
        addon.lastinteraction = {}
        return true
      end
    end

    if possible and action and 
      (action ~= addon.lastinteraction["action"] or name ~= addon.lastinteraction["name"]) then
      addon.lastinteraction = { action=action, name=name }
      -- Collect, Runestone
      -- Collect, Blessed Thistle/Bugloss/Columbine/Corn Flower/Mountain Flower
      --   /Nightshade/Nirnroot/Water Hyacinth/Wormwood
      -- Collect, Pure Water
      -- Collect, Ebon Thread/Spidersilk
      -- Cut, Hickory/Yew
      -- Enter, Snugpod/...
      -- Examine, The Feast of Saint Coellicia IV
      -- Excavate, Dig Site
      -- Fish, Lake Fishing Hole
      -- Mine, Copper Seam/Dwarven Ore/Ebony Ore/Electrum Seam
      -- Open, Rawl'kha/Stormhold/Wayrest/...
      -- Pickpocket, Gellsoane
      -- Search, Bookshelf
      -- Search, Great Bear
      -- Search, Heavy Sack/Trunk
      -- Talk, Mirri Elendis
      -- Use, Blueblood Wayshrine
      -- Use, Alchemy Station/Cooking Fire

      if addon.handleInteraction (action, name) then
        return true
      end

      -- if action == "Steal From"
      -- and (name == "Thieves Trove" or name == "Safebox") and IsPlayerMoving() then
      --  addon.lastinteraction = {}
      -- end
      -- if action == "Take" and GetActiveCompanionDefId() == MIRRI and
      --    (name == "Butterfly" or name == "Torchbug" or name == "Worker Bee") then
      --   EndPendingInteraction()
      --   addon.lastinteraction = {}
      --   return true
      -- end

      -- debug if no action taken
        -- d("interaction: "..tostring(frametimeseconds)..": "..
        --   tostring(action)..", "..tostring(name)..", "..tostring(blocked)..", "..
        --   tostring(owned)..", "..tostring(info)..", "..tostring(context)..", "..
        --   tostring(link)..", "..tostring(criminal))
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
      addon.summonCompanion (BASTIAN)
    end
  end)

  SCENE_MANAGER:GetScene("antiquityDigging"):RegisterCallback("StateChange",
  function(old, new)
    if (new == SCENE_SHOWN) then
      addon.summonCompanion (MIRRI)
    end
  end)

  SCENE_MANAGER:GetScene("scribingKeyboard"):RegisterCallback("StateChange",
  function(old, new)
    if (new == SCENE_SHOWN) then
      addon.summonCompanion (TANLORIN)
    end
  end)

  addon.lastsummon = GetGameTimeMilliseconds()
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
  if addon.player_activated == 1 and addon.earlylog and addon.earlylog ~= "" then
    d(addon.earlylog)
  end
  addon.updateCompanionRapport()
end)

ZO_PreHook("UseCollectible", function(newCollectibleId)
  -- we could check if the id is one of addon.Companions[].id, but that is probably more expensive than just updating
  -- this actually fires when the new companion is appearing...?!!
  addon.updateCompanionRapport()
end)

function addon.updateCompanionRapport()
  local cid = GetActiveCompanionDefId()
  if addon.Companions[cid] ~= nil then
    local rapport = GetActiveCompanionRapport()
    addon.Companions[cid].rapport = rapport
    local charId = GetCurrentCharacterId()
    addon.SV.companionRapport[charId] = addon.SV.companionRapport[charId] or {}
    addon.SV.companionRapport[charId][cid] = rapport
    d("|BC| "..addon.Companions[cid].name.." current rapport: "..tostring(rapport))
  end
end

function addon.summonCompanion (companionid)
  if HasBlockedCompanion() or DoesCurrentZoneHaveTelvarStoneBehavior() or IsInCyrodiil() then
    -- d("|BC| Companion blocked, cannot summon")
    return false
  end

  if HasPendingCompanion() then
    -- d("|BC| Companion pending, cancelling interaction")
    EndPendingInteraction()
    addon.lastinteraction = {}
    return true
  end

  if (GetGameTimeMilliseconds() - addon.lastsummon) < 6000 then
    return false
  end

  if not addon.Companions[companionid].unlocked then return false end
  if not addon.Companions[companionid].introdone then
    if addon.Companions[companionid].nagplayer then
      d(addon.Companions[companionid].name .. " is unlocked but you have not completed their quest")
      addon.Companions[companionid].nagplayer = false
    end
    return false
  end
  if companionid == GetActiveCompanionDefId() then return false end

  local charId = GetCurrentCharacterId()
  local rapport = addon.SV.companionRapport[charId][companionid] or 0
  if rapport >= addon.maximumrapport then
    d("|BC| "..addon.Companions[companionid].name.." has maximum rapport, no need to summon")
    return false
  end

  -- all clear: cancel and clear the current interaction and summon the new companion
  addon.lastcompanion = GetActiveCompanionDefId()
  addon.updateCompanionRapport()
  addon.lastsummon = GetGameTimeMilliseconds()
  UseCollectible (addon.Companions[companionid].id)
  EndPendingInteraction()
  addon.lastinteraction = {}
  return true
end

function addon.getDesiredCompanionForInteraction(action, name)
  if not action or not name then return nil end

  addon.unsummon = false
  if action == "Dig" and name == "Dirt Mound" then
    if addon.Companions[SHARP].introdone then return SHARP else return MIRRI end
  end
  if action == "Examine" and name == "Alchemist Delivery Crate" then return TANLORIN end
  if action == "Examine" and name == "Enchanter Delivery Crate" then return AZANDAR end
  if action == "Loot" and name == "Psijic Portal" then return BASTIAN end
  if action == "Open" and name:match ("^Mages Guild") and addon.Companions[BASTIAN].introdone then return BASTIAN end
  if action == "Open" and name:match (' Refuge$') and addon.Companions[EMBER].introdone then return EMBER end
  -- if action=open?? and player IsInOutlawZone() and last companion was Isobel then resummon after exit
  if action == "Steal From" and (name == "Thieves Trove" or name == "Safebox") and not IsPlayerMoving() then return MIRRI end
  if action == "Take" and (name:match ('^Affix Script: ') or name:match ('^Focus Script: ') or name:match ('^Signature Script: ')) then return TANLORIN end
  if action == "Talk" and name == "Lyris Titanborn" then return ISOBEL end
  if action == "Unlock" and name == "Chest" and not IsUnitInAir ("player") then
    if addon.Companions[MIRRI].introdone then return MIRRI else return TANLORIN end
  end
  if action == "Use" and (name == "Chest" or name == "Hidden Treasure") and not IsUnitInAir ("player") then return MIRRI end
  if action == "Use" and name == "Skyshard" then return TANLORIN end
  -- unsummon interaction list
  addon.unsummon = true
  if action == "Collect" and (name == "Emetic Russula" or name == "Luminous Russula" or name == "Namira's Rot") and
     GetActiveCompanionDefId() == AZANDAR then return AZANDAR end
  if action == "Collect" and name == "Nirnroot" and GetActiveCompanionDefId() == TANLORIN then return TANLORIN end
  if action == "Examine" and addon.ShalidorBooks[name] ~= nil and GetActiveCompanionDefId() == TANLORIN then return TANLORIN end
  if action == "Open" and name:match ("^Mages Guild") and GetActiveCompanionDefId() == TANLORIN then return TANLORIN end
  if action == "Open" and name:match (' Refuge$') and GetActiveCompanionDefId() == ISOBEL then return ISOBEL end
  if action == "Travel" and name:match ('^Boat ') and GetActiveCompanionDefId() == MIRRI then return MIRRI end
  if action == "Take" and GetActiveCompanionDefId() == MIRRI and (name == "Butterfly" or name == "Torchbug" or name == "Worker Bee") then return MIRRI end

  return nil
end

function addon.handleInteraction(action, name)
  local desired = addon.getDesiredCompanionForInteraction(action, name)
  if not desired then return false end

  if addon.unsummon and GetActiveCompanionDefId() == desired then
    UseCollectible (addon.Companions[desired].id)
    return true
  else
    return addon.summonCompanion(desired)
  end
end

EVENT_MANAGER:RegisterForEvent (addon.name, EVENT_CRAFTING_STATION_INTERACT,
function(event, station)
  -- TODO: save active companion and resummon after crafting
  if GetCraftingInteractionType() == CRAFTING_TYPE_ALCHEMY then
    addon.summonCompanion (SHARP)
  elseif GetCraftingInteractionType() == CRAFTING_TYPE_BLACKSMITHING then
    addon.summonCompanion (ISOBEL)
  elseif GetCraftingInteractionType() == CRAFTING_TYPE_PROVISIONING then
    addon.summonCompanion (MIRRI)
  end
end)

EVENT_MANAGER:RegisterForEvent (addon.name, EVENT_END_CRAFTING_STATION_INTERACT,
function(event, station)
  -- 
end)

EVENT_MANAGER:RegisterForEvent (addon.name, EVENT_COMPANION_ACTIVATED,
function()
  addon.updateCompanionRapport()
end)

EVENT_MANAGER:RegisterForEvent (addon.name, EVENT_COMPANION_RAPPORT_UPDATE,
function()
  addon.updateCompanionRapport()
end)

EVENT_MANAGER:RegisterForEvent (addon.name, EVENT_QUEST_COMPLETE,
function(event, questname, _, _, _, _, questtype, displaytype)
  -- d("finished quest "..questname..", type "..tostring(questtype)..", display "..tostring(displaytype))
  -- d("finished quest '"..questname.."' is companionintro: "..tostring(addon.IntroQuests[questname]~=nil))
  id = addon.IntroQuests[questname]
  if id ~= nil then
    addon.Companions[id].introdone = true
    addon.Companions[id].nagplayer = false
    d("Congratulations, completed intro for "..addon.Companions[id].name)
  end
end)
