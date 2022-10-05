---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

---@class DREAM_TS_INITIALIZER
local DreamTSLib = _G.DreamTS or require("DreamTS")
local DreamTS = DreamTSLib.TargetSelectorSdk
local Utils = require("Common.Utils")
local SpellQueueManager = require("Common.SpellQueueManager")
local BuffManager = require("Xerath.BuffManager")
local enemies = SDK.ObjectManager:GetEnemyHeroes()

local Xerath = {}

function Xerath:__init()
    self.version = "2.0"
    self:InitFields()
    self:InitMenu()
    self:InitTS()
    self:InitEvents()
    SDK.PrintChat("Xerath - Empyrean loaded.")
end

function Xerath:InitFields()
    self.q = {
        type = "linear",
        min = 700,
        max = 1450,
        charge = 1.5,
        range = 1450,
        delay = 0.61,
        width = 145,
        speed = math.huge,
    }

    self.w = {
        type = "circular",
        range = 1000,
        delay = 0.85,
        radius = 275,
        speed = math.huge
    }
    self.e = {
        type = "linear",
        range = 1000,
        delay = 0.25,
        width = 120,
        speed = 1400,
        collision = {
            ["Wall"] = true,
            ["Hero"] = true,
            ["Minion"] = true
        }
    }
    self.r = {
        type = "circular",
        active = false,
        range = 5000,
        delay = 0.7,
        radius = 200,
        speed = math.huge,
        lastTarget = nil,
        mode = nil
    }

    ---@type SpellQueueManager
    self.sqm = SpellQueueManager({
        Q1 = {
            name = "XerathArcanopulseChargeUp",
            delay = 0,
        },
        Q2 = {
            name = "XerathArcanopulse2",
            delay = 0.8
        },
        W = {
            name = "XerathArcaneBarrage2",
            delay = 0.25
        },
        E = {
            name = "XerathMageSpear",
            delay = 0.25
        },
        R = {
            name = "XerathLocusPulse",
            delay = 0.15
        }
    })
    ---@type Empyrean.Xerath.BuffManager
    self.bm = BuffManager()
end

function Xerath:InitMenu()
    self.menu = SDK.Libs.Menu("xerathEmpyrean", "Xerath - Empyrean")
    self.menu:AddLabel("Xerath - Empyrean v: " .. self.version, true)
    self.menu:AddSubMenu("dreamTs", "Target Selector")
    local qMenu = self.menu:AddSubMenu("q", "Q: Arcanopulse")
    qMenu:AddLabel("Cast Q in combo if w not ready")
    local wMenu = self.menu:AddSubMenu("w", "W: Eye of Destruction")
    qMenu:AddLabel("Cast W in combo")
    local eMenu = self.menu:AddSubMenu("e", "E: Shocking Orb")
    eMenu:AddLabel("Cast E/E flash by pressing key")
    eMenu:AddKeybind("e", "E Key", string.byte("E"))
    eMenu:AddKeybind("eFlash", "E Flash Key", string.byte("T"))
    -- eMenu:AddLabel("Alternatively cast E/E flash by single or double tapping key")
    -- eMenu:AddKeybind("eTap", "E Tap Key", string.byte("E"))
    local rMenu = self.menu:AddSubMenu("r", "R: Rite of the Arcane")
    rMenu:AddLabel("Cast R shots by holding key and hovering mouse over enemy")
    rMenu:AddKeybind("r", "R Tap Key", string.byte("T"))
    rMenu:AddSlider("circle", "R aim circle radius", { min = 100, max = 3000, default = 1500, step = 100 })
    rMenu:AddCheckbox("circleOnly", "Cast only if in circle: otherwise prioritize circle enemies", true)

    local antigapMenu = self.menu:AddSubMenu("antigap", "Anti-Gap")
    antigapMenu:AddLabel("Cast E or W on anti-gap")
    for _, enemy in pairs(enemies) do
        local charName = enemy:GetCharacterName()
        local charMenu = antigapMenu:AddSubMenu(charName, charName)
        charMenu:AddCheckbox("e", "E", true)
        charMenu:AddCheckbox("w", "W", true)
        antigapMenu:AddCheckbox(charName, charName, true)
    end
    local drawMenu = self.menu:AddSubMenu("draw", "Draw")
    drawMenu:AddCheckbox("q", "Draw Q range", true)
    drawMenu:AddCheckbox("r", "Draw R range", true)
    drawMenu:AddCheckbox("rMinimap", "Draw R range on minimap", true)
    drawMenu:AddCheckbox("rCircle", "Draw R aim circle ", true)
    self.menu:Render()
end

function Xerath:InitTS()
    self.TS =
    DreamTS(
        self.menu:GetChild("dreamTs"),
        {
            Damage = DreamTS.Damages.AP
        }
    )
end

function Xerath:InitEvents()
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnTick, function() self:OnTick() end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnDraw, function() self:OnDraw() end)
end

function Xerath:OnDraw()
    if self.menu:Get("draw.q") then
        SDK.Renderer:DrawCircle3D(myHero:GetPosition(), self.q.range, Utils.COLOR_WHITE)
    end
    if self.menu:Get("draw.r") then
        SDK.Renderer:DrawCircle3D(myHero:GetPosition(), self.r.range, Utils.COLOR_WHITE)
    end
    if self.menu:Get("draw.rMinimap") then
        SDK.Renderer:DrawCircleMinimap(myHero:GetPosition(), self.r.range, Utils.COLOR_WHITE)
    end
    local mousePos = SDK.Renderer:GetMousePos3D()
    local radius = self.menu:Get("r.circle")
    if self.menu:Get("draw.rCircle") and self.bm:IsRActive() then
        SDK.Renderer:DrawCircle3D(mousePos, radius, Utils.COLOR_WHITE)
    end
end

function Xerath:UpdateQRange()
    self.q.range = self:GetQRange()
end

function Xerath:GetQRange()
    if not self.bm:IsQActive() then
        return self.q.max
    end
    return math.min(self.q.min + (self.q.max - self.q.min) *
        (SDK.Game:GetTime() - self.bm:GetQStartTime() - SDK.Game:GetLatency() / 2000) / self.q.charge, self.q.max)
end

function Xerath:CastQ()

end

function Xerath:HasWPred()
    local target, pred = self.TS:GetTarget(self.w)
    return pred and true or false
end

function Xerath:CastW()
    local target, pred = self.TS:GetTarget(self.w, nil, nil,
        function(unit, pred)
            -- anti feez pred
            if myHero:GetPosition():Distance(pred.castPosition) > self.w.range - self.w.radius then
                return false
            end
            return pred.rates["slow"]
        end)
    if not pred then
        return
    end
    SDK.Input:Cast(SDK.Enums.SpellSlot.W, pred.castPosition)
    self.sqm:InvokeCastSpell("W")
    pred:Draw()
    return true
end

function Xerath:CastAntiGapW()
    local target, pred = self.TS:GetTarget(self.w, nil, nil, function(unit, pred)
        local menuName = "antigap." .. unit:GetCharacterName() .. ".w"
        return pred and pred.targetDashing and self.menu:Get(menuName)
    end)
    if not pred then
        return
    end
    self.sqm:InvokeCastSpell("W")
    SDK.Input:Cast(SDK.Enums.SpellSlot.W, pred.castPosition)
    pred:Draw()
    return true
end

function Xerath:CastE()
    local target, pred = self.TS:GetTarget(self.e, nil, nil,
        function(unit, pred)
            return pred.rates["slow"]
        end)
    if not pred then
        return
    end
    SDK.Input:Cast(SDK.Enums.SpellSlot.E, pred.castPosition)
    self.sqm:InvokeCastSpell("E")
    pred:Draw()
    return true
end

function Xerath:CastAntiGapE()
    local target, pred = self.TS:GetTarget(self.e, nil, nil, function(unit, pred)
        local menuName = "antigap." .. unit:GetCharacterName() .. ".e"
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

function Xerath:CastR()
    local circleTarget, circlePred = self.TS:GetTarget(self.r, nil, nil,
        function(unit, pred)
            return self:IsInRCircle(unit) and pred.rates["slow"]
        end)
    if circlePred then
        SDK.Input:Cast(SDK.Enums.SpellSlot.R, circlePred.castPosition)
        self.sqm:InvokeCastSpell("R")
        circlePred:Draw()
        return true
    end
    if self.menu:Get("r.circleOnly") then
        return
    end
    local target, pred = self.TS:GetTarget(self.r, nil, nil,
        function(unit, pred)
            return pred.rates["slow"]
        end)
    if not pred then
        return
    end
    SDK.Input:Cast(SDK.Enums.SpellSlot.R, pred.castPosition)
    self.sqm:InvokeCastSpell("R")
    pred:Draw()
    return true
end

function Xerath:IsInRCircle(enemy)
    return enemy:GetPosition():Distance(SDK.Renderer:GetMousePos3D()) < self.menu:Get("r.circle")
end


function Xerath:OnTick()
    self:UpdateQRange()
    self:CastSpells()
end

function Xerath:CastSpells()
    local evade = _G.DreamEvade and _G.DreamEvade.HasPath()
    local q = myHero:CanUseSpell(SDK.Enums.SpellSlot.Q) and self.sqm:ShouldCast() and not evade
    local w = myHero:CanUseSpell(SDK.Enums.SpellSlot.W) and self.sqm:ShouldCast() and not evade
    local e = myHero:CanUseSpell(SDK.Enums.SpellSlot.E) and self.sqm:ShouldCast() and not evade


    if self.bm:IsRActive() then
        if self.menu:Get("r.r") then
            self:CastR()
        end
        return
    end

    if self.bm:IsQActive() then
        if q then
            self:CastQ()
        end
        return
    end

    if e and self:CastAntiGapE() then
        return
    end

    if w and self:CastAntiGapW() then
        return
    end

    if e and self.menu:Get("e.e") and self:CastE() then
        return
    end

    local isCombo = SDK.Libs.Orbwalker:IsComboMode()

    if isCombo then
        if w and self:CastW() then
            return
        end 
        if (not self:HasWPred() or not w) and q and self:CastQ() then
            return
        end
    end
end

Xerath:__init()
