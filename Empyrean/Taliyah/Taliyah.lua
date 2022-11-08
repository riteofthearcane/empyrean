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
local LevelTracker = require("Common.LevelTracker")
local QTracker = require("Taliyah.QTracker")
local Geometry = require("Common.Geometry")
local enemies = SDK.ObjectManager:GetEnemyHeroes()
local ModernUOL = SDK:GetPlatform() == "FF15" and require("ModernUOL") or nil


local Taliyah = {}

function Taliyah:__init()
    self.version = "2.0"
    self:InitMenu()
    self:InitFields()
    self:InitEvents()
    SDK.PrintChat("Taliyah - Empyrean loaded.")
end

function Taliyah:InitFields()
    self.q1 = {
        type = "linear",
        range = 900,
        delay = 0.25,
        width = -200,
        speed = 3600,
        collision = {
            ["Wall"] = true,
            ["Hero"] = true,
            ["Minion"] = true
        }
    }

    self.Q1_WIDTH = 200

    self.q2 = {
        type = "linear",
        range = 900,
        delay = 0.25,
        width = 200,
        speed = 2000,
        collision = {
            ["Wall"] = true,
            ["Hero"] = true,
            ["Minion"] = true
        }
    }

    self.Q2_EXPLOSION_RADIUS = 225

    self.w = {
        type = "circular",
        range = 1000,
        delay = 1,
        radius = 225,
        speed = math.huge
    }
    self.e = {
        type = "circular",
        range = 1000,
        delay = 0.25,
        radius = 1,
        speed = 1000
    }

    ---@type Empyrean.Common.SpellLockManager
    self.slm = SpellLockManager()

    ---@type Empyrean.Common.TapManager
    self.tm = TapManager(
        function() return self.menu:Get("w.useTap") and self.menu:Get("w.wTap") end,
        function() return not self.menu:Get("w.useTap") and self.menu:Get("w.wTo") end,
        function() return not self.menu:Get("w.useTap") and self.menu:Get("w.wAway") end
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

function Taliyah:InitMenu()
    self.menu = SDK.Libs.Menu("TaliyahEmpyrean", "Taliyah - Empyrean")
    self.menu:AddLabel("Taliyah - Empyrean v: " .. self.version, true)
    self.menu:AddSubMenu("dreamTs", "Target Selector")
    local qMenu = self.menu:AddSubMenu("q", "Q: Threaded Volley")
    qMenu:AddLabel("Cast regular Q with key")
    qMenu:AddKeybind("q", "Q Key", string.byte("Q"))
    qMenu:AddLabel("Autofollow regular Q in combo")
    qMenu:AddLabel("Cast worked Q in combo")
    local wMenu = self.menu:AddSubMenu("w", "W: Seismic Shove")
    wMenu:AddCheckbox("useTap", "Cast W to/away from player by single or double tapping key", true)
    wMenu:AddKeybind("wTap", "W Tap Key", string.byte("W"))
    wMenu:AddLabel("Alternatively use separate keys (disabled if above toggle on)")
    wMenu:AddKeybind("wTo", "W to Key", string.byte("W"))
    wMenu:AddKeybind("wAway", "W away Key", string.byte("T"))
    local eMenu = self.menu:AddSubMenu("e", "E: Unraveled Earth")
    eMenu:AddLabel("use E after W in combo")
    local antigapMenu = self.menu:AddSubMenu("antigap", "Anti-Gap")
    antigapMenu:AddLabel("Cast E or W on anti-gap")
    for _, enemy in pairs(enemies) do
        antigapMenu:AddCheckbox(enemy:GetCharacterName(), enemy:GetCharacterName(), true)
    end
    local drawMenu = self.menu:AddSubMenu("draw", "Draw")
    drawMenu:AddCheckbox("q", "Draw Q range", true)
    drawMenu:AddCheckbox("r", "Draw R range", true)
    drawMenu:AddCheckbox("rMinimap", "Draw R range on minimap", true)
    self.menu:Render()
end

function Taliyah:InitEvents()
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnUpdate, function() self:OnUpdate() end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnDraw, function() self:OnDraw() end)
end

function Taliyah:GetRRange()
    local level = myHero:GetSpell(SDK.Enums.SpellSlot.R):GetLevel()
    if level == 0 then return 0 end
    return 500 + 2000 * level
end

function Taliyah:OnDraw()
    if self.menu:Get("draw.q") then
        SDK.Renderer:DrawCircle3D(myHero:GetPosition(), self.q1.range, Utils.COLOR_WHITE)
    end
    if QTracker:IsCastingQ1() then
        local dir = QTracker:GetQ1Direction()
        SDK.Renderer:DrawLine3D(myHero:GetPosition(), myHero:GetPosition() + dir * self.q1.range, Utils.COLOR_WHITE)
    end
    local level = myHero:GetSpell(SDK.Enums.SpellSlot.R):GetLevel()
    if level == 0 then return end
    if self.menu:Get("draw.r") then
        SDK.Renderer:DrawCircle3D(myHero:GetPosition(), self:GetRRange(), Utils.COLOR_WHITE)
    end
    if self.menu:Get("draw.rMinimap") then
        SDK.Renderer:DrawCircleMinimap(myHero:GetPosition(), self:GetRRange(), Utils.COLOR_WHITE)
    end

end

function Taliyah:CastQ1()
    local checkSpell = setmetatable({ width = self.Q1_WIDTH }, { __index = self.q1 })
    local _, checkPred = self.ts:GetTarget(checkSpell, nil, function(unit) return self.nem:IsTarget(unit) end)
    if not checkPred then return end
    local target, pred = self.ts:GetTarget(self.q1, nil, function(unit) return self.nem:IsTarget(unit) end)
    if not pred then return end
    if SDK.Input:Cast(SDK.Enums.SpellSlot.Q, pred.castPosition) then return true end
end

function Taliyah:Autofollow()
    local checkSpell = setmetatable({ delay = 0, width = self.Q1_WIDTH }, { __index = self.q1 })
    local res = Geometry.GetAutofollowPos(checkSpell, self.ts, QTracker:GetQ1Direction())
    if not res.pos then
        if SDK:GetPlatform() == "FF15" then
            ModernUOL:BlockAttack(false)
            ModernUOL:BlockMove(false)
        end
        return
    end
    SDK.Input:MoveTo(res.pos)
    if SDK:GetPlatform() == "FF15" then
        ModernUOL:BlockAttack(true)
        ModernUOL:BlockMove(true)
    end
    return true
    -- if not res.closeToCenter then
    --     SDK.Input:MoveTo(res.pos)
    --     if SDK:GetPlatform() == "FF15" then
    --         ModernUOL:BlockAttack(true)
    --         ModernUOL:BlockMove(true)
    --     end
    --     return true
    -- end
    -- if SDK:GetPlatform() == "FF15" then
    --     ModernUOL:BlockAttack(false)
    --     ModernUOL:BlockMove(true)
    -- end
    -- if myHero:AsAI():IsWindingUp() then

    --     return
    -- end
    -- SDK.Input:MoveTo(res.pos)
    -- return true
end

function Taliyah:CastQ2()
    local target, pred = self.ts:GetTarget(self.q2)
    if not pred or not pred.rates["slow"] then
        return
    end
    if not SDK.Input:Cast(SDK.Enums.SpellSlot.Q, pred.castPosition) then
        pred:Draw()
        return true
    end
    --TODO: AOE Q2
end

---@param to boolean
function Taliyah:CastW(to)
    local target, pred = self.ts:GetTarget(self.w, nil, function(unit) return self.nem:IsTarget(unit) end)
    if not pred or not pred.rates["slow"] then
        return
    end
    local endPos = to and myHero:GetPosition() or pred.castPosition + pred.castPosition - myHero:GetPosition()
    --TODO: add cast to E rocks
    if SDK.Input:Cast(SDK.Enums.SpellSlot.W, pred.castPosition, endPos) then
        pred:Draw()
        return true
    end
end

function Taliyah:CastE()
    local target, pred = self.ts:GetTarget(self.e)
    if not pred or not pred.rates["slow"] then
        return
    end
    if SDK.Input:Cast(SDK.Enums.SpellSlot.E, pred.castPosition) then
        pred:Draw()
        return true
    end
end

function Taliyah:CastAntiGapE()
    local target, pred = self.ts:GetTarget(self.e, nil, nil, function(unit, pred)
        local menuName = "antigap." .. unit:GetCharacterName()
        return pred and pred.targetDashing and self.menu:Get(menuName)
    end)
    if not pred then
        return
    end
    if SDK.Input:ForceCastFast(SDK.Enums.SpellSlot.E, pred.castPosition) then
        pred:Draw()
        return true
    end
end

function Taliyah:OnUpdate()
    self:CastSpells()
end

function Taliyah:CastSpells()
    local q = myHero:CanUseSpell(SDK.Enums.SpellSlot.Q) and self.slm:ShouldCast()
    local w = myHero:CanUseSpell(SDK.Enums.SpellSlot.W) and self.slm:ShouldCast()
    local e = myHero:CanUseSpell(SDK.Enums.SpellSlot.E) and self.slm:ShouldCast()

    local isGround = QTracker:IsGround()
    local isCombo = SDK.Libs.Orbwalker:IsComboMode()

    if e and self:CastAntiGapE() then return end

    if w and self.tm:GetSingleTap() and self:CastW(true) then return end
    if w and self.tm:GetDoubleTap() and self:CastW(false) then return end


    if not isGround and self.menu:Get("q.q") and q and self:CastQ1() then
        return
    end

    if isCombo then
        if isGround and q and self:CastQ2() then return end

        if QTracker:IsCastingQ1() then
            self:Autofollow()
        elseif SDK:GetPlatform() == "FF15" then
            ModernUOL:BlockAttack(false)
            ModernUOL:BlockMove(false)
        end
    end

end

Taliyah:__init()
