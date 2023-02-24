-- ---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

---@class Empyrean.Ahri.LastAutoTracker
local LastAutoTracker = require("Common.Utils").Class()

function LastAutoTracker:_init()
    self.data = {
        time = 0,
        target = nil
    }
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnBasicAttack,
        function(...) self:_OnBasicAttack(...) end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnUpdate, function() self:_OnUpdate() end)
end

---@param obj SDK_AIBaseClient
---@param cast SDK_SpellCast
function LastAutoTracker:_OnBasicAttack(obj, cast)
    local lower = string.lower(cast:GetName())
    if obj:GetNetworkId() == myHero:GetNetworkId() and string.find(lower, "ahri") and
        string.find(lower, "attack") and
        cast:GetTarget():IsHero() then
        self.data.time = SDK.Game:GetTime()
        self.data.target = obj:GetNetworkId()
    end
end

function LastAutoTracker:_OnUpdate()
    if self.data.time and SDK.Game:GetTime() > self.data.time + 1 then
        self.data.time = 0
        self.data.target = nil
    end
end

---@return SDK_AIHeroClient
function LastAutoTracker:GetLastAutoedEnemy()
    if not self.data.target then
        return
    end
    return SDK.ObjectManager:GetObjectFromNetworkId(self.data.target)
end

return LastAutoTracker
    