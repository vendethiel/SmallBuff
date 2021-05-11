Scorpio "SmallBuff" "0.1"

import "System.Reactive"
import "Scorpio.Secure"

local cacheSubject = Subject()

local BUFFS_CACHE = { player = {}, target = {} }
local function RebuildCache(unit)
  local cache = BUFFS_CACHE[unit]
  wipe(cache)
  for i = 1, 40 do -- Can stop after 40, but doesn't matter
    local name, icon, count, buffType, duration, expirationTime, source, _, _, id = UnitAura(unit, i)
    if not name then break end

    -- TODO if unit == target and source != player

    print('id'..id)
    if cache[id] then
      cache[id].count = cache[id].count + (count or 1)
    else
      cache[id] = { id = id, name = name, icon = icon, duration = duration, expirationTime = expirationTime, count = count or 1 }
    end
  end
  cacheSubject:OnNext()
end

function OnLoad()
  Wow.FromEvent("UNIT_AURA"):MatchUnit("player"):Next():Subscribe(RebuildCache)
  Wow.FromEvent("UNIT_AURA"):MatchUnit("target"):Next():Subscribe(RebuildCache)
  Wow.FromEvent("PLAYER_TARGET_CHANGED"):Subscribe(function () RebuildCache('target') end)

  RebuildCache("player")
  RebuildCache("target")
end

class "MixedElementPanelIcon" { Scorpio.Secure.UnitFrame.AuraPanelIcon }

__Sealed__()
class "MixedElementPanel"(function(_ENV)
  inherit "ElementPanel"

  __Observable__()
  __Indexer__()
  property "IconCooldown" { set = Toolset.fakefunc }

  __Observable__()
  __Indexer__()
  property "IconImage" { set = Toolset.fakefunc }

  __Observable__()
  __Indexer__()
  property "AuraIndex" { set = Toolset.fakefunc }

  function Refresh(self)
    local count = 0
    for i, buff in List(self.IDs):Map(function (id) print('[]'..id); return BUFFS_CACHE['player'][id] or BUFFS_CACHE['target'][id] end):Filter("x=>x"):GetIterator() do
    print('lol'..buff.id .. ' = ' .. buff.icon)
      self.IconCooldown[i] = CooldownStatus(buff.expirationTime - buff.duration, buff.duration)
      self.IconImage[i] = buff.icon
      self.AuraIndex[i] = i
      count = i
    end
    self.Count = count
  end

  field { __IDs = List, default = List{} }
  property "IDs" {
    type = List,
    get = function (self) return self.__IDs or List() end,
    set = function (self, value)
      self.__IDs = value
      self:Refresh()
      -- TODO unbind previous observable +
      -- TODO Observable.Merge(Observable.From(list.OnAdd), Observable.From(list.OnRemove))
    end
  }

  function __ctor(self)
    cacheSubject:Subscribe(function () self:Refresh() end)
  end
end)

Style.UpdateSkin("Default", {
  [MixedElementPanel] = {
    elementType = MixedElementPanelIcon,
    location = { Anchor("CENTER") },
  },

  [MixedElementPanelIcon] = {
    IconTexture = {
      file = Wow.FromPanelProperty("IconImage"),
    },
    Cooldown = {
      setAllPoints = true,
      enableMouse = false,
      cooldown = Wow.FromPanelProperty("IconCooldown")
    }
  }
})

SMALLBUFF_PANEL = MixedElementPanel("SmallBuffMain")
__SlashCmd__ "sb" "add"
function AddBuff(id)
  print('[id] ' .. id)
  SMALLBUFF_PANEL.IDs = List[Number]{ 774 } -- Rejuv
end
