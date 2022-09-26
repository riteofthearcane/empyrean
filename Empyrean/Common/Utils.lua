local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player


local Utils = {}

function Utils.Class()
    return setmetatable({}, {
        __call = function(self, ...)
            local result = setmetatable({}, {
                __index = self
            })
            result:_init(...)

            return result
        end
    })
end

Utils.COLOR_WHITE = SDK.Libs.Color.GetD3DColor(255, 255, 255, 255)

function Utils.GetClosestEnemyToMouse()
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

function Utils.IsMyHeroDashing()
    return myHero:AsAI():GetPathing():IsDashing()
end

---@param unit SDK_AIHeroClient
---@return boolean
function Utils.IsValidTarget(unit)
    return unit and unit:IsValid() and unit:IsVisible() and
        (unit:IsAttackableUnit() and not unit:AsAttackableUnit():IsDead())
end

return Utils
