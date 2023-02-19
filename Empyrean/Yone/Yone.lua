---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

local DreamLoader = require("Common.DreamLoader")
local DreamTS = DreamLoader.Api.TargetSelector
local Utils = require("Common.Utils")
local SpellQueueManager = require("Common.SpellQueueManager")


local Yone = {}

function Yone:__init()
    self.version = "2.0"
    self:InitFields()
    self:InitMenu()
    self:InitTs()
    self:InitEvents()
end

function Yone:InitMenu()
    self.menu = SDK.Libs.Menu("yoneempyrean", "Yone - Empyrean")
    self.menu:AddLabel("Yone - Empyrean v: " .. self.version, true)
    self.menu:AddSubMenu("dreamTs", "Target Selector")
    local qMenu = self.menu:AddSubMenu("q", "Q: Mortal Steel")
    qMenu:AddLabel("Cast Q on charmed targets in combo")
    qMenu:AddLabel("Cast Q by hovering mouse over enemy and pressing key")
    qMenu:AddKeybind("q", "Q Key", string.byte("Q"))
    local wMenu = self.menu:AddSubMenu("w", "W: Fox-fire")
    wMenu:AddLabel("Cast W on charmed or last attacked targets in combo")
    local eMenu = self.menu:AddSubMenu("e", "E: Charm")
    eMenu:AddLabel("Cast E/E flash by hovering mouse over enemy and pressing key")
    eMenu:AddKeybind("e", "E Key", string.byte("E"))
    eMenu:AddKeybind("eFlash", "E Flash Key", string.byte("T"))
    -- eMenu:AddLabel("Alternatively cast E/E flash by single or double tapping key")
    -- eMenu:AddKeybind("eTap", "E Tap Key", string.byte("E"))
    local efMenu = self.menu:AddSubMenu("ef", "Everfrost")
    efMenu:AddLabel("Cast Everfrost on CCed targets in combo")
    efMenu:AddLabel("Cast Everfrost by hovering mouse over enemy and pressing key")
    efMenu:AddKeybind("ef", "Everfrost Key", string.byte("1"))
    local antigapMenu = self.menu:AddSubMenu("antigap", "Anti-Gap")
    antigapMenu:AddLabel("Cast E or Everfrost on anti-gap")
    for _, enemy in pairs(enemies) do
        local charName = enemy:GetCharacterName()
        antigapMenu:AddCheckbox(charName, charName, true)
    end
    self.menu:AddLabel("Disable smart cast on Q/E so you can use them regularly with the same key")
    local drawMenu = self.menu:AddSubMenu("draw", "Draw")
    drawMenu:AddCheckbox("r", "Draw R Range", true)
    drawMenu:AddCheckbox("lastHit", "Draw Last Hit", true)
    drawMenu:AddCheckbox("mark", "Draw E Killable Mark", true)

    self.menu:Render()
end

function Yone:InitTs()

end
function Yone:InitEvents()

end



function Yone:LoadMenu()

end


Yone:__init()
