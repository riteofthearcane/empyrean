-- ---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

---@class LastAutoTracker
local LastAutoTracker = require("Common.Utils").Class()

function LastAutoTracker:_init()
    self.data = {
        time = 0,
        target = nil
    }
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnExecuteCastFrame,
        function(...) self:_OnExecuteCastFrame(...) end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnTick, function() self:_OnTick() end)
end

---@param obj SDK_AIBaseClient
---@param cast SDK_SpellCast
function LastAutoTracker:_OnExecuteCastFrame(obj, cast)
    if obj:GetNetworkId() == myHero:GetNetworkId() and string.find(cast:GetName(), "Ahri") and
        string.find(cast:GetName(), "Attack") and
        cast:GetTarget():IsHero() then
        self.data.time = SDK.Game:GetTime()
        self.data.target = obj:GetNetworkId()
    end
end

function LastAutoTracker:_OnTick()
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
    