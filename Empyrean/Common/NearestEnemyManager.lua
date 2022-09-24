-- ---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@class NearestEnemyManager
local NearestEnemyManager = require("Common.Utils").Class()

local enemies = SDK.ObjectManager:GetEnemyHeroes()

function NearestEnemyManager:_init()
    self.target = nil
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnTick, function() self:_OnTick() end)
end

function NearestEnemyManager.GetClosestEnemyToMouse()
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

function NearestEnemyManager:_OnTick()
    self.target = self.GetClosestEnemyToMouse()
end

function NearestEnemyManager:IsTarget(enemy)
    if not self.target then
        return false
    end
    return enemy:GetNetworkId() == self.target:GetNetworkId()
end

return NearestEnemyManager
