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
local NearestEnemyTracker = require("Common.NearestEnemyTracker")
local CharmedTracker = require("Ahri.CharmedTracker")
local LastAutoTracker = require("Ahri.LastAutoTracker")
local SummonerTracker = require("Common.SummonerTracker")

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

    self.flashQueue = {
        pos = nil,
        time = nil
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
    ---@type NearestEnemyTracker
    self.nem = NearestEnemyTracker()
    ---@type CharmedTracker
    self.cm = CharmedTracker()
    ---@type LastAutoTracker
    self.lat = LastAutoTracker()
    ---@type SummonerTracker
    self.flashTracker = SummonerTracker("SummonerFlash")
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
    local charm = self.cm:GetClosestValidTarget()
    local validCharmedTarget = charm and myHero:GetPosition():Distance(charm:GetPosition()) < self.w.range - 25

    local auto = self.lat:GetLastAutoedEnemy()
    local validAutoedTarget = auto and Utils.IsValidTarget(auto) and
        myHero:GetPosition():Distance(auto:GetPosition()) < self.w.range - 25

    if validCharmedTarget or validAutoedTarget then
        SDK.Input:Cast(SDK.Enums.SpellSlot.W, myHero)
        return true
    end
end

function Ahri:CastE()
    local target, pred = self.TS:GetTarget(self.e, nil, nil, function(unit, pred)
        return self.nem:IsTarget(unit) and pred.rates["slow"]
    end, self.TS.Modes["Closest To Mouse"])
    if pred then
        SDK.Input:Cast(SDK.Enums.SpellSlot.E, pred.castPosition)
        pred:Draw()
        self.sqm:InvokeCastSpell("E")
        return true
    end
end

function Ahri:CastEFlash()
    local target = self.nem:GetClosestEnemyToMouse()
    if not target then
        return
    end
    local flashDist = 400
    local dir = (target:GetPosition() - myHero:GetPosition()):Normalized()
    local flashPos = myHero:GetPosition() + dir * flashDist
    if SDK.NavMesh:IsWall(flashPos) then
        return
    end
    local target, pred = self.TS:GetTarget(self.e, flashPos, nil, function(unit, pred)
        if unit:GetNetworkId() ~= target:GetNetworkId() then
            return
        end
        return pred.rates["slow"]
    end)
    if pred then
        SDK.Input:Cast(SDK.Enums.SpellSlot.E, pred.castPosition)
        pred:Draw()
        self.sqm:InvokeCastSpell("E")
        self.flashQueue.pos = flashPos
        self.flashQueue.time = SDK.Game:GetTime() + self.e.delay - 0.10
        return true
    end
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

function Ahri:OnTick()
    self:InvokeFlash()
    self:CastSpells()
end

function Ahri:InvokeFlash()
    if not self.flashQueue.time then
        return
    end
    if SDK.Game:GetTime() < self.flashQueue.time then
        return
    end
    local slot = self.flashTracker:GetSlot()
    local f = slot and myHero:CanUseSpell(slot)
    if f then
        SDK.Input:Cast(self.flashTracker:GetSlot(), self.flashQueue.pos)

    end
    self.flashQueue.pos = nil
    self.flashQueue.time = nil
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

    local slot = self.flashTracker:GetSlot()
    local f = slot and myHero:CanUseSpell(slot)
    if e and f and self.menu:Get("e.eFlash") and self:CastEFlash() then
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
    if q and self:CastQ(function(unit)
        return (self.menu:Get("q.q") and self.nem:IsTarget(unit)) or (isCombo and self.cm:IsCharmed(unit))
    end) then
        return
    end


end

Ahri:__init()
