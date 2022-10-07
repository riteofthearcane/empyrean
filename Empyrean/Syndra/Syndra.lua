---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

---@class DREAM_TS_INITIALIZER
local DreamTSLib = _G.DreamTS or require("DreamTS")
local DreamTS = DreamTSLib.TargetSelectorSdk
local Utils = require("Common.Utils")
local SpellQueueManager = require("Common.SpellQueueManager")
local OrbManager = require("Syndra.OrbManager")
local Constants = require("Syndra.Constants")
local enemies = SDK.ObjectManager:GetEnemyHeroes()

local Syndra = {}

function Syndra:__init()
    self.version = "2.0"
    self:InitMenu()
    self:InitFields()
    self:InitEvents()
    SDK.PrintChat("Syndra - Empyrean loaded.")
end

function Syndra:InitFields()

    ---@type Empyrean.Syndra.OrbManager
    self.om = OrbManager()


    ---@type Empyrean.Common.SpellQueueManager
    self.sqm = SpellQueueManager({
        Q  = {
            names = {
                [1] = "SyndraQ",
                [2] = "SyndraQUpgrade"
            },
        },
        W1 = {
            name = "SyndraW",
        },
        W2 = {
            name = "SyndraWCast",
        },
        E  = {
            names = {
                [1] = "SyndraE",
                [2] = "SyndraE5"
            },

        },
        R  = {
            name = "SyndraR"
        }
    })

    self.ts =
    DreamTS(
        self.menu:GetChild("dreamTs"),
        {
            Damage = DreamTS.Damages.AP
        }
    )
end

function Syndra:InitMenu()
    self.menu = SDK.Libs.Menu("syndraEmpyrean", "Syndra - Empyrean")
    self.menu:AddLabel("Syndra - Empyrean v: " .. self.version, true)
    self.menu:AddSubMenu("dreamTs", "Target Selector")
    local qMenu = self.menu:AddSubMenu("q", "Q: Dark Sphere")
    qMenu:AddLabel("Cast Q in combo")
    local wMenu = self.menu:AddSubMenu("w", "W: Force of Will")
    wMenu:AddLabel("Cast W in combo")
    local eMenu = self.menu:AddSubMenu("e", "E: Scatter the Weak")
    eMenu:AddLabel("Use key without combo to stun using existing balls")
    eMenu:AddLabel("Use key with combo to stun with QE/WE/E")
    eMenu:AddKeybind("e", "E Key", string.byte("E"))
    local rMenu = self.menu:AddSubMenu("r", "R: Unleashed Power")
    rMenu:AddLabel("Cast R in combo if killable")
    rMenu:AddKeybind("disable", "Disable R Key", string.byte("Z"))

    local antigapMenu = self.menu:AddSubMenu("antigap", "Anti-Gap")
    antigapMenu:AddLabel("Cast QE/WE/E on anti-gap")
    for _, enemy in pairs(enemies) do
        local charName = enemy:GetCharacterName()
        antigapMenu:AddCheckbox(charName, charName, true)
    end
    local drawMenu = self.menu:AddSubMenu("draw", "Draw")
    drawMenu:AddCheckbox("q", "Draw Q range", true)
    drawMenu:AddCheckbox("e", "Draw E range", true)
    self.menu:AddKeybind("key", "Key", string.byte("W")) -- temp
    self.menu:Render()
end

function Syndra:InitEvents()
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnUpdate, function() self:OnUpdate() end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnDraw, function() self:OnDraw() end)
end

function Syndra:CastQ()
    local target, pred = self.ts:GetTarget(Constants.Q, nil, nil,
        function(unit, pred)
            -- anti feez pred
            return Utils.IsValidCircularPred(pred, Constants.Q)
        end)
    if not pred or not pred.rates["slow"] then
        return
    end
    if SDK.Input:Cast(SDK.Enums.SpellSlot.Q, pred.castPosition) then
        self.sqm:InvokeCastSpell("Q")
        pred:Draw()
        return true
    end
end

function Syndra:CastW2()
    local target, pred = self.ts:GetTarget(Constants.W, nil, nil,
        function(unit, pred)
            -- anti feez pred
            return Utils.IsValidCircularPred(pred, Constants.W)
        end) --TODO: check W blacklist for champs if enemy has been pushed by E
    if not pred or not pred.rates["slow"] then
        return
    end
    if SDK.Input:Cast(SDK.Enums.SpellSlot.W, pred.castPosition) then
        self.sqm:InvokeCastSpell("W2")
        pred:Draw()
        return true
    end

    -- TODO: wall checks
end

function Syndra:CastW1(predFunc)
    local grabTargetTable = self.om:GetGrabTarget()
    if not grabTargetTable then
        return
    end
    if SDK.Input:Cast(SDK.Enums.SpellSlot.W, grabTargetTable.pos) then
        self.sqm:InvokeCastSpell("W1")
        return true
    end
end

function Syndra:GetBestECastPos(orbPos, pos)
    -- TODO: finish this
    return pos
end

---@param enemy SDK_AIHeroClient
---@return SDK_DreamPred_Result | nil
function Syndra:GetQELongIterPred(enemy)
    local eMod = setmetatable({ delay = 0.35 }, { __index = Constants.E })
    local res = false
    local l = {}
    local pred = nil
    while not res do
        _, pred = self.ts:GetTarget(eMod, nil,
            function(unit) return unit:GetNetworkId() == enemy:GetNetworkId() end)
        if not pred then
            print("SYNDRA: Iterpred QE Long fail")
            return
        end
        local distToCast = myHero:GetPosition():Distance(pred.targetPosition)
        local distToCastCeil = math.ceil(distToCast, Constants.E_ORB_CONTACT_RANGE)
        eMod.speed = (Constants.E.speed * Constants.E_ORB_CONTACT_RANGE +
            Constants.E_PUSH_SPEED * (distToCastCeil - Constants.E_ORB_CONTACT_RANGE)) / distToCastCeil
        table.insert(l, eMod.speed)
        res = Utils.CheckForSame(l)
    end
    return pred
end

---@param pos SDK_VECTOR
---@return SDK_VECTOR
function Syndra:GetQELongQPos(pos)
    local diff = (pos - myHero:GetPosition()):Normalized()
    return myHero:GetPosition() + diff * Constants.E_ORB_CONTACT_RANGE
end

function Syndra:HasEPred()
    local target, pred = self.ts:GetTarget(Constants.E)
    return pred ~= nil
end

function Syndra:HasWPred()
    local target, pred = self.ts:GetTarget(Constants.W, nil, nil,
        function(unit, pred)
            -- anti feez pred
            return Utils.IsValidCircularPred(pred, Constants.W)
        end) --TODO: check W blacklist for champs if enemy has been pushed by E
    return pred ~= nil
end

function Syndra:CastQELong()
    local target, pred = self.ts:GetTarget(Constants.E)
    if not pred or not pred.rates["slow"] or
        myHero:GetPosition():Distance(pred.targetPosition) < Constants.E_ENEMY_CONTACT_RANGE then
        return
    end
    local iterPred = self:GetQELongIterPred(target)
    if not iterPred then return end
    local qPos = self:GetQELongQPos(iterPred.castPosition)
    local ePos = self:GetBestECastPos(nil, qPos)
    if SDK.Input:CastFast(SDK.Enums.SpellSlot.Q, qPos) and SDK.Input:CastFast(SDK.Enums.SpellSlot.E, ePos) then
        self.sqm:InvokeCastSpell("Q")
        self.sqm:InvokeCastSpell("E")
        iterPred:Draw()
        return true
    end
end

---@param pos SDK_VECTOR
---@return SDK_VECTOR
function Syndra:GetQEShortQPos(pos)
    local dist = pos:Distance(myHero:GetPosition())
    local pushDist = self:GetEPushDist(dist)
    local diff = (pos - myHero:GetPosition()):Normalized()
    return myHero:GetPosition() + diff * pushDist
end

---@param dist number
---@return number
function Syndra:GetEPushDist(dist)
    return math.min(Constants.Q.range, dist + Constants.E_ENEMY_PUSH_DIST) --use q range for now
end

---@param enemy SDK_AIHeroClient
---@return SDK_DreamPred_Result | nil
function Syndra:GetQEShortIterPred(enemy)
    local eMod = setmetatable({}, { __index = Constants.E })
    local res = false
    local l = {}
    local pred = nil
    while not res do
        _, pred = self.ts:GetTarget(eMod, nil,
            function(unit) return unit:GetNetworkId() == enemy:GetNetworkId() end)
        if not pred then
            print("SYNDRA: Iterpred QE Short fail with width - " .. eMod.width)
            return
        end
        local boundingRadius = enemy:GetBoundingRadius()
        -- local boundingRadius = 0
        local dist = pred.targetPosition:Distance(myHero:GetPosition())
        local pushDist = self:GetEPushDist(dist)
        eMod.width = (Constants.E.width + boundingRadius) * dist / pushDist - boundingRadius
        table.insert(l, eMod.width)
        res = Utils.CheckForSame(l)
    end
    print("SYNDRA E short IterPred width: " .. eMod.width)
    return pred
end

function Syndra:CanEShort(pred, target)
    -- wall check
    local interval = 50
    local startPos = pred.castPosition
    local startDist = startPos:Distance(myHero:GetPosition())
    local diff = (startPos - myHero:GetPosition()):Normalized()
    local endDist = self:GetEPushDist(startDist) + interval
    for i = startDist, endDist, interval do
        local pos = myHero:GetPosition() + diff * i
        if SDK.NavMesh:IsWall(pos) then
            return false
        end
    end

    -- cc check
    if _G.Prediction.IsImmobile(target, pred.interceptionTime) then
        return false
    end
    return true
end

function Syndra:CastQEShort()
    local target, pred = self.ts:GetTarget(Constants.E)
    if not pred or not pred.rates["slow"] or
        myHero:GetPosition():Distance(pred.targetPosition) > Constants.E_ENEMY_CONTACT_RANGE then
        return
    end
    local iterPred = self:GetQEShortIterPred(target)
    if not iterPred then return end
    if not self:CanEShort(iterPred, target) then return end
    local qPos = self:GetQEShortQPos(iterPred.castPosition)
    local ePos = self:GetBestECastPos(nil, qPos)
    if SDK.Input:CastFast(SDK.Enums.SpellSlot.Q, qPos) and SDK.Input:CastFast(SDK.Enums.SpellSlot.E, ePos) then
        print(myHero:GetPosition():Distance(iterPred.castPosition))
        self.sqm:InvokeCastSpell("Q")
        self.sqm:InvokeCastSpell("E")
        pred:Draw()
        return true
    end
end

function Syndra:CastWEShort()
    local target, pred = self.ts:GetTarget(Constants.E)
    if not pred or not pred.rates["slow"] or
        myHero:GetPosition():Distance(pred.targetPosition) > Constants.E_ENEMY_CONTACT_RANGE then
        return
    end
    local iterPred = self:GetQEShortIterPred(target)
    if not iterPred then return end
    if not self:CanEShort(iterPred, target) then return end
    local wPos = self:GetQEShortQPos(iterPred.castPosition)
    local ePos = self:GetBestECastPos(nil, wPos)
    if SDK.Input:CastFast(SDK.Enums.SpellSlot.W, wPos) and SDK.Input:CastFast(SDK.Enums.SpellSlot.E, ePos) then
        print('CastWEShort')
        print(myHero:GetPosition():Distance(iterPred.castPosition))
        self.sqm:InvokeCastSpell("W2")
        self.sqm:InvokeCastSpell("E")
        pred:Draw()
        return true
    end
end

function Syndra:CastWEShortInclGrab()
    local grabTargetTable = self.om:GetGrabTarget()
    local grabPos = grabTargetTable and grabTargetTable.isOrb and grabTargetTable.pos
    if not grabPos then return end
    local target, pred = self.ts:GetTarget(Constants.E)
    if not pred or not pred.rates["slow"] or
        myHero:GetPosition():Distance(pred.targetPosition) > Constants.E_ENEMY_CONTACT_RANGE then
        return
    end
    local iterPred = self:GetQEShortIterPred(target)
    if not iterPred then return end
    if not self:CanEShort(iterPred, target) then return end
    local wPos = self:GetQEShortQPos(iterPred.castPosition)
    local ePos = self:GetBestECastPos(nil, wPos)
    if SDK.Input:CastFast(SDK.Enums.SpellSlot.W, grabPos) and SDK.Input:CastFast(SDK.Enums.SpellSlot.W, wPos) and
        SDK.Input:CastFast(SDK.Enums.SpellSlot.E, ePos) then
        print('CastWEShort')
        print(myHero:GetPosition():Distance(iterPred.castPosition))
        self.sqm:InvokeCastSpell("W1")
        self.sqm:InvokeCastSpell("W2")
        self.sqm:InvokeCastSpell("E")
        pred:Draw()
        return true
    end
end

function Syndra:CastWELong()
    local target, pred = self.ts:GetTarget(Constants.E)
    if not pred or not pred.rates["slow"] or
        myHero:GetPosition():Distance(pred.targetPosition) < Constants.E_ENEMY_CONTACT_RANGE then
        return
    end
    local iterPred = self:GetQELongIterPred(target)
    if not iterPred then return end
    local wPos = self:GetQELongQPos(iterPred.castPosition)
    local ePos = self:GetBestECastPos(nil, wPos)
    if SDK.Input:CastFast(SDK.Enums.SpellSlot.W, wPos) and SDK.Input:CastFast(SDK.Enums.SpellSlot.E, ePos) then
        self.sqm:InvokeCastSpell("W2")
        self.sqm:InvokeCastSpell("E")
        iterPred:Draw()
        return true
    end
end

---@param slow boolean
---@
function Syndra:GetAntigapTarget(slow)
    local check = setmetatable({ width = slow and Constants.E.width + 0.2 or Constants.E.width },
        { __index = Constants.E })
    local target, pred = self.ts:GetTarget(check, nil, nil, function(unit, pred)
        return pred.targetDashing and self.menu:Get("antigap." .. unit:GetCharacterName())
    end)
    return target
end

function Syndra:OnDraw()
    if self.menu:Get("draw.q") then
        SDK.Renderer:DrawCircle3D(myHero:GetPosition(), Constants.Q.range, Utils.COLOR_WHITE)
    end
    if self.menu:Get("draw.e") then
        SDK.Renderer:DrawCircle3D(myHero:GetPosition(), Constants.E.range, Utils.COLOR_WHITE)
    end
end

function Syndra:OnUpdate()
    self:CastSpells()
end

function Syndra:CastSpells()
    local isCombo = SDK.Libs.Orbwalker:IsComboMode()
    local q = myHero:CanUseSpell(SDK.Enums.SpellSlot.Q) and self.sqm:ShouldCast()
    local isW1 = myHero:GetSpell(SDK.Enums.SpellSlot.W):GetName() == "SyndraW" and not self.om:GetHeld() and
        not self.om:IsSearchingForHeld()
    local isW2 = myHero:GetSpell(SDK.Enums.SpellSlot.W):GetName() == "SyndraWCast" and self.om:GetHeld()
    local w = myHero:CanUseSpell(SDK.Enums.SpellSlot.W) and self.sqm:ShouldCast() and (isW1 or isW2)
    local e = myHero:CanUseSpell(SDK.Enums.SpellSlot.E) and self.sqm:ShouldCast()

    local qMana = myHero:GetSpell(SDK.Enums.SpellSlot.Q):GetManaCost()
    local wMana = myHero:GetSpell(SDK.Enums.SpellSlot.W):GetManaCost()
    local eMana = myHero:GetSpell(SDK.Enums.SpellSlot.E):GetManaCost()
    local curMana = myHero:AsAttackableUnit():GetMana()

    -- antigap

    -- cast e without q/w if e held

    -- cast qe/we if combo and e held

    -- cast w if combo and e not waiting

    -- cast q if combo and e and w not waiting
    local hasE = self:HasEPred()
    local canQe = hasE and q and e and curMana > qMana + eMana
    local grabTargetTable = self.om:GetGrabTarget()
    local canGrabOrb = grabTargetTable and grabTargetTable.isOrb
    local canWe = hasE and w and e and curMana > wMana + eMana and
        (isW2 and (self.om:GetHeld() and self.om:GetHeld().isOrb) or canGrabOrb)
    local canE = canQe or canWe
    if isCombo then
        if self.menu:Get("e.e") and canE then
            if canWe then
                -- if isW1 and self:CastWEShortInclGrab() then return end
                if (isW2 and (self:CastWEShort() or self:CastWELong())) or (isW1 and self:CastW1()) then return end
            else
                if self:CastQEShort() or self:CastQELong() then return end
            end
        else
            if w and isW2 and self:CastW2() then return end
            if q and self:CastQ() then return end
            if w and isW1 and self:HasWPred() and self:CastW1() then return end
        end
    end
end

Syndra:__init()
