---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

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

local loaded = false

if SDK.GetPlatform() == "FF15" then
    local dependencies = {
        {
            "DreamPred",
            _G.PaidScript.DREAM_PRED,
            function()
                return _G.Prediction
            end
        }
    }
    local ModernUOL = require("ModernUOL")
    ModernUOL:OnOrbLoad(
        function()
            _G.LoadDependenciesAsync(
                dependencies,
                function(success)
                    if success then
                        require(myHero:GetCharacterName() .. ".Main")
                    end
                end
            )
        end
    )
else
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnTick, function()
        if loaded then
            return
        end
        if not _G.DreamTS or not _G.Prediction then
            return
        end

        require(myHero:GetCharacterName() .. ".Main")
        loaded = true
    end)

end
