---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

local DreamLoader = require("Common.DreamLoader")
local DreamTS = DreamLoader.Api.TargetSelector
local Utils = require("Common.Utils")
local SpellLockManager = require("Common.SpellLockManager")
local NearestEnemyTracker = require("Common.NearestEnemyTracker")
local TapManager = require("Common.TapManager")
local CharmTracker = require("Ahri.CharmTracker")
local LastAutoTracker = require("Ahri.LastAutoTracker")
local LevelTracker = require("Common.LevelTracker")

local enemies = SDK.ObjectManager:GetEnemyHeroes()

local Ahri = {}

function Ahri:__init()
    self.version = "2.0"
    self:InitMenu()
    self:InitFields()
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


    ---@type Empyrean.Common.SpellLockManager
    self.slm = SpellLockManager()
    ---@type Empyrean.Common.NearestEnemyTracker
    self.nem = NearestEnemyTracker()
    ---@type Empyrean.Ahri.CharmTracker
    self.cm = CharmTracker()
    ---@type Empyrean.Ahri.LastAutoTracker
    self.lat = LastAutoTracker()
    ---@type Empyrean.Common.LevelTracker
    self.lt = LevelTracker()

    ---@type Empyrean.Common.TapManager
    self.tm = TapManager(
        function() return self.menu:Get("e.useTap") and self.menu:Get("e.eTap") end,
        function() return not self.menu:Get("e.useTap") and self.menu:Get("e.e") end,
        function() return not self.menu:Get("e.useTap") and self.menu:Get("e.eFlash") end
    )


    self.ts =
    DreamTS(
        self.menu:GetChild("dreamTs"),
        {
            Damage = DreamTS.Damages.AP
        }
    )
end

function Ahri:InitMenu()
    self.menu = SDK.Libs.Menu("ahriEmpyrean", "Ahri - Empyrean")
    self.menu:AddLabel("Ahri - Empyrean v: " .. self.version, true)
    self.menu:AddSubMenu("dreamTs", "Target Selector")
    local qMenu = self.menu:AddSubMenu("q", "Q: Orb of Deception")
    qMenu:AddLabel("Cast Q on charmed targets in combo")
    qMenu:AddLabel("Cast Q by hovering mouse over enemy and pressing key")
    qMenu:AddKeybind("q", "Q Key", string.byte("Q"))
    local wMenu = self.menu:AddSubMenu("w", "W: Fox-fire")
    wMenu:AddLabel("Cast W on charmed or last attacked targets in combo")
    local eMenu = self.menu:AddSubMenu("e", "E: Charm")
    eMenu:AddCheckbox("useTap", "Cast E/E Flash by single or double tapping key", false)
    eMenu:AddKeybind("eTap", "E Tap Key", string.byte("E"))
    eMenu:AddLabel("Alternatively use separate keys (disabled if above toggle on)")
    eMenu:AddKeybind("e", "E Key", string.byte("E"))
    eMenu:AddKeybind("eFlash", "E Flash Key", string.byte("E"))
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
    drawMenu:AddCheckbox("e", "Draw E range", true)
    self.menu:Render()
end

function Ahri:InitEvents()
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnUpdate, function() self:OnUpdate() end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnDraw, function() self:OnDraw() end)
end

function Ahri:OnDraw()
    if self.menu:Get("draw.e") then
        SDK.Renderer:DrawCircle3D(myHero:GetPosition(), self.e.range, Utils.COLOR_WHITE)
    end
end

function Ahri:CastQ(unitFunc)
    local target, pred = self.ts:GetTarget(self.q, nil,
        function(unit)
            return unitFunc(unit)
        end,
        function(unit, pred)
            return pred.rates["slow"]
        end, self.ts.Modes["Closest To Mouse"])
    if not pred then
        return
    end
    if SDK.Input:Cast(SDK.Enums.SpellSlot.Q, pred.castPosition) then
        pred:Draw()
        return true
    end
end

function Ahri:CastW()
    local charm = self.cm:GetClosestValidTarget()
    local validCharmedTarget = charm and myHero:GetPosition():Distance(charm:GetPosition()) < self.w.range - 25

    local auto = self.lat:GetLastAutoedEnemy()
    local validAutoedTarget = auto and Utils.IsValidTarget(auto) and
        myHero:GetPosition():Distance(auto:GetPosition()) < self.w.range - 25

    if validCharmedTarget or validAutoedTarget and SDK.Input:Cast(SDK.Enums.SpellSlot.W, myHero) then
        return true
    end
end

function Ahri:CastE()
    local target, pred = self.ts:GetTarget(self.e, nil, nil, function(unit, pred)
        return self.nem:IsTarget(unit) and pred.rates["slow"]
    end, self.ts.Modes["Closest To Mouse"])
    if not pred then
        return
    end
    if SDK.Input:Cast(SDK.Enums.SpellSlot.E, pred.castPosition) then
        pred:Draw()
        return true
    end
end

function Ahri:CastEFlash()
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

function Ahri:CastAntiGapE()
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

function Ahri:GetEfSlot()
    return Utils.GetItemSlot("6656cast")
end

function Ahri:CastEf()
    local target, pred = self.ts:GetTarget(self.ef, nil, nil, function(unit, pred)
        return self.nem:IsTarget(unit) and pred.rates["slow"]
    end, self.ts.Modes["Closest To Mouse"])
    if not pred then
        return
    end
    local slot = self:GetEfSlot()
    if SDK.Input:Cast(slot, pred.castPosition) then
        pred:Draw()
        return true
    end
end

function Ahri:CastAntiGapEf()
    local target, pred = self.ts:GetTarget(self.ef, nil, nil, function(unit, pred)
        local menuName = "antigap." .. unit:GetCharacterName()
        return pred and pred.targetDashing and self.menu:Get(menuName)
    end)
    if not pred then
        return
    end
    local slot = self:GetEfSlot()
    if SDK.Input:ForceCastFast(slot, pred.castPosition) then
        pred:Draw()
        return true
    end
end

function Ahri:CastEfCc()
    ---@param unit SDK_AIHeroClient
    ---@param pred SDK_DreamPred_Result
    local checkFunc = function(unit, pred)
        local buffTypes = {
            [SDK.Enums.BuffType.Charm] = true,
            [SDK.Enums.BuffType.Fear] = true,
            [SDK.Enums.BuffType.Knockup] = true,
            [SDK.Enums.BuffType.Knockback] = true,
            [SDK.Enums.BuffType.Stun] = true,
            [SDK.Enums.BuffType.Suppression] = true,
            [SDK.Enums.BuffType.Taunt] = true,
        }

        local immobileBuffs = {
            ["chronorevive"] = true,
            ["zhonyasringshield"] = true
        }

        local ignoredBuffs = {
            ["threshq"] = true,
            ["rocketgrab2"] = true,
            ["rocketgrab"] = true
        }

        local buffs = unit:GetBuffs()
        local res = 0
        for i = 1, #buffs do
            local buff = buffs[i]
            if buff then
                local buffName = buff:GetName():lower()
                local buffType = buff:GetType()
                if (immobileBuffs[buffName] or buffTypes[buffType]) and not ignoredBuffs[buffName] then
                    res = math.max(buff:GetRemainingTime(), res)
                end
            end
        end
        if pred.interceptionTime < res and pred.interceptionTime + 0.1 > res then
            return true
        end
    end
    local target, pred = self.ts:GetTarget(self.ef, nil, nil, checkFunc, self.ts.Modes["Closest To Mouse"])
    if not pred then
        return
    end
    local slot = self:GetEfSlot()
    if SDK.Input:Cast(slot, pred.castPosition) then
        pred:Draw()
        return true
    end
end

function Ahri:OnUpdate()
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
    local slot = Utils.GetSummonerSlot("summonerflash")
    local f = slot and myHero:CanUseSpell(slot)
    if f and SDK.Input:Cast(slot, self.flashQueue.pos) then
        self.flashQueue.pos = nil
        self.flashQueue.time = nil
        return true
    end
end

function Ahri:CastSpells()
    local evade = _G.DreamEvade and _G.DreamEvade.HasPath()
    local q = myHero:CanUseSpell(SDK.Enums.SpellSlot.Q) and self.slm:ShouldCast() and
        not Utils.IsMyHeroDashing() and not evade
    local w = myHero:CanUseSpell(SDK.Enums.SpellSlot.W) and self.slm:ShouldCastSpell(SDK.Enums.SpellSlot.W)
    local e = myHero:CanUseSpell(SDK.Enums.SpellSlot.E) and self.slm:ShouldCast() and
        not Utils.IsMyHeroDashing()
    local efSlot = self:GetEfSlot()
    local ef = efSlot and myHero:CanUseSpell(efSlot) and self.slm:ShouldCast()
    if e and self:CastAntiGapE() then
        return
    end

    if not e and ef and self:CastAntiGapEf() then
        return
    end

    if e and self.tm:GetSingleTap() and self.lt:ShouldCast() and self:CastE() then
        return
    end

    local slot = Utils.GetSummonerSlot("summonerflash")
    local f = slot and myHero:CanUseSpell(slot)
    if e and f and self.lt:ShouldCast() and self.tm:GetDoubleTap() and self:CastEFlash() then
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
        return (self.menu:Get("q.q") and self.lt:ShouldCast() and self.nem:IsTarget(unit)) or
            (isCombo and self.cm:IsCharm(unit))
    end) then
        return
    end


end

Ahri:__init()
