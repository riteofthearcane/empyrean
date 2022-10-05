-- ---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

local Utils = require("Common.Utils")

local Q_BUFF = "XerathArcanopulseChargeUp"
local R_BUFF = "XerathLocusOfPower2"

---@class Empyrean.Xerath.BuffManager
local BuffManager = Utils.Class()

function BuffManager:_init()
    self.qActive = false
    self.qStartTime = 0
    self.rActive = false
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnBuffGain, function(...) self:_OnBuffGain(...) end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnBuffLost, function(...) self:_OnBuffLost(...) end)
end

---@param obj SDK_AIBaseClient
---@param buff SDK_BuffInstance
function BuffManager:_OnBuffGain(obj, buff)
    if not obj or not buff then
        return
    end
    if not obj:GetNetworkId() ~= myHero:GetNetworkId() then
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
    self.qActive = true
    self.qStartTime = SDK.Game:GetTime()
    --Orbwalker:BlockAttack(true)
end

function BuffManager:_HandleRGain()
    self.rActive = true
    --Orbwalker:BlockAttack(true)
    --Orbwalker:BlockMove(true)
end

---@param obj SDK_AIBaseClient
---@param buff SDK_BuffInstance
function BuffManager:_OnBuffLost(obj, buff)
    if not obj or not buff then
        return
    end
    if not obj:GetNetworkId() ~= myHero:GetNetworkId() then
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
    self.qActive = false
    --Orbwalker:BlockAttack(false)

end

function BuffManager:_HandleRLost()
    self.rActive = false
    --Orbwalker:BlockAttack(false)
    --Orbwalker:BlockMove(false)
end

function BuffManager:IsQActive()
    return self.qActive
end

function BuffManager:IsRActive()
    return self.rActive
end

function BuffManager:GetQStartTime()
    return self.qStartTime
end

return BuffManager
