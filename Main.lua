Scorpio "SmallBuff" "0.1"

import "System.Reactive"
import "Scorpio.Secure"

local _Cache = {}
local function GetSpellFromCache(id)
  if not _Cache[id] then
    local name, _, icon = GetSpellInfo(id)
    _Cache[id] = { name = name, icon = icon }
  end
  return _Cache[id]
end

interface "ICooldownLike"(function(_ENV)

  local sharedcd = { start = 0, duration = 0 }

  __Abstract__()
  property "Cooldown" { type = Number, get = "GetCooldown" }

  __Abstract__()
  function GetCooldown(self)
    sharedcd.start = self.Start
    sharedcd.duration = self.Duration
    return sharedcd
  end

  __Abstract__()
  property "ID" { type = Number }

  __Abstract__()
  property "Name"  { type = String }

  __Abstract__()
  property "Icon"  { type = String + Number }

  __Abstract__()
  property "Enabled" { default = true }

  __Abstract__()
  property "Count" { default = 1 }
end)

class "Cooldown" (function(_ENV)
  extend "ICooldownLike"

  property "Name"  { get = function(self) return GetSpellFromCache(self.ID).name end }

  property "Icon"  { get = function(self) return GetSpellFromCache(self.ID).icon end }
  
  property "Start" { type = Number }

  property "Duration" { type = Number }

  property "ExpirationTime" { get = function(self) return self.Start + self.Duration end }
end)

class "Aura"(function(_ENV)
  extend "ICooldownLike"

  property "Start" { get = function(self) return self.ExpirationTime - self.Duration end }

  property "Duration" { type = Number }
    
  property "ExpirationTime" { type = Number }
end)

local cacheSubject = Subject()

local BUFFS_CACHE = { }
local DEBUFFS_CACHE = { }
local function RebuildCache(cache, auraFn, unit)
  return function()
    wipe(cache)
    for i = 1, 40 do
      local name, icon, count, buffType, duration, expirationTime, source, _, _, id = auraFn(unit, i)
      if not name then break end

      -- TODO if unit == target and source != player

      if cache[id] then
        cache[id].count = cache[id].count + (count or 1)
      else
        cache[id] = Aura { ID = id, Name = name, Icon = icon, Duration = duration, ExpirationTime = expirationTime, Count = count }
      end
    end
    cacheSubject:OnNext()
  end
end

local shareCooldown = Cooldown()

local function CooldownData(id)
  local start, duration, enabled = GetSpellCooldown(id)
  shareCooldown.ID = id
  shareCooldown.Start = start
  shareCooldown.Duration = duration
  shareCooldown.Enabled = enabled
  shareCooldown.Count = GetSpellCharges(id) or 0

  return shareCooldown
end

function OnLoad()
  local BUILD_PLAYER_CACHE = RebuildCache(BUFFS_CACHE, UnitBuff, "player")
  local BUILD_TARGET_CACHE = RebuildCache(DEBUFFS_CACHE, UnitDebuff, "target")
  Wow.FromEvent("UNIT_AURA"):MatchUnit("player"):Next():Subscribe(BUILD_PLAYER_CACHE)
  Wow.FromEvent("UNIT_AURA"):MatchUnit("target"):Next():Subscribe(BUILD_TARGET_CACHE)
  Wow.FromEvent("PLAYER_TARGET_CHANGED"):Subscribe(BUILD_TARGET_CACHE)

  -- TODO ACTIONBAR_UPDATE_USABLE? SPELL_UPDATE_USABLE? UPDATE_SHAPESHIFT_COOLDOWN?
  Wow.FromEvent(
    "ACTIONBAR_UPDATE_COOLDOWN",
    "ACTIONBAR_UPDATE_STATE",
    "BAG_UPDATE_COOLDOWN",
    "PET_BAR_UPDATE_COOLDOWN",
    "SPELL_UPDATE_COOLDOWN"
  ):Next():Subscribe(cacheSubject)

  BUILD_PLAYER_CACHE()
  BUILD_TARGET_CACHE()
end

class "MixedElementPanelIcon" { Scorpio.Secure.UnitFrame.AuraPanelIcon }

class "MixedElementPanel"(function(_ENV)
  inherit "ElementPanel"

  __Observable__()
  __Indexer__()
  property "Data" { set = Toolset.fakefunc, type = ICooldownLike }

  local function DataFor(id)
    return BUFFS_CACHE[id] or DEBUFFS_CACHE[id] or CooldownData(id)
  end

  function Refresh(self)
    local count = 0
    for i, data in self.IDs:Map(DataFor):GetIterator() do
      self.Data[i] = data
      count = i
    end
    self.Count = count
  end

  property "IDs" { default = function () return List[Number]() end, handler = Refresh }

  function __ctor(self)
    cacheSubject:Subscribe(function () self:Refresh() end)
  end
end)

Style.UpdateSkin("Default", {
  [MixedElementPanel] = {
    elementType = MixedElementPanelIcon,
    elementWidth = 20,
    elementHeight = 20,
    location = { Anchor("CENTER") },
  },

  [MixedElementPanelIcon] = {
    IconTexture = {
      setAllPoints = true,
      file = Wow.FromPanelProperty("Data"):Map("x=>x.Icon"),
    },

    Cooldown = {
      setAllPoints = true,
      enableMouse = false,
      cooldown = Wow.FromPanelProperty("Data"):Map("x=>x.Cooldown")
    },

    Label = {
      location = { Anchor("BOTTOM", 0, -12) },
      text = Wow.FromPanelProperty("Data"):Map("x=>x.Count"):Map("x=>x > 1 and x or ''")
    }
  }
})

SMALLBUFF_PANEL = MixedElementPanel("SmallBuffMain")

__SlashCmd__ "sb" "add"
function AddBuff(id) -- TODO from param
  SMALLBUFF_PANEL.IDs = List[Number]{ 8143, 5394, 108271, 974 }
end
