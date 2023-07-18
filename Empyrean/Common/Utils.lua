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
        if string.lower(myHero:GetSpell(slot):GetName()) == item then
            return slot
        end
    end
    return nil
end

---@param summoner string
---@return number | nil
function Utils.GetSummonerSlot(summoner)
    for _, slot in pairs(SUMMONER_SLOTS) do
        if string.lower(myHero:GetSpell(slot):GetName()) == summoner then
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
    local x = SDK.Renderer:GetResolution().x
    local y = SDK.Renderer:GetResolution().y
    local barPos = target:AsAI():GetHealthBarScreenPos()
    if x == 3840 and y == 2160 then
        return Vector(barPos.x - 84, barPos.y - 44, barPos.z)
    end
    if x == 2560 and y == 1440 then
        return Vector(barPos.x - 57, barPos.y - 31, barPos.z)
    end
    if x == 1920 and y == 1080 then
        return Vector(barPos.x - 48, barPos.y - 26, barPos.z)
    end
    return Vector(barPos.x - 48, barPos.y - 26, barPos.z)
end

---@return number
function Utils.GetHealthBarWidth()
    local x = SDK.Renderer:GetResolution().x
    local y = SDK.Renderer:GetResolution().y
    if x == 3840 and y == 2160 then
        return 194
    end
    if x == 2560 and y == 1440 then
        return 130
    end
    if x == 1920 and y == 1080 then
        return 109
    end
    return 109
end

---@return number
function Utils.GetHealthBarHeight()
    local x = SDK.Renderer:GetResolution().x
    local y = SDK.Renderer:GetResolution().y
    if x == 3840 and y == 2160 then
        return 35
    end
    if x == 2560 and y == 1440 then
        return 25
    end
    if x == 1920 and y == 1080 then
        return 20
    end
    return 20
end

function Utils.DrawHealthBarDamage(damageFunc, range)
    local w = Utils.GetHealthBarWidth()
    local h = Utils.GetHealthBarHeight()
    for _, enemy in pairs(enemies) do
        if Utils.IsValidTarget(enemy) and myHero:GetPosition():Distance(enemy:GetPosition()) < range then
            local damage = damageFunc(enemy)
            local healthAfter = enemy:GetHealth() + enemy:GetShieldAll() - damage
            local canExecute = healthAfter <= 0
            local bar = Utils.GetHealthBarStartPos(enemy)
            if canExecute then
                local color = Utils.COLOR_RED
                local p1 = bar
                local p2 = Vector(bar.x + w, bar.y, 0)
                local p3 = Vector(bar.x + w, bar.y + h, 0)
                local p4 = Vector(bar.x, bar.y + h, 0)
                SDK.Renderer:DrawLine(p1, p2, color)
                SDK.Renderer:DrawLine(p2, p3, color)
                SDK.Renderer:DrawLine(p3, p4, color)
                SDK.Renderer:DrawLine(p4, p1, color)
            else
                local color = Utils.COLOR_GREEN
                local xOffset = w * (healthAfter / enemy:GetMaxHealth())
                local p1 = Vector(bar.x + xOffset, bar.y, bar.z)
                local p2 = Vector(bar.x + xOffset, bar.y + h, bar.z)
                SDK.Renderer:DrawLine(p1, p2, color)
            end
        end
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
