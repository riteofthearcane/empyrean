---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

---@class DREAM_TS_INITIALIZER
local DreamTSLib = _G.DreamTS or require("DreamTS")
local DreamTS = DreamTSLib.TargetSelectorSdk
local Vector = SDK.Libs.Vector
local Utils = require("Common.Utils")
local SpellQueueManager = require("Common.SpellQueueManager")
local NearestEnemyManager = require("Common.NearestEnemyManager")

local enemies = SDK.ObjectManager:GetEnemyHeroes()

local Ahri = {}

function Ahri:__init()
    self.version = "2.0"
    self:InitFields()
    self:InitMenu()
    self:InitTS()
    self:InitEvents()
    SDK.PrintChat("Ahri - Empyrean loaded.")
end

function Ahri:InitFields()
    self.q = {
        type = "linear",
        speed = 2500,
        range = 900,
        delay = 0.25,
        trueWidth = 200,
        width = 60,
        collision = {
            ["Wall"] = true,
            ["Hero"] = false,
            ["Minion"] = false
        }
    }

    self.w = {
        range = 725
    }

    self.e = {
        type = "linear",
        speed = 1550,
        range = 925,
        delay = 0.25,
        width = 120,
        collision = {
            ["Wall"] = true,
            ["Hero"] = true,
            ["Minion"] = true
        }
    }

    self.ef = {
        type = "linear",
        speed = 1600,
        range = 800,
        delay = 0.3,
        castDelay = 0.15,
        width = 80,
        collision = {
            ["Wall"] = true
        },
        slot = nil
    }


    ---@type SpellQueueManager
    self.sqm = SpellQueueManager({
        Q = {
            name = "AhriOrbofDeception",
            delay = self.q.delay
        },
        W = {
            name = "AhriFoxFire",
            delay = 0
        },
        E = {
            name = "AhriSeduce",
            delay = self.e.delay
        },
        Ef = {
            name = "6656Cast",
            delay = self.ef.castDelay
        }
    })
    ---@type NearestEnemyManager
    self.nem = NearestEnemyManager()
end

function Ahri:InitMenu()
    self.menu = SDK.Libs.Menu("ahriempyrean", "Ahri - Empyrean")
    self.menu:AddLabel("Ahri - Empyrean v: " .. self.version, true)
    self.menu:AddSubMenu("dreamTs", "Target Selector")
    local qMenu = self.menu:AddSubMenu("q", "Q: Orb of Deception")
    qMenu:AddLabel("Cast Q on charmed targets in combo")
    qMenu:AddLabel("Cast Q by hovering mouse over enemy and pressing key")
    qMenu:AddKeybind("q", "Q Key", string.byte("Q"))
    local wMenu = self.menu:AddSubMenu("w", "W: Fox-fire")
    wMenu:AddLabel("Cast W on charmed or last attacked targets in combo")
    local eMenu = self.menu:AddSubMenu("e", "E: Charm")
    eMenu:AddLabel("Cast E/E flash by hovering mouse over enemy and pressing key")
    eMenu:AddKeybind("e", "E Key", string.byte("E"))
    eMenu:AddKeybind("eFlash", "E Flash Key", string.byte("T"))
    eMenu:AddLabel("Alternatively cast E/E flash by single or double tapping key")
    eMenu:AddKeybind("eTap", "E Tap Key", string.byte("E"))
    local efMenu = self.menu:AddSubMenu("ef", "Everfrost")
    efMenu:AddLabel("Cast Everfrost on CCed targets in combo")
    efMenu:AddLabel("Cast Everfrost by hovering mouse ov    er enemy and pressing key")
    efMenu:AddKeybind("ef", "Everfrost Key", string.byte("1"))
    local antigapMenu = self.menu:AddSubMenu("antigap", "Anti-Gap")
    antigapMenu:AddLabel("Cast E or Everfrost on anti-gap")
    for _, enemy in pairs(enemies) do
        local charName = enemy:GetCharacterName()
        antigapMenu:AddCheckbox(charName, charName, true)
    end
    self.menu:AddLabel("Disable smart cast on Q/E so you can use them regularly with the same key")
    local drawMenu = self.menu:AddSubMenu("draw", "Draw")
    drawMenu:AddCheckbox("q", "Draw Q Range", true)
    self.menu:Render()
end

function Ahri:InitTS()
    self.TS =
    DreamTS(
        self.menu:GetChild("dreamTs"),
        {
            Damage = DreamTS.Damages.AP
        }
    )
end

function Ahri:InitEvents()
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnTick, function() self:OnTick() end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnDraw, function() self:OnDraw() end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnProcessSpell, function(...) self:OnProcessSpell(...) end)
end

function Ahri:OnDraw()
    if self.menu:Get("draw.q") then
        SDK.Renderer:DrawCircle3D(myHero:GetPosition(), self.q.range, Utils.COLOR_WHITE)
    end
end

function Ahri:CastQ(unitFunc)
    local target, pred = self.TS:GetTarget(self.q, nil,
        function(unit)
            return unitFunc(unit)
        end,
        function(unit, pred)
            return pred.rates["slow"]
        end, self.TS.Modes["Closest To Mouse"])
    if not pred then
        return
    end
    self.sqm:InvokeCastSpell("Q")
    SDK.Input:Cast(SDK.Enums.SpellSlot.Q, pred.castPosition)
    pred:Draw()
    return true
end

function Ahri:CastW()

end

function Ahri:CastE()
    return
end

function Ahri:CastEFlash()

end

function Ahri:CastAntiGapE()
    local target, pred = self.TS:GetTarget(self.e, nil, nil, function(unit, pred)
        local menuName = "antigap." .. unit:GetCharacterName()
        return pred and pred.targetDashing and self.menu:Get(menuName)
    end)
    if not pred then
        return
    end
    self.sqm:InvokeCastSpell("E")
    SDK.Input:Cast(SDK.Enums.SpellSlot.E, pred.castPosition)
    pred:Draw()
    return true
end

function Ahri:CastEf()

end

function Ahri:CastAntiGapEf()
    return
end

function Ahri:CastEfCc()

end

function Ahri:OnProcessSpell(obj, cast)
    if obj:GetNetworkId() ~= myHero:GetNetworkId() then
        return
    end
    print(cast:GetName())
end

function Ahri:OnTick()
    self:CastSpells()
end

function Ahri:CastSpells()
    local q = myHero:CanUseSpell(SDK.Enums.SpellSlot.Q) and self.sqm:ShouldCast() and
        not Utils.IsMyHeroDashing()
    local w = myHero:CanUseSpell(SDK.Enums.SpellSlot.W) and self.sqm:ShouldCastSpell("W")
    local e = myHero:CanUseSpell(SDK.Enums.SpellSlot.E) and self.sqm:ShouldCast() and
        not Utils.IsMyHeroDashing()
    local ef = true --TODO
    if e and self:CastAntiGapE() then
        return
    end

    if not e and ef and self:CastAntiGapEf() then
        return
    end

    if e and self.menu:Get("e.e") and self:CastE() then
        return
    end

    if e and self.menu:Get("e.eFlash") and self:CastEFlash() then
        return
    end

    if ef and self.menu:Get("ef.ef") and self:CastEf() then
        return
    end
    local isCombo = SDK.Libs.Orbwalker:IsComboMode()

    if isCombo then
        if ef and self:CastEfCc() then
            return
        end
        if w and self:CastW() then
            return
        end
    end
    if not myHero:IsWindingUp() and q and self:CastQ(function(unit)
        return (self.menu:Get("q.q") and self.nem:IsTarget(unit))
        -- or
        --     (unit == self.charmedTarget and isCombo)
    end) then
        return
    end


end

Ahri:__init()
