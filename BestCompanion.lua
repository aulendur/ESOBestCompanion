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
      -- /script for i = 1,20 do n,_ = GetQuestName(GetCompanionIntroQuestId(i)); if n~="" then d(i.." questname="..n); end; end
      local questname = GetQuestName (qid)
      if questname ~= "" then
        addon.IntroQuests[questname] = i
      end
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

      local wait = 0

      if action == "Collect" and name == "Nirnroot" and GetActiveCompanionDefId() == TANLORIN then
        UseCollectible (addon.Companions[TANLORIN].id)
      elseif action == "Dig" and name == "Dirt Mound" then
        if addon.Companions[SHARP].introdone then
          addon.summonCompanion (SHARP, wait)
          return addon.PauseInteraction{SHARP}
        else
          addon.summonCompanion (MIRRI, wait)
          return addon.PauseInteraction{MIRRI}
        end
      elseif action == "Examine" and name == "Alchemist Delivery Crate" then
        addon.summonCompanion (TANLORIN, wait)
        return addon.PauseInteraction{TANLORIN}
      elseif action == "Examine" and GetActiveCompanionDefId() == TANLORIN and
             addon.ShalidorBooks[name] ~= nil then
        UseCollectible (addon.Companions[TANLORIN].id)
      elseif action == "Loot" and name == "Psijic Portal" then
        addon.summonCompanion (BASTIAN, wait)
      elseif action == "Open" then
        if name:match ("Mages Guild Hall") then
          if addon.Companions[BASTIAN].introdone then
            addon.summonCompanion (BASTIAN)
          elseif GetActiveCompanionDefId() == TANLORIN then
            UseCollectible (addon.Companions[TANLORIN].id)
          end
        elseif name:match (' Refuge$') and GetActiveCompanionDefId() == ISOBEL then
          -- unsummon straight away
          -- we could summon Ember instead if she is available
          UseCollectible (addon.Companions[ISOBEL].id)
        end
      elseif action == "Steal From" and (name == "Thieves Trove" or name == "Safebox") then
        if not IsPlayerMoving() then
          addon.summonCompanion (MIRRI, wait)
        else
          addon.lastinteraction = {}
        end
      elseif action == "Take" then
        if GetActiveCompanionDefId() == MIRRI and
           (name == "Butterfly" or name == "Torchbug" or name == "Worker Bee") then
          EndPendingInteraction()
          addon.lastinteraction = {}
          return true
        elseif name:match ('^Affix Script: ') or name:match ('^Focus Script: ') or
               name:match ('^Signature Script: ') then
          addon.summonCompanion (TANLORIN, wait)
          return addon.PauseInteraction{TANLORIN}
        end
      elseif action == "Unlock" and name == "Chest" and not IsUnitInAir ("player") then
        addon.summonCompanion (MIRRI, wait)
      elseif action == "Use" and (name == "Chest" or name == "Hidden Treasure") and not IsUnitInAir ("player") then
        addon.summonCompanion (MIRRI, wait)
        return addon.PauseInteraction{MIRRI}
      elseif action == "Use" and name == "Skyshard" then
        addon.summonCompanion (TANLORIN, wait)
        return addon.PauseInteraction{TANLORIN}
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

  SCENE_MANAGER:GetScene("scribingKeyboard"):RegisterCallback("StateChange",
  function(old, new)
    if (new == SCENE_SHOWN) then
      addon.summonCompanion (TANLORIN, wait)
    end
  end)

  addon.init_done = "Hello Nirn!"
  addon.lastsummon = GetGameTimeMilliseconds()
end

function addon.PauseInteraction (t)
  setmetatable (t,{__index={interaction={}}})
  local companion, interaction = t[1] or t.companion, t[2] or t.interaction
  if not HasBlockedCompanion() and not DoesCurrentZoneHaveTelvarStoneBehavior() and not IsInCyrodiil() then
    if addon.Companions[companion].introdone and GetActiveCompanionDefId() ~= companion then
      --d("Waiting for "..companion..", pausing interaction '"..addon.prettyprint(interaction).."'")
      EndPendingInteraction()
      addon.lastinteraction = interaction
      return true
    end
  else
    --d("|BC| Companion blocked, cannot summon")
  end
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
  if (GetGameTimeMilliseconds() - addon.lastsummon) < 6000 then
    -- don't do anything if we attempted a summon in the last five seconds
  elseif addon.Companions[companionid].unlocked and addon.Companions[companionid].introdone
    and companionid ~= GetActiveCompanionDefId() then
    addon.lastcompanion = GetActiveCompanionDefId()
    if HasBlockedCompanion() then
      -- Full group, Cyro/IC, ...
      -- d("|BC| Companion blocked, cannot summon")
    elseif HasPendingCompanion() then
      -- summon in progress, do nothing
    else
      -- all clear, try a summon
      addon.lastsummon = GetGameTimeMilliseconds()
      zo_callLater(function()
        UseCollectible (addon.Companions[companionid].id)
      end, wait)
      return true
    end
  elseif addon.Companions[companionid].unlocked and not addon.Companions[companionid].introdone then
    if addon.Companions[companionid].nagplayer then
      d(addon.Companions[companionid].name .. " is unlocked but you have not completed their quest")
      addon.Companions[companionid].nagplayer = false
    end
  else
    -- pass
  end
  return false
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
