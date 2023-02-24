-- ---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

local Q_BUFF = "xeratharcanopulsechargeUp"
local R_BUFF = "xerathlocusofpower2"
local ModernUOL = require("ModernUOL")


---@class Empyrean.Xerath.BuffManager
local BuffManager = require("Common.Utils").Class()

function BuffManager:_init()
    self._qActive = false
    self._qStartTime = 0
    self._rActive = false
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnUpdate, function(...) self:_OnUpdate(...) end)
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

function BuffManager:_OnUpdate()
    local qBuff = myHero:AsAI():GetBuff(Q_BUFF)
    local rBuff = myHero:AsAI():GetBuff(R_BUFF)
    local hasQBuff = qBuff ~= nil
    local hasRBuff = rBuff ~= nil
    if hasQBuff ~= self._qActive then
        if hasQBuff then
            self:_HandleQGain()
        else
            self:_HandleQLost()
        end
    end
    if hasRBuff ~= self._rActive then
        if hasRBuff then
            self:_HandleRGain()
        else
            self:_HandleRLost()
        end
    end
end

function BuffManager:_HandleQGain()
    self._qActive = true
    self._qStartTime = SDK.Game:GetTime()
    if SDK.GetPlatform() == "FF15" then
        ModernUOL:BlockAttack(true)
    end
end

function BuffManager:_HandleRGain()
    self._rActive = true
    if SDK.GetPlatform() == "FF15" then
        ModernUOL:BlockAttack(true)
        ModernUOL:BlockMove(true)
    end
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
    if SDK.GetPlatform() == "FF15" then
        ModernUOL:BlockAttack(false)
    end
end

function BuffManager:_HandleRLost()
    self._rActive = false
    if SDK.GetPlatform() == "FF15" then
        ModernUOL:BlockAttack(false)
        ModernUOL:BlockMove(false)
    end
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
