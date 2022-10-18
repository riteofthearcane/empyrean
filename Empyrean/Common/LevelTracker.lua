-- ---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@class Empyrean.Common.LevelTracker
local LevelTracker = require("Common.Utils").Class()

local LEVEL_KEY = 17


function LevelTracker:_init()
    self.time = SDK.Game:GetTime()
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnUpdate, function() self:_OnUpdate() end)
end

function LevelTracker:_OnUpdate()
    if SDK.Keyboard:IsKeyDown(LEVEL_KEY) then
        self.time = SDK.Game:GetTime() + 0.25
    end
end

function LevelTracker:ShouldCast()
    return SDK.Game:GetTime() > self.time
end

return LevelTracker
