-- ---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

local Q_BUFF = "XerathArcanopulseChargeUp"
local R_BUFF = "XerathLocusOfPower2"

---@class Empyrean.Xerath.BuffManager
local BuffManager = require("Common.Utils").Class()

function BuffManager:_init()
    self._qActive = false
    self._qStartTime = 0
    self._rActive = false
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnBuffGain, function(...) self:_OnBuffGain(...) end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnBuffLost, function(...) self:_OnBuffLost(...) end)
end

---@param obj SDK_AIBaseClient
---@param buff SDK_BuffInstance
function BuffManager:_OnBuffGain(obj, buff)
    if not obj or not buff then
        return
    end
    if obj:GetNetworkId() ~= myHero:GetNetworkId() then
        return
    end
    if buff:GetName() == Q_BUFF then
        self:_HandleQGain()
        return
    end
    if buff:GetName() == R_BUFF then
        self:_HandleRGain()
        return
    end
end

function BuffManager:_HandleQGain()
    self._qActive = true
    self._qStartTime = SDK.Game:GetTime()
    --Orbwalker:BlockAttack(true)
end

function BuffManager:_HandleRGain()
    self._rActive = true
    --Orbwalker:BlockAttack(true)
    --Orbwalker:BlockMove(true)
end

---@param obj SDK_AIBaseClient
---@param buff SDK_BuffInstance
function BuffManager:_OnBuffLost(obj, buff)
    if not obj or not buff then
        return
    end
    if obj:GetNetworkId() ~= myHero:GetNetworkId() then
        return
    end
    if buff:GetName() == Q_BUFF then
        self:_HandleQLost()
        return
    end
    if buff:GetName() == R_BUFF then
        self:_HandleRLost()
        return
    end
end

function BuffManager:_HandleQLost()
    self._qActive = false
    --Orbwalker:BlockAttack(false)

end

function BuffManager:_HandleRLost()
    self._rActive = false
    --Orbwalker:BlockAttack(false)
    --Orbwalker:BlockMove(false)
end

function BuffManager:IsQActive()
    return self._qActive
end

function BuffManager:IsRActive()
    return self._rActive
end

function BuffManager:GetQStartTime()
    return self._qStartTime
end

return BuffManager
