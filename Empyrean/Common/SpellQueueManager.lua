-- ---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

---@class SpellQueueManager
local SpellQueueManager = require("Common.Utils").Class()

local IDLE = 0
local UNVERIFIED = 1
local VERIFIED = 2

--- Key: spell (or whatever the developer chooses to call the spell)
--- Value: {name = spell name in OnProcessSpell, delay = delay of lockout}
---@param spellsData table
function SpellQueueManager:_init(spellsData)
    self:_InitTables(spellsData)
    self:_InitEvents()
end

function SpellQueueManager:_InitTables(spellsData)
    self._invokes = {}
    self._spellLookupTable = {}
    for spell in pairs(spellsData) do
        self:_SetIdle(spell)
        self._spellLookupTable[spellsData[spell].name] = {
            spell = spell,
            delay = spellsData[spell].delay
        }
    end
end

function SpellQueueManager:_InitEvents()
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnTick, function() self:_OnTick() end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnProcessSpell, function(...) self:_OnProcessSpell(...) end)
end

function SpellQueueManager:_OnProcessSpell(obj, cast)
    if obj:GetNetworkId() ~= myHero:GetNetworkId() then
        return
    end
    if not self._spellLookupTable[cast:GetName()] then
        return
    end
    local spell = self._spellLookupTable[cast:GetName()].spell
    local delay = self._spellLookupTable[cast:GetName()].delay
    self._invokes[spell] = {
        status = VERIFIED,
        verifyDeadline = 0,
        expireTime = SDK.Game.GetTime() + delay
    }
    -- TODO: check if verification of manual casts becomes an issue
end

function SpellQueueManager:_OnTick()
    for spell in pairs(self._invokes) do
        local status = self._invokes[spell].status
        local verifyDeadline = self._invokes[spell].verifyDeadline
        local expireTime = self._invokes[spell].expireTime
        if status == UNVERIFIED and SDK.Game:GetTime() > verifyDeadline then
            print(spell .. " was never casted.")
            self:_SetIdle(spell)
        elseif status == VERIFIED and SDK.Game.GetTime() > expireTime then
            -- print(spell .. " expired and set idle.")
            self:_SetIdle(spell)
        end
    end
end

function SpellQueueManager:_SetIdle(spell)
    self._invokes[spell] = {
        status = IDLE,
        verifyDeadline = 0,
        expireTime = 0
    }
end

function SpellQueueManager:_GetVerificationDeadline()
    return SDK.Game:GetTime() + SDK.Game:GetLatency() / 1000 + 0.1
end

function SpellQueueManager:InvokeCastSpell(spell)
    if not self._invokes[spell] then
        print("Unrecognized spell " .. spell .. " when calling InvokeCastSpell")
        return
    end
    if not self:ShouldCastSpell(spell) then
        print(spell .. " needs to be idle when calling InvokeCastSpell")
        return
    end
    self._invokes[spell] = {
        status = UNVERIFIED,
        verifyDeadline = self:_GetVerificationDeadline(),
        expireTime = 0
    }
end

function SpellQueueManager:ShouldCastSpell(spell)
    if not self._invokes[spell] then
        print("Unrecognized spell " .. spell .. " when checking ShouldCastSpell")
        return
    end
    return self._invokes[spell].status == IDLE
end

function SpellQueueManager:ShouldCast()
    for spell in pairs(self._invokes) do
        if self._invokes[spell].status ~= IDLE then
            return false
        end
    end
    return true
end

return SpellQueueManager
