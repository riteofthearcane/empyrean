local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

local Vector = SDK.Libs.Vector

local DreamLoader = require("Common.DreamLoader")
local Prediction = DreamLoader.Api.Prediction

local ITEM_SLOTS =
{
    SDK.Enums.SpellSlot.Item1,
    SDK.Enums.SpellSlot.Item2,
    SDK.Enums.SpellSlot.Item3,
    SDK.Enums.SpellSlot.Item4,
    SDK.Enums.SpellSlot.Item5,
    SDK.Enums.SpellSlot.Item6,
    SDK.Enums.SpellSlot.Trinket,
}

local SUMMONER_SLOTS = {
    SDK.Enums.SpellSlot.Summoner1,
    SDK.Enums.SpellSlot.Summoner2
}

local FLASH_DIST = 400

local enemies = SDK.ObjectManager:GetEnemyHeroes()

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
Utils.COLOR_RED = SDK.Libs.Color.GetD3DColor(255, 255, 0, 0)
Utils.COLOR_GREEN = SDK.Libs.Color.GetD3DColor(255, 0, 255, 0)
Utils.COLOR_BLUE = SDK.Libs.Color.GetD3DColor(255, 0, 0, 255)

---@param item string
---@return number | nil
function Utils.GetItemSlot(item)
    for _, slot in pairs(ITEM_SLOTS) do
        if myHero:GetSpell(slot):GetName() == item then
            return slot
        end
    end
    return nil
end

---@param summoner string
---@return number | nil
function Utils.GetSummonerSlot(summoner)
    for _, slot in pairs(SUMMONER_SLOTS) do
        if myHero:GetSpell(slot):GetName() == summoner then
            return slot
        end
    end
    return nil
end

---@return boolean
function Utils.IsMyHeroDashing()
    return myHero:AsAI():GetPathing():IsDashing()
end

---@param enemy SDK_AIHeroClient
function Utils.GenerateSpellFlashPositions(enemy)
    local posList = {}
    ---@type SDK_VECTOR
    local dir = (enemy:GetPosition() - myHero:GetPosition()):Normalized()
    local flashPos = myHero:GetPosition() + dir * FLASH_DIST
    if not SDK.NavMesh:IsWall(flashPos) then
        table.insert(posList, flashPos)
    end
    for i = 30, 90, 30 do
        local pos1 = myHero:GetPosition() + dir:Rotated(0, i, 0) * FLASH_DIST
        local pos2 = myHero:GetPosition() + dir:Rotated(0, -i, 0) * FLASH_DIST
        if not SDK.NavMesh:IsWall(pos1) then
            table.insert(posList, pos1)
        end
        if not SDK.NavMesh:IsWall(pos2) then
            table.insert(posList, pos2)
        end
    end
    return posList
end

local EQ_THRESHOLD = 1

--- checks in list for same number as the last number in list
---@param list number[]
---@return boolean
function Utils.CheckForSame(list)
    if #list <= 1 then
        return false
    end
    local last = list[#list]
    for i = #list - 1, 1, -1 do
        local this = list[i]
        if (this == math.huge and last == math.huge) or math.abs(last - this) < EQ_THRESHOLD then
            return true
        end
    end
    return false
end

---@param unit SDK_AIHeroClient
---@return boolean
function Utils.IsValidTarget(unit)
    return unit and unit:IsValid() and unit:IsVisible() and
        (unit:IsAttackableUnit() and not unit:AsAttackableUnit():IsDead())
end

---@param unit SDK_AIHeroClient
---@return SDK_VECTOR
function Utils.GetSourcePosition(unit)
    return Prediction.GetUnitPosition(unit, SDK.Game:GetLatency() / 2000)
    -- return _G.Prediction.SDK.GetTrueUnitPosition(unit, SDK.Game:GetLatency() / 2000)
end

---@return boolean
function Utils.IsValidPred(pred, spell, target)
    return pred and (myHero:GetPosition():Distance(target:GetPosition()) < spell.range or pred.realHitChance == 1)
end

---@param target SDK_AIHeroClient
---@return SDK_VECTOR
function Utils.GetHealthBarStartPos(target)
    local barPos = target:AsAI():GetHealthBarScreenPos()
    -- TODO: finish this
    return barPos
end

---@return number
function Utils.GetHealthBarWidth()
    local resolution = SDK.Renderer:GetResolution()
end

---@return number
function Utils.GetHealthBarHeight()

end

function Utils.DrawHealthBarDamage(damageFunc, range)
    local w = Utils.GetHealthBarWidth()
    local h = Utils.GetHealthBarHeight()
    for _, enemy in pairs(enemies) do
        if not Utils.IsValidTarget(enemy) or myHero:GetPosition():Distance(enemy:GetPosition()) > range then
            goto continue
        end
        local damage = damageFunc(enemy)
        local healthAfter = enemy:GetHealth() + enemy:GetShieldAll() - damage
        local canExecute = healthAfter <= damage
        local bar = enemy:AsAI():GetHealthBarScreenPos()
        if canExecute then
            local color = Utils.COLOR_RED
            local p1 = bar
            local p2 = bar + Vector(w, 0, 0)
            local p3 = bar + Vector(w, h, 0)
            local p4 = bar + Vector(0, h, 0)
            SDK.Renderer:DrawLine(p1, p2, color)
            SDK.Renderer:DrawLine(p2, p3, color)
            SDK.Renderer:DrawLine(p3, p4, color)
            SDK.Renderer:DrawLine(p4, p1, color)
        else
            local color = Utils.COLOR_RED
            local xOffset = w * (healthAfter / enemy:GetMaxHealth())
            local p1 = bar + Vector(xOffset, 0, 0)
            local p2 = bar + Vector(xOffset, h, 0)
            SDK.Renderer:DrawLine(p1, p2, color)
        end
        ::continue::
    end
end

function Utils.Uuid()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
            local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
            return string.format('%x', v)
        end)
end

return Utils
