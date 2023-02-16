---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

---@class DREAM_TS_INITIALIZER
local DreamTSLib = _G.DreamTS or require("DreamTS")
local DreamTS = DreamTSLib.TargetSelectorSdk
local Utils = require("Common.Utils")
local SpellLockManager = require("Common.SpellLockManager")
local NearestEnemyTracker = require("Common.NearestEnemyTracker")
local TapManager = require("Common.TapManager")
local BuffManager = require("Xerath.BuffManager")
local LevelTracker = require("Common.LevelTracker")
local enemies = SDK.ObjectManager:GetEnemyHeroes()

local Xerath = {}

function Xerath:__init()
    self.version = "2.0"
    self:InitMenu()
    self:InitFields()
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
    }

    self.flashQueue = {
        pos = nil,
        time = nil
    }

    ---@type Empyrean.Common.SpellLockManager
    self.slm = SpellLockManager()
    ---@type Empyrean.Xerath.BuffManager
    self.bm = BuffManager()

    ---@type Empyrean.Common.TapManager
    self.tm = TapManager(
            function() return self.menu:Get("e.useTap") and self.menu:Get("e.eTap") end,
            function() return not self.menu:Get("e.useTap") and self.menu:Get("e.e") end,
            function() return not self.menu:Get("e.useTap") and self.menu:Get("e.eFlash") end
        )

    ---@type Empyrean.Common.NearestEnemyTracker
    self.nem = NearestEnemyTracker()

    ---@type Empyrean.Common.LevelTracker
    self.lt = LevelTracker()

    self.ts =
        DreamTS(
            self.menu:GetChild("dreamTs"),
            {
                Damage = DreamTS.Damages.AP
            }
        )
end

function Xerath:InitMenu()
    self.menu = SDK.Libs.Menu("xerathEmpyrean", "Xerath - Empyrean")
    self.menu:AddLabel("Xerath - Empyrean v: " .. self.version, true)
    self.menu:AddSubMenu("dreamTs", "Target Selector")
    local qMenu = self.menu:AddSubMenu("q", "Q: Arcanopulse")
    qMenu:AddLabel("Cast Q in combo if w not ready")
    local wMenu = self.menu:AddSubMenu("w", "W: Eye of Destruction")
    wMenu:AddLabel("Cast W in combo")
    local eMenu = self.menu:AddSubMenu("e", "E: Shocking Orb")
    eMenu:AddCheckbox("useCombo", "Use E in Combo", true)
    eMenu:AddCheckbox("useTap", "Cast E/E Flash by single or double tapping key", true)
    eMenu:AddKeybind("eTap", "E Tap Key", string.byte("E"))
    eMenu:AddLabel("Alternatively use separate keys (disabled if above toggle on)")
    eMenu:AddKeybind("e", "E Key", string.byte("E"))
    eMenu:AddKeybind("eFlash", "E Flash Key", string.byte("E"))
    local rMenu = self.menu:AddSubMenu("r", "R: Rite of the Arcane")
    rMenu:AddLabel("Cast R shots by holding key and hovering mouse over enemy")
    rMenu:AddKeybind("r", "R Tap Key", string.byte("T"))
    rMenu:AddSlider("circle", "R aim circle radius", { min = 100, max = 3000, default = 1500, step = 100 })
    rMenu:AddCheckbox("circleOnly", "Cast only if in circle: otherwise prioritize circle enemies", false)

    local antigapMenu = self.menu:AddSubMenu("antigap", "Anti-Gap")
    antigapMenu:AddLabel("Cast E or W on anti-gap")
    for _, enemy in pairs(enemies) do
        local charName = enemy:GetCharacterName()
        local charMenu = antigapMenu:AddSubMenu(charName, charName)
        charMenu:AddCheckbox("e", "E", true)
        charMenu:AddCheckbox("w", "W", true)
    end
    local drawMenu = self.menu:AddSubMenu("draw", "Draw")
    drawMenu:AddCheckbox("q", "Draw Q range", true)
    drawMenu:AddCheckbox("we", "Draw W/E range", true)
    drawMenu:AddCheckbox("r", "Draw R range", true)
    drawMenu:AddCheckbox("rMinimap", "Draw R range on minimap", true)
    drawMenu:AddCheckbox("rCircle", "Draw R aim circle ", true)
    drawMenu:AddCheckbox("rDmg", "Draw R dmg ", true)
    self.menu:Render()
end

function Xerath:InitEvents()
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnUpdate, function() self:OnUpdate() end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnDraw, function() self:OnDraw() end)
end

function Xerath:OnDraw()
    if not self.bm:IsRActive() and self.menu:Get("draw.q") then
        SDK.Renderer:DrawCircle3D(myHero:GetPosition(), self.q.range, Utils.COLOR_WHITE)
    end
    if not self.bm:IsQActive() and not self.bm:IsRActive() and self.menu:Get("draw.we") then
        SDK.Renderer:DrawCircle3D(myHero:GetPosition(), self.w.range, Utils.COLOR_WHITE)
    end
    local level = myHero:GetSpell(SDK.Enums.SpellSlot.R):GetLevel()
    if level == 0 then return end
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
    if self.menu:Get("draw.rDmg") then
        local f = function(target)
            local level = myHero:GetSpell(SDK.Enums.SpellSlot.R):GetLevel()
            local total = 0.45 * myHero:GetTotalAP() + 150 + 50 * level
            return SDK.Libs.Damage:GetMagicalDamage(myHero, target, total)
        end
        Utils.DrawHealthBarDamage(f, self.r.range)
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

function Xerath:CastQ1()
    local target, pred = self.ts:GetTarget(self.q, nil, nil,
            function(unit, checkPred) return Utils.IsValidPred(checkPred, self.q, unit) end)
    if not pred then
        return
    end
    -- if myHero:GetPosition():Distance(pred.targetPosition) < self.q.min then
    --     -- defer cast Q1 until slow pred found
    --     if not pred.rates["slow"] then
    --         return
    --     end
    --     --TODO: check if this working
    --     if SDK.Input:CastFast(SDK.Enums.SpellSlot.Q, pred.castPosition) and
    --         SDK.Input:Release(SDK.Enums.SpellSlot.Q, pred.castPosition) then
    --         pred.drawRange = self.q.min
    --         pred:Draw()
    --         return true
    --     end
    -- else
    --     if not SDK.Input:Cast(SDK.Enums.SpellSlot.Q, pred.castPosition) then
    --         return true
    --     end
    -- end
    if not SDK.Input:Cast(SDK.Enums.SpellSlot.Q, pred.castPosition) then
        return true
    end
end

function Xerath:CastQ2()
    local target, pred = self.ts:GetTarget(self.q, nil, nil,
            function(unit, checkPred) return Utils.IsValidPred(checkPred, self.q, unit) end)
    if not pred or not pred.rates["slow"] then
        return
    end
    if not SDK.Input:Release(SDK.Enums.SpellSlot.Q, pred.castPosition) then
        pred:Draw()
        return true
    end
end

function Xerath:HasWPred()
    local target, pred = self.ts:GetTarget(self.w)
    return pred ~= nil
end

function Xerath:HasEPred()
    local target, pred = self.ts:GetTarget(self.e, nil, nil,
            function(unit, checkPred) return Utils.IsValidPred(checkPred, self.e, unit) end)
    return pred ~= nil
end

function Xerath:CastW()
    local target, pred = self.ts:GetTarget(self.w)
    if not pred or not pred.rates["slow"] then
        return
    end
    if SDK.Input:Cast(SDK.Enums.SpellSlot.W, pred.castPosition) then
        pred:Draw()
        return true
    end
end

function Xerath:CastAntiGapW()
    local target, pred = self.ts:GetTarget(self.w, nil, nil, function(unit, pred)
            local menuName = "antigap." .. unit:GetCharacterName() .. ".w"
            return pred and pred.targetDashing and self.menu:Get(menuName)
        end)
    if not pred then
        return
    end
    if SDK.Input:CastFast(SDK.Enums.SpellSlot.W, pred.castPosition) then
        pred:Draw()
        return true
    end
end

function Xerath:CastE()
    local target, pred = self.ts:GetTarget(self.e, nil, nil,
            function(unit, checkPred) return Utils.IsValidPred(checkPred, self.e, unit) end)
    if not pred or not pred.rates["slow"] then
        return
    end
    if SDK.Input:Cast(SDK.Enums.SpellSlot.E, pred.castPosition) then
        pred:Draw()
        return true
    end
end

function Xerath:CastEFlash()
    local target = self.nem:GetClosestEnemyToMouse()
    if not target then
        return
    end
    local posList = Utils.GenerateSpellFlashPositions(target)
    for _, pos in pairs(posList) do
        local target, pred = self.ts:GetTarget(self.e, pos, nil, function(unit, pred)
                return self.nem:IsTarget(unit) and pred.rates["slow"]
            end, self.ts.Modes["Closest To Mouse"])
        if pred and SDK.Input:Cast(SDK.Enums.SpellSlot.E, pred.castPosition) then
            pred:Draw()
            self.flashQueue.pos = pos
            self.flashQueue.time = SDK.Game:GetTime() + self.e.delay - 0.10
            return true
        end
    end
end

function Xerath:CastAntiGapE()
    local target, pred = self.ts:GetTarget(self.e, nil, nil, function(unit, pred)
            local menuName = "antigap." .. unit:GetCharacterName() .. ".e"
            return pred and pred.targetDashing and self.menu:Get(menuName)
        end)
    if not pred then
        return
    end
    if SDK.Input:CastFast(SDK.Enums.SpellSlot.E, pred.castPosition) then
        pred:Draw()
        return true
    end
end

function Xerath:CastR()
    local circleTarget, circlePred = self.ts:GetTarget(self.r, nil, function(unit)
            return self:IsInRCircle(unit)
        end)
    if circlePred then
        if circlePred.rates["slow"] then
            SDK.Input:Cast(SDK.Enums.SpellSlot.R, circlePred.castPosition)
            circlePred:Draw()
            return true
        end
        return
    end
    if self.menu:Get("r.circleOnly") then
        return
    end
    local target, pred = self.ts:GetTarget(self.r)
    if not pred or not pred.rates["slow"] then
        return
    end
    if SDK.Input:Cast(SDK.Enums.SpellSlot.R, pred.castPosition) then
        pred:Draw()
        return true
    end
end

function Xerath:IsInRCircle(enemy)
    return enemy:GetPosition():Distance(SDK.Renderer:GetMousePos3D()) < self.menu:Get("r.circle")
end

function Xerath:OnUpdate()
    self:UpdateQRange()
    self:InvokeFlash()
    self:CastSpells()
end

function Xerath:InvokeFlash()
    if not self.flashQueue.time then
        return
    end
    if SDK.Game:GetTime() < self.flashQueue.time then
        return
    end
    local slot = Utils.GetSummonerSlot("SummonerFlash")
    local f = slot and myHero:CanUseSpell(slot)
    if f and SDK.Input:Cast(slot, self.flashQueue.pos) then
        self.flashQueue.pos = nil
        self.flashQueue.time = nil
        return true
    end
end

function Xerath:CastSpells()
    local q = myHero:CanUseSpell(SDK.Enums.SpellSlot.Q) and self.slm:ShouldCast()
    local w = myHero:CanUseSpell(SDK.Enums.SpellSlot.W) and self.slm:ShouldCast()
    local e = myHero:CanUseSpell(SDK.Enums.SpellSlot.E) and self.slm:ShouldCast()
    local r = myHero:CanUseSpell(SDK.Enums.SpellSlot.R) and self.slm:ShouldCast()

    if self.bm:IsRActive() then
        if r and self.menu:Get("r.r") then
            self:CastR()
        end
        return
    end

    local isCombo = SDK.Libs.Orbwalker:IsComboMode()
    local isHarass = SDK.Libs.Orbwalker:IsHarassMode()

    if self.bm:IsQActive() then
        if (isCombo or isHarass) and q then
            self:CastQ2()
        end
        return
    end

    if e and self:CastAntiGapE() then
        return
    end

    if w and self:CastAntiGapW() then
        return
    end
    if e and (isCombo and self.menu:Get("e.useCombo") or (self.tm:GetSingleTap() and self.lt:ShouldCast())) and
        self:CastE() then
        return
    end

    local slot = Utils.GetSummonerSlot("SummonerFlash")
    local f = slot and myHero:CanUseSpell(slot)
    if e and f and self.tm:GetDoubleTap() and self.lt:ShouldCast() and self:CastEFlash() then
        return
    end

    if isCombo then
        if w and self:CastW() then
            return
        end
        if ((not w or not self:HasWPred()) and (not e or not self:HasEPred())) and q and self:CastQ1() then
            return
        end
    end
    if isHarass then
        if w and self:CastW() then
            return
        end
        if not w and q and self:CastQ1() then
            return
        end
    end
end

Xerath:__init()
