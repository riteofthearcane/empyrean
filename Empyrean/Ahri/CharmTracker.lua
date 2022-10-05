-- ---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

local Utils = require("Common.Utils")

---@class Empyrean.Ahri.CharmTracker
local CharmTracker = Utils.Class()

function CharmTracker:_init()
    self.targets = {}
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnBuffGain, function(...) self:_OnBuffGain(...) end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnBuffLost, function(...) self:_OnBuffLost(...) end)
end

---@param obj SDK_AIBaseClient
---@param buff SDK_BuffInstance
function CharmTracker:_OnBuffGain(obj, buff)
    if not obj or not buff then
        return
    end
    if obj:GetTeam() == myHero:GetTeam() or not obj:IsHero() then
        return
    end
    if buff:GetType() ~= BuffType.Charm then
        return
    end
    self.targets[obj:GetNetworkId()] = true
end

---@param obj SDK_AIBaseClient
---@param buff SDK_BuffInstance
function CharmTracker:_OnBuffLost(obj, buff)
    if obj:GetTeam() == myHero:GetTeam() or not obj:IsHero() then
        return
    end
    if buff:GetType() ~= BuffType.Charm then
        return
    end
    self.targets[obj:GetNetworkId()] = nil
end

---@return SDK_AIHeroClient
function CharmTracker:GetClosestValidTarget()
    local res, resDist = nil, nil
    local pos = myHero:GetPosition()
    for networkId in pairs(self.targets) do
        local obj = SDK.ObjectManager:GetObjectFromNetworkId(networkId)
        local dist = pos:Distance(obj:GetPosition())
        if Utils.IsValidTarget(obj) and (resDist == nil or resDist < dist) then
            res, resDist = obj, resDist
        end
    end
    return res
end

function CharmTracker:IsCharm(unit)
    local networkId = unit:GetNetworkId()
    return self.targets[networkId] and true or false
end

return CharmTracker
