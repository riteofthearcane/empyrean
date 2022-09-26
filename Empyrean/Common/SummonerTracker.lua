-- ---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

---@class SummonerTracker
local SummonerTracker = require("Common.Utils").Class()


---@param str string
function SummonerTracker:_init(str)
    self.summoner = str
    self.slot = nil
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnTick, function() self:_OnTick() end)
end

function SummonerTracker:_OnTick()
    self.slot = nil
    if myHero:GetSpell(SpellSlot.Summoner1):GetName() == self.summoner then
        self.slot = SDK.Enums.SpellSlot.Summoner1
    elseif myHero:GetSpell(SpellSlot.Summoner2):GetName() == self.summoner then
        self.slot = SDK.Enums.SpellSlot.Summoner2
    end
end

function SummonerTracker:GetSlot()
    return self.slot 
end

return SummonerTracker
