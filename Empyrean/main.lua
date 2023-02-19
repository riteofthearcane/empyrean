
if rawget(_G, "Empyrean") then
    print("Instance of Empyrean already loaded.")
    return
end

---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_DreamApiLoader
local DreamLoader = require("DreamApi.Loader")

---@type SDK_AIHeroClient
local myHero = SDK.Player

local SUPPORTED_CHAMPIONS = {
    ["Xerath"] = true,
    ["Syndra"] = true,
    ["Ahri"] = true,
    ["Taliyah"] = true, 
}


if not SUPPORTED_CHAMPIONS[myHero:GetCharacterName()] then
    return
end

DreamLoader.LoadChampDependencies(function()
    require(myHero:GetCharacterName() .. ".Main")
end)
