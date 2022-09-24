---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

local SUPPORTED_CHAMPIONS = {
    ["Xerath"] = true,
    ["Syndra"] = true,
    ["Lucian"] = true,
    ["Yone"] = true,
    ["Ahri"] = true,
    ["Taliyah"] = true
}


if not SUPPORTED_CHAMPIONS[myHero:GetCharacterName()] then
    return
end

require(myHero:GetCharacterName() .. ".Main")
