-- ---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@class Empyrean.Common.Debug
local Debug = {}

function Debug:_init()
    self.funcs = {}
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnUpdate, function() self:_OnUpdate() end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnDraw, function() self:_OnDraw() end)
end

function Debug:_OnUpdate()
    for func, time in pairs(self.funcs) do
        if time < SDK.Game:GetTime() then
            self.funcs[func] = nil
        end
    end
end

function Debug:RegisterDraw(drawFunc, time)
    self.funcs[drawFunc] = SDK.Game:GetTime() + time
end

function Debug:_OnDraw()
    for func in pairs(self.funcs) do
        func()
    end
end

Debug:_init()

return {
    RegisterDraw = function(drawFunc, time)
        Debug:RegisterDraw(drawFunc, time)
    end
}
