-- ---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

local MAX_INTERVAL = 0.1
local MAX_HOLD_TIME = 0.1

---@class Empyrean.Common.TapManager
local TapManager = require("Common.Utils").Class()

---@param fCommon function @tap key
---@param fSingle function @single key
---@param fDouble function @double key
function TapManager:_init(fCommon, fSingle,fDouble)
    self._fCommon = fCommon
    self._fSingle = fSingle
    self._fDouble = fDouble
    self._prev = false
    self._count = 0
    self._available = true
    self._startTime = 0
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnUpdate, function() self:_OnUpdate() end)
end

function TapManager:_OnUpdate()
    -- reset after a while
    if not self._prev and SDK.Game:GetTime() > self._startTime + MAX_INTERVAL then
        self._count = 0
        self._available = false
    end
    -- make first tap available after MAX_HOLD_TIME
    if self._prev and SDK.Game:GetTime() > self._startTime + MAX_HOLD_TIME then
        self._available = true
    end
    local state = self._fCommon()
    if state == self._prev then
        return
    end
    self._prev = state
    self._startTime = SDK.Game:GetTime()
    if state then
        self._count = math.min(2, self._count + 1)
        -- available instantly at 2 taps
        self._available = self._count == 2
    else
        self._available = false
    end
end

---@return boolean
function TapManager:GetSingleTap()
    return (self._count == 1 and self._available) or self._fSingle()
end

---@return boolean
function TapManager:GetDoubleTap()
    return (self._count == 2 and self._available) or self._fDouble()
end

function TapManager:GetCount()
    return self._count
end

return TapManager