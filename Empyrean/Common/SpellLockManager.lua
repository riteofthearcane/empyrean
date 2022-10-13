-- ---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

---@class Empyrean.Common.SpellLockManager
local SpellLockManager = require("Common.Utils").Class()

local DELAY_BUFFER = 0.05

function SpellLockManager:_init(spellTable)
    self:_InitTables(spellTable)
    self:_InitEvents()
end

function SpellLockManager:_InitTables(spellTable)
    self._invokes = {}
    self._invokesLen = 0
    self.delayLookup = {}
    if not spellTable then return end
    for spell, delay in pairs(spellTable) do self.delayLookup[spell] = delay end
end

function SpellLockManager:_InitEvents()
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnUpdate, function() self:_OnUpdate() end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnProcessSpell, function(...) self:_OnProcessSpell(...) end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnCastSpell, function(...) self:_OnCastSpell(...) end)
end

function SpellLockManager:_OnCastSpell(args)
    if not args.Process then return end
    if not myHero:CanUseSpell(args.Slot) then return end
    local name = myHero:GetSpell(args.Slot):GetName()
    if not self._invokes[name] then self._invokesLen = self._invokesLen + 1 end
    local delay = self.delayLookup[name] or 0
    if name == "SyndraW" then
        SDK.PrintChat("SPELLLOCKMANAGER: Syndra W cast")
    end
    self._invokes[name] = SDK.Game:GetTime() + SDK.Game:GetLatency() / 1000 + DELAY_BUFFER + delay
end

function SpellLockManager:_OnProcessSpell(obj, cast)
    if obj:GetNetworkId() ~= myHero:GetNetworkId() then
        return
    end

    if not self._invokes[cast:GetName()] then self._invokesLen = self._invokesLen + 1 end
    self._invokes[cast:GetName()] = SDK.Game:GetTime() + cast:GetCastDelay() + DELAY_BUFFER
end

function SpellLockManager:_OnUpdate()
    for spell, time in pairs(self._invokes) do
        if time < SDK.Game:GetTime() then
            self._invokes[spell] = nil
            self._invokesLen = self._invokesLen - 1
        end
    end
end

---@return boolean
---@param slot number
function SpellLockManager:ShouldCastSpell(slot)
    return self._invokes[myHero:GetSpell(slot):GetName()] == nil
end

---@return boolean
function SpellLockManager:ShouldCast()
    return self._invokesLen == 0
end

return SpellLockManager
