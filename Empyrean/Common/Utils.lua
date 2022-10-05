local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

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

---@param unit SDK_AIHeroClient
---@return boolean
function Utils.IsValidTarget(unit)
    return unit and unit:IsValid() and unit:IsVisible() and
        (unit:IsAttackableUnit() and not unit:AsAttackableUnit():IsDead())
end

return Utils
