-- ---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

---@class Empyrean.Taliyah.QTracker
local QTracker = {}

local Q1_DURATION = 1.5

function QTracker:_init()
    self.isGround = false
    self.q1End = 0
    self.q1Direction = nil
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnCreateObject, function(...) self:_OnCreateObject(...) end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnDeleteObject, function(...) self:_OnDeleteObject(...) end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnProcessSpell, function(...) self:_OnProcessSpell(...) end)
end

---@param obj SDK_GameObject
---@param networkId number
function QTracker:_OnCreateObject(obj, networkId)
    if string.find(obj:GetName(), "Taliyah") and string.find(obj:GetName(), "Q_BuffGround") then
        self.isGround = true
    end
end

---@param obj SDK_GameObject
---@param networkId number
function QTracker:_OnDeleteObject(obj, networkId)
    if string.find(obj:GetName(), "Taliyah") and string.find(obj:GetName(), "Q_BuffGround") then
        self.isGround = false
    end
end

---@param obj SDK_AIBaseClient
---@param spell SDK_SpellCast
function QTracker:_OnProcessSpell(obj, spell)
    if obj:GetNetworkId() ~= myHero:GetNetworkId() then return end
    if spell:GetName() == "TaliyahQ" and not self:IsGround() then
        self.q1Direction = (spell:GetEndPos() - spell:GetStartPos()):Normalized()
        self.q1End = SDK.Game:GetTime() + spell:GetCastDelay() + Q1_DURATION
    end
end

---@return boolean
function QTracker:IsGround()
    return self.isGround
end

---@return boolean
function QTracker:IsCastingQ1()
    return self.q1End > SDK.Game:GetTime()
end

---@return SDK_VECTOR | nil
function QTracker:GetQ1Direction()
    if not self:IsCastingQ1() then return nil end
    return self.q1Direction
end

QTracker:_init()

return {
    IsGround = function() return QTracker:IsGround() end,
    IsCastingQ1 = function() return QTracker:IsCastingQ1() end,
    GetQ1Direction = function() return QTracker:GetQ1Direction() end
}
