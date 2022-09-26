-- ---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@class NearestEnemyTracker
local NearestEnemyTracker = require("Common.Utils").Class()

local enemies = SDK.ObjectManager:GetEnemyHeroes()

function NearestEnemyTracker:_init()
    self.target = nil
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnTick, function() self:_OnTick() end)
end

function NearestEnemyTracker.GetClosestEnemyToMouse()
    local mousePos = SDK.Renderer:GetMousePos3D()
    local closestDistSqr = nil
    local closestEnemy = nil
    for _, enemy in pairs(enemies) do
        local isEnemyValid = enemy:IsValid() and enemy:IsVisible() and not enemy:IsDead()
        local distSqr = mousePos:Distance(enemy:GetPosition())
        if isEnemyValid and (closestDistSqr == nil or distSqr < closestDistSqr) then
            closestDistSqr, closestEnemy = distSqr, enemy
        end
    end
    return closestEnemy
end

function NearestEnemyTracker:_OnTick()
    self.target = nil
    local obj = NearestEnemyTracker.GetClosestEnemyToMouse()
    if obj then
        self.target = obj:GetNetworkId()
    end
end

function NearestEnemyTracker:IsTarget(enemy)
    if not self.target then
        return false
    end
    return enemy:GetNetworkId() == self.target
end

return NearestEnemyTracker
