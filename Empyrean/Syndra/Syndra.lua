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
local LevelTracker = require("Common.LevelTracker")
local OrbManager = require("Syndra.OrbManager")
local Constants = require("Syndra.Constants")
local Geometry = require("Common.Geometry")
local enemies = SDK.ObjectManager:GetEnemyHeroes()
local LineSegment = require("LeagueSDK.Api.Common.LineSegment")
local ModernUOL = SDK:GetPlatform() == "FF15" and require("ModernUOL") or nil
local Debug = require("Common.Debug")

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

    ---@type Empyrean.Common.NearestEnemyTracker
    self.nem = NearestEnemyTracker()

    ---@type Empyrean.Common.SpellLockManager
    self.slm = SpellLockManager({
        SyndraW = 0.25,
    })
    ---@type Empyrean.Common.LevelTracker
    self.lt = LevelTracker()

    self.ts =
    DreamTS(
        self.menu:GetChild("dreamTs"),
        {
            Damage = DreamTS.Damages.AP
        }
    )
    -- last tick r key state (whether key was pressed or not)
    self.prevToggle = false
    -- last tick r.toggle state (whether to use toggle or key)
    self.prevMenuToggle = false
    -- r toggle state
    self.toggleState = false

    self.playerPos = myHero:GetPosition()

    self.debugText = ""
end

function Syndra:InitMenu()
    self.menu = SDK.Libs.Menu("syndraEmpyrean", "Syndra - Empyrean")
    self.menu:AddLabel("Syndra - Empyrean v: " .. self.version, true)
    self.menu:AddSubMenu("dreamTs", "Target Selector")
    local qMenu = self.menu:AddSubMenu("q", "Q: Dark Sphere")
    qMenu:AddLabel("Cast Q in combo or harass")
    local wMenu = self.menu:AddSubMenu("w", "W: Force of Will")
    wMenu:AddLabel("Cast W in combo")
    wMenu:AddLabel("Cast W1 on unkillable targets in lasthit")
    local eMenu = self.menu:AddSubMenu("e", "E: Scatter the Weak")
    eMenu:AddKeybind("e1", "QE/WE/E Key", string.byte("E"))
    eMenu:AddKeybind("e2", "E Key", string.byte("T"))
    eMenu:AddLabel("Use LMB to cast with mouse targeting")
    local rMenu = self.menu:AddSubMenu("r", "R: Unleashed Power")
    rMenu:AddLabel("Use LMB to cast R to execute")
    rMenu:AddKeybind("rExecute", "Use key of choice to cast R to execute", string.byte("A"))
    rMenu:AddCheckbox("toggle", "Use LMB/above key as toggle", false)
    rMenu:AddLabel("If above is toggle, will turn off after r usage")
    rMenu:AddKeybind("r", "R Key (closest enemy inside reticle)", string.byte("R"))
    rMenu:AddSlider("circle", "R aim circle radius", { min = 100, max = 500, default = 200, step = 100 })
    local antigapMenu = self.menu:AddSubMenu("antigap", "Anti-Gap")
    antigapMenu:AddLabel("Cast QE/WE on anti-gap")
    for _, enemy in pairs(enemies) do
        local charName = enemy:GetCharacterName()
        local charMenu = antigapMenu:AddSubMenu(charName, charName)
        charMenu:AddCheckbox("stun", "QE/WE Stun", true)
        charMenu:AddCheckbox("push", "E Push", false)

    end
    local drawMenu = self.menu:AddSubMenu("draw", "Draw")
    drawMenu:AddCheckbox("q", "Draw Q range", true)
    drawMenu:AddCheckbox("e", "Draw E range", true)
    drawMenu:AddCheckbox("rCircle", "Draw R aim circle", false)
    drawMenu:AddCheckbox("rUsage", "Draw R usage", true)
    self.menu:Render()
end

function Syndra:InitEvents()
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnUpdate, function() self:OnUpdate() end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnDraw, function() self:OnDraw() end)
end

function Syndra:CastQ()
    local target, pred = self.ts:GetTarget(Constants.Q)
    if not pred or not pred.rates["slow"] then return end
    if not SDK.Input:Cast(SDK.Enums.SpellSlot.Q, pred.castPosition) then return end
    pred:Draw()
    return true
end

---@param enemy SDK_AIHeroClient
---@return SDK_DreamPred_Result | nil
function Syndra:GetW2IterPred(enemy)
    local obj = self.om:GetHeld().obj
    local src = Utils.GetSourcePosition(obj:AsHero())
    local wMod = setmetatable({}, { __index = Constants.W })
    local res = false
    local l = {}
    local pred = nil
    while not res do
        _, pred = self.ts:GetTarget(wMod, nil,
            function(unit) return unit:GetNetworkId() == enemy:GetNetworkId() end)
        if not pred then
            SDK.PrintChat("SYNDRA: Iterpred W2 Long fail")
            return
        end
        local distToCast = src:Distance(pred.targetPosition)
        wMod.speed = math.max(math.min(distToCast, 1500), 200)
        table.insert(l, wMod.speed)
        res = Utils.CheckForSame(l)
    end
    SDK.PrintChat("W SPEED: " .. wMod.speed)
    SDK.PrintChat("DIST TO CAST: " .. src:Distance(pred.castPosition))
    Debug.RegisterDraw(function() SDK.Renderer:DrawCircle3D(pred.castPosition, 150, Utils.COLOR_RED) end, 5)
    Debug.RegisterDraw(function() SDK.Renderer:DrawCircle3D(src, 150, Utils.COLOR_RED) end, 5)
    return pred
end

function Syndra:CastW2()
    -- local target, pred = self.ts:GetTarget(Constants.W) --TODO: check W blacklist for champs if enemy has been pushed by E
    -- if not pred or not pred.rates["slow"] then
    --     return
    -- end
    -- local iterPred = self:GetW2IterPred(target)
    -- if not iterPred then return end
    -- if not SDK.Input:Cast(SDK.Enums.SpellSlot.W, iterPred.castPosition) then
    --     return
    -- end
    -- iterPred:Draw()
    -- return true
    -- -- TODO: wall checks
end

function Syndra:CastW2Old()
    local W = {
        type = "circular",
        range = 950,
        speed = math.huge,
        delay = 0.75,
        radius = 220,
        useHeroSource = true,
    }
    local target, pred = self.ts:GetTarget(W) --TODO: check W blacklist for champs if enemy has been pushed by E
    if not pred or not pred.rates["slow"] then
        return
    end
    if not SDK.Input:Cast(SDK.Enums.SpellSlot.W, pred.castPosition) then
        return
    end
    pred:Draw()
    return true
    -- TODO: wall checks
end

function Syndra:CastW1()
    local grabTargetTable = self.om:GetGrabTarget()
    if not grabTargetTable then
        self.debugText = self.debugText .. "No grab target\n"
        return
    end
    if not SDK.Input:Cast(SDK.Enums.SpellSlot.W, grabTargetTable.pos) then
        self.debugText = self.debugText .. "Failed w1 cast\n"
        return
    end
    return true
end

function Syndra:GetQEAoeEPos(qPos)
    local posTable = {}
    table.insert(posTable, { pos = qPos, isPrio = true })
    local orbPosTable = self.om:GetEHitOrbs()
    for _, orbPos in pairs(orbPosTable) do
        table.insert(posTable, { pos = orbPos, isPrio = false })
    end
    local res = Geometry.BestAoeConic(self.playerPos, Constants.E_ORB_CONTACT_RANGE, Constants:GetEAngle(),
        posTable)
    if not res then
        print('WTF no EPOS')
    end
    return res.pos
end

---@param enemy SDK_AIHeroClient
---@return SDK_DreamPred_Result | nil
function Syndra:GetQELongIterPred(enemy)
    local eMod = setmetatable({}, { __index = Constants.E })
    local res = false
    local l = {}
    local pred = nil
    while not res do
        _, pred = self.ts:GetTarget(eMod, nil,
            function(unit) return unit:GetNetworkId() == enemy:GetNetworkId() end)
        if not pred then
            SDK.PrintChat("SYNDRA: Iterpred QE Long fail")
            return
        end
        local distToCast = self.playerPos:Distance(pred.targetPosition)
        local distToCastCeil = math.max(distToCast, Constants.E_ORB_CONTACT_RANGE)
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
    local diff = (pos - self.playerPos):Normalized()
    return self.playerPos + diff * Constants.E_ORB_CONTACT_RANGE
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
    self.debugText = self.debugText .. "in QE long\n"
    local closest = self.nem:GetTarget()
    if SDK.Keyboard:IsKeyDown(0x01) and not closest then return end
    local target, pred = self.ts:GetTarget(Constants.E, nil,
        function(unit) return not SDK.Keyboard:IsKeyDown(0x01) or closest:GetNetworkId() == unit:GetNetworkId() end)
    if not pred or not pred.rates["slow"] or
        self.playerPos:Distance(pred.targetPosition) < Constants.E_ENEMY_CONTACT_RANGE then
        return
    end
    self.debugText = self.debugText .. "passed first check in QE long\n"
    local iterPred = self:GetQELongIterPred(target)
    if not iterPred then return end
    local qPos = self:GetQELongQPos(iterPred.castPosition)
    local ePos = self:GetQEAoeEPos(qPos)
    if SDK.Input:CastFast(SDK.Enums.SpellSlot.Q, qPos) and SDK.Input:CastFast(SDK.Enums.SpellSlot.E, ePos) then
        iterPred:Draw()
        return true
    else
        print("SYNDRA: Cast QEShort fail")
    end
end

function Syndra:GetQEShortIterPred(enemy)
    local eMod = setmetatable({}, { __index = Constants.E })
    local res = false
    local l = {}
    local pred = nil
    local pushDist = 0
    while not res do
        _, pred = self.ts:GetTarget(eMod, nil,
            function(unit) return unit:GetNetworkId() == enemy:GetNetworkId() end)
        if not pred then
            SDK.PrintChat("SYNDRA: Iterpred QE Short fail with width - " .. eMod.width)
            return nil, nil
        end
        local boundingRadius = enemy:GetBoundingRadius()
        -- local boundingRadius = 0
        local dist = pred.targetPosition:Distance(self.playerPos)
        pushDist = self:GetEPushDist(pred)
        eMod.width = (Constants.E.width + boundingRadius) * dist / pushDist - boundingRadius
        table.insert(l, eMod.width)
        res = Utils.CheckForSame(l)
    end
    return pred, pushDist
end

function Syndra:CastQEShort()
    local target, pred = self.ts:GetTarget(Constants.E, nil,
        function(unit) return not SDK.Keyboard:IsKeyDown(0x01) or self.nem:IsTarget(unit) end)
    self.debugText = self.debugText .. "looking at QE short\n"
    if not pred then
        self.debugText = self.debugText .. "no pred\n"
    end
    if not pred.rates["slow"] then
        self.debugText = self.debugText .. "no short rate\n"
    end
    if not pred.rates["slow"] or self.playerPos:Distance(pred.targetPosition) > Constants.E_ENEMY_CONTACT_RANGE then
        self.debugText = self.debugText .. "no short rate or too far\n"
    end
    if not pred or not pred.rates["slow"] or
        self.playerPos:Distance(pred.targetPosition) > Constants.E_ENEMY_CONTACT_RANGE then
        return
    end
    self.debugText = self.debugText .. "passed first check in QE short\n"

    local iterPred, pushDist = self:GetQEShortIterPred(target)
    if not iterPred then return end
    local qPos = self.playerPos + (iterPred.castPosition - self.playerPos):Normalized() * pushDist
    local ePos = self:GetQEAoeEPos(qPos)
    if SDK.Input:CastFast(SDK.Enums.SpellSlot.Q, qPos) and SDK.Input:CastFast(SDK.Enums.SpellSlot.E, ePos) then
        pred:Draw()
        return true
    else
        print("SYNDRA: Cast QEShort fail")
    end
end

---@param pos SDK_VECTOR
---@return number
function Syndra:GetEPushDist(pred)
    local dist = pred.targetPosition:Distance(self.playerPos)
    local pushDist = math.min(Constants.Q.range, dist + Constants.E_ENEMY_PUSH_DIST)
    local interval = 50
    local startDist = pred.castPosition:Distance(self.playerPos)
    local diff = (pred.castPosition - self.playerPos):Normalized()
    local endDist = Constants.Q.range
    for i = startDist, endDist, interval do
        local pos = self.playerPos + diff * i
        if SDK.NavMesh:IsWall(pos) then
            pushDist = math.min(pushDist, i - interval)
            break
        end
    end
    return pushDist
end

function Syndra:CastQEAntigap()
    local target, pred = self.ts:GetTarget(Constants.E, nil, nil,
        function(unit, pred) return pred.targetDashing and
                self.playerPos:Distance(pred.targetPosition) < Constants.E_ENEMY_CONTACT_RANGE and
                self.menu:Get("antigap." .. unit:GetCharacterName() .. ".stun")
        end)
    if not pred then
        return
    end
    local pushDist = self:GetEPushDist(pred)
    local qPos = self.playerPos + (pred.castPosition - self.playerPos):Normalized() * pushDist
    local ePos = self:GetQEAoeEPos(qPos)
    if SDK.Input:ForceCastFast(SDK.Enums.SpellSlot.Q, qPos) and SDK.Input:ForceCastFast(SDK.Enums.SpellSlot.E, ePos) then
        pred:Draw()
        return true
    else
        print("CAST QE ANTIGAP FAIL")
    end
end

function Syndra:CastWEShort()
    local target, pred = self.ts:GetTarget(Constants.E)
    if not pred or not pred.rates["slow"] or
        self.playerPos:Distance(pred.targetPosition) > Constants.E_ENEMY_CONTACT_RANGE then
        return
    end
    local iterPred, pushDist = self:GetQEShortIterPred(target)
    if not iterPred then return end
    local wPos = self.playerPos + (iterPred.castPosition - self.playerPos):Normalized() * pushDist
    local ePos = self:GetQEAoeEPos(wPos)
    if SDK.Input:CastFast(SDK.Enums.SpellSlot.W, wPos) and SDK.Input:CastFast(SDK.Enums.SpellSlot.E, ePos) then
        pred:Draw()
        return true
    else
        print("SYNDRA: Cast WEShort fail")
    end
end

function Syndra:CastWEAntigap()
    local target, pred = self.ts:GetTarget(Constants.E, nil, nil,
        function(unit, pred) return pred.targetDashing and
                self.playerPos:Distance(pred.targetPosition) < Constants.E_ENEMY_CONTACT_RANGE and
                self.menu:Get("antigap." .. unit:GetCharacterName() .. ".stun")
        end)
    if not pred then
        return
    end
    local pushDist = self:GetEPushDist(pred)
    local wPos = self.playerPos + (pred.castPosition - self.playerPos):Normalized() * pushDist
    local ePos = self:GetQEAoeEPos(wPos)
    if SDK.Input:ForceCastFast(SDK.Enums.SpellSlot.W, wPos) and SDK.Input:ForceCastFast(SDK.Enums.SpellSlot.E, ePos) then
        pred:Draw()
        return true
    else
        print("CAST WE ANTIGAP FAIL")
    end
end

-- function Syndra:CastWWEAntigap()
--     local grabTargetTable = self.om:GetGrabTarget()
--     local canGrabOrb = grabTargetTable and grabTargetTable.isOrb
--     if not canGrabOrb then return end
--     local target, pred = self.ts:GetTarget(Constants.E, nil, nil,
--         function(unit, pred) return pred.targetDashing and
--                 self.playerPos:Distance(pred.targetPosition) < 250 and
--                 self.menu:Get("antigap." .. unit:GetCharacterName())
--         end)
--     if not pred then
--         return
--     end
--     local wPos = self:GetQEShortQPos(pred.castPosition)
--     local ePos = self:GetQEAoeEPos(wPos)
--     if SDK.Input:ForceCastFast(SDK.Enums.SpellSlot.W, grabTargetTable.pos) and
--         SDK.Input:ForceCastFast(SDK.Enums.SpellSlot.W, wPos) and SDK.Input:ForceCastFast(SDK.Enums.SpellSlot.E, ePos) then
--         pred:Draw()
--         SDK.PrintChat("WWE ANTIGAP")
--         SDK.PrintChat("orb to cast: " .. wPos:Distance(grabTargetTable.pos))
--         SDK.PrintChat("hero to cast: " .. wPos:Distance(self.playerPos))
--         SDK.PrintChat("hero to pred: " .. pred.castPosition:Distance(self.playerPos))
--         return true
--     else
--         print("CAST WE ANTIGAP FAIL")
--     end
-- end

function Syndra:CastWELong()
    local closest = self.nem:GetTarget()
    if SDK.Keyboard:IsKeyDown(0x01) and not closest then return end
    local target, pred = self.ts:GetTarget(Constants.E, nil,
        function(unit) return not SDK.Keyboard:IsKeyDown(0x01) or closest:GetNetworkId() == unit:GetNetworkId() end)
    if not pred or not pred.rates["slow"] or
        self.playerPos:Distance(pred.targetPosition) < Constants.E_ENEMY_CONTACT_RANGE then
        return
    end
    local iterPred = self:GetQELongIterPred(target)
    if not iterPred then return end
    local wPos = self:GetQELongQPos(iterPred.castPosition)
    local ePos = self:GetQEAoeEPos(wPos)
    if SDK.Input:CastFast(SDK.Enums.SpellSlot.W, wPos) and SDK.Input:CastFast(SDK.Enums.SpellSlot.E, ePos) then
        iterPred:Draw()
        return true
    else
        print("SYNDRA: Cast WELong fail")
    end
end

function Syndra:CastEAntigap()
    local target, pred = self.ts:GetTarget(Constants.E, nil, nil,
        function(unit, pred) return pred.targetDashing and
                self.playerPos:Distance(pred.targetPosition) < Constants.E_ENEMY_CONTACT_RANGE and
                self.menu:Get("antigap." .. unit:GetCharacterName() .. ".push")
        end)
    if not pred then
        return
    end
    local qPos = self:GetQEShortQPos(pred.castPosition)
    local ePos = self:GetQEAoeEPos(qPos)
    if SDK.Input:ForceCastFast(SDK.Enums.SpellSlot.E, ePos) then
        pred:Draw()
        return true
    else
        print("CAST E ANTIGAP FAIL")
    end
end

function Syndra:OnDraw()
    SDK.Renderer:DrawText(self.debugText, 20, SDK.Renderer:WorldToScreen(self.playerPos, 0), Utils.COLOR_WHITE)
    local color = self.toggleState and Utils.COLOR_GREEN or Utils.COLOR_WHITE
    if self.menu:Get("draw.q") then
        SDK.Renderer:DrawCircle3D(self.playerPos, Constants.Q.range, color)
    end
    if self.menu:Get("draw.e") then
        -- local color = self.menu:Get("e.e1") and Utils.COLOR_RED or Utils.COLOR_WHITE
        SDK.Renderer:DrawCircle3D(self.playerPos, Constants.E.range, color)
        SDK.Renderer:DrawCircle3D(self.playerPos, Constants.W.range + Constants.W_TARGET_RANGE, color)

    end
    if self.menu:Get("draw.rCircle") then
        SDK.Renderer:DrawCircle3D(SDK.Renderer:GetMousePos3D(), self.menu:Get("r.circle"), color)
    end
end

function Syndra:CastAntigap(canQe, canWe, e)

    if not canQe and not canWe and not e then return end
    local hasOrb = self.om:GetHeld() and self.om:GetHeld().isOrb
    local isW1 = myHero:GetSpell(SDK.Enums.SpellSlot.W):GetName() == "SyndraW" and not self.om:GetHeld() and
        not self.om:IsSearchingForHeld()
    if canWe and hasOrb and self:CastWEAntigap() then
        return true
    end
    -- if canWe and isW1 and self:CastWWEAntigap() then
    --     return true
    -- end
    if canQe and self:CastQEAntigap() then
        return true
    end
    if e and self:CastEAntigap() then
        return
    end
end

---@param enemy SDK_AIHeroClient
---@return SDK_DreamPred_Result | nil
function Syndra:GetEPushIterPred(enemy, orbPos)
    local eMod = setmetatable({}, { __index = Constants.E })
    local orbDist = orbPos:Distance(self.playerPos)
    local res = false
    local l = {}
    local pred = nil
    while not res do
        _, pred = self.ts:GetTarget(eMod, nil,
            function(unit) return unit:GetNetworkId() == enemy:GetNetworkId() end)
        if not pred then
            return
        end
        local distToCast = self.playerPos:Distance(pred.targetPosition)
        if distToCast < orbDist - Constants.E.width / 2 then
            return
        end
        eMod.speed = (Constants.E.speed * orbDist +
            Constants.E_PUSH_SPEED * (distToCast - orbDist)) / distToCast
        table.insert(l, eMod.speed)
        res = Utils.CheckForSame(l)
    end
    return pred
end

function Syndra:CastE()
    local orbPosTable = self.om:GetEHitOrbs()
    local srcPos = self.playerPos
    local hitPosTable = {}
    if #orbPosTable == 0 then return end
    local targets, preds = self.ts:GetTargets(Constants.E)
    if #targets == 0 then return end
    local hasOnePrio = false
    for _, orbPos in ipairs(orbPosTable) do
        if orbPos:Distance(self.playerPos) < Constants.E_ORB_CONTACT_RANGE + 0.01 then
            local hasTarget, isPrio = false, false
            local diff = (orbPos - srcPos):Normalized()
            local seg = LineSegment(srcPos + diff * Constants.E.range, srcPos)
            for _, target in ipairs(targets) do
                local pred = self:GetEPushIterPred(target, orbPos)
                if pred then
                    local prioDistLimit = pred.realHitChance == 1 and Constants.E.width or Constants.E.width / 2
                    local dist = seg:DistanceTo(pred.targetPosition)
                    if dist < prioDistLimit / 2 + target:GetBoundingRadius() and pred.rates["slow"] then
                        hasTarget, isPrio, hasOnePrio = true, true, true
                    elseif dist < Constants.E.width / 2 + target:GetBoundingRadius() then
                        hasTarget = true
                    end
                end
            end
            if hasTarget then
                table.insert(hitPosTable, { pos = orbPos, isPrio = isPrio })
            end
        end
    end
    if not hasOnePrio then return end
    if #hitPosTable == 0 then return end
    local res = Geometry.BestAoeConic(self.playerPos, Constants.E_ORB_CONTACT_RANGE, Constants:GetEAngle(),
        hitPosTable)
    if not res then
        print('WTF no EPOS')
    end
    if not SDK.Input:Cast(SDK.Enums.SpellSlot.E, res.pos) then return end
    return true
end

function Syndra:CastR()
    local target = self.nem:GetClosestEnemyToMouse()
    if not target or not Utils.IsValidTarget(target) then return end
    if SDK.Renderer:GetMousePos3D():Distance(target:GetPosition()) > self.menu:Get("r.circle") then return end
    if SDK.Input:Cast(SDK.Enums.SpellSlot.R, target) then return true end
end

function Syndra:CastRExecute()
    local targets = self.ts:Evaluate({
        ValidTarget = function(unit)
            return Utils.IsValidTarget(unit) and unit:GetPosition():Distance(self.playerPos) < Constants.R_RANGE
        end
    }).Targets
    for _, target in ipairs(targets) do
        if self:CanExecuteR(target) and
            SDK.Input:Cast(SDK.Enums.SpellSlot.R, target) then
            return true
        end
    end
end

function Syndra:GetRDamage()
    local ammo = myHero:GetSpell(SDK.Enums.SpellSlot.R):GetAmmo()
    local level = myHero:GetSpell(SDK.Enums.SpellSlot.R):GetLevel()
    return ammo * (0.17 * myHero:GetTotalAP() + 50 + 40 * level)
end

function Syndra:CanExecuteR(target)
    local damage = SDK.Libs.Damage:GetMagicalDamage(myHero, target, self:GetRDamage())
    local remainingHealth = target:GetHealth() + target:GetShieldAll() - damage
    return remainingHealth < 0 or (self:IsRUpgraded() and remainingHealth / target:GetMaxHealth() < 0.15)
end

function Syndra:IsRUpgraded()
    return self:GetPassiveStacks() >= 100
end

function Syndra:ComputeRTriggerState()
    local rToggleState = self.menu:Get("r.toggle")
    local rKeyState = self.menu:Get("r.rExecute") or SDK.Keyboard:IsKeyDown(0x01)
    local res = false

    if rToggleState ~= self.prevMenuToggle then
        self.toggleState = false
    else
        if not rToggleState then
            res = rKeyState
            self.toggleState = rKeyState
        else
            if rKeyState and not self.prevToggle then
                self.toggleState = not self.toggleState
            end
            res = self.toggleState
        end
    end
    self.prevMenuToggle = rToggleState
    self.prevToggle = rKeyState
    return res
end

function Syndra:GetPassiveStacks()
    local buff = myHero:GetBuff("syndrapassivestacks")
    return buff and buff:GetStacks() or 0
end

function Syndra:LastHitUnkillableW1()
    if not ModernUOL then return end
    local range = myHero:AsAI():GetAttackRange() + myHero:GetBoundingRadius() + 55
    local target = ModernUOL:GetSpellFarmTarget({ range = range, speed = math.huge, delay = 0, type = "AD" }, math.huge,
        true)
    if not target then return end
    local targetSdk = SDK.Types.AIBaseClient(target)
    if not SDK.Input:Cast(SDK.Enums.SpellSlot.W, targetSdk:GetPosition()) then return end
    return true
end

function Syndra:OnUpdate()
    self.playerPos = Utils.GetSourcePosition(myHero)
    self.debugText = ""
    self:CastSpells()
end

function Syndra:CastSpells()
    local evade = _G.DreamEvade and _G.DreamEvade.HasPath()
    local useR = self:ComputeRTriggerState()
    local isCombo = SDK.Libs.Orbwalker:IsComboMode()
    local isHarass = SDK.Libs.Orbwalker:IsHarassMode()
    local isLasthit = SDK.Libs.Orbwalker:IsLastHitMode()
    local q = myHero:CanUseSpell(SDK.Enums.SpellSlot.Q) and self.slm:ShouldCast()
    local isW1 = myHero:GetSpell(SDK.Enums.SpellSlot.W):GetName() == "SyndraW" and not self.om:GetHeld() and
        not self.om:IsSearchingForHeld()
    local isW2 = myHero:GetSpell(SDK.Enums.SpellSlot.W):GetName() == "SyndraWCast" and self.om:GetHeld()
    local w = myHero:CanUseSpell(SDK.Enums.SpellSlot.W) and self.slm:ShouldCast() and (isW1 or isW2)
    local e = myHero:CanUseSpell(SDK.Enums.SpellSlot.E) and self.slm:ShouldCast()
    local r = myHero:CanUseSpell(SDK.Enums.SpellSlot.R) and self.slm:ShouldCast()
    local qMana = myHero:GetSpell(SDK.Enums.SpellSlot.Q):GetManaCost()
    local wMana = myHero:GetSpell(SDK.Enums.SpellSlot.W):GetManaCost()
    local eMana = myHero:GetSpell(SDK.Enums.SpellSlot.E):GetManaCost()
    local curMana = myHero:AsAttackableUnit():GetMana()
    local hasE = self:HasEPred()
    if self.menu:Get("e.e1") then
        self.debugText = self.debugText .. "holding E key\n"
    end
    local canQe = hasE and q and e and curMana > qMana + eMana
    local grabTargetTable = self.om:GetGrabTarget()
    local canGrabOrb = grabTargetTable and grabTargetTable.isOrb
    local canWe = hasE and w and e and curMana > wMana + eMana and
        ((isW2 and self.om:GetHeld() and self.om:GetHeld().isOrb) or (isW1 and canGrabOrb))
    local canE = canQe or canWe
    if self:CastAntigap(canQe, canWe, e) then return end
    self.debugText = self.debugText .. " reached e casting\n"
    if (self.menu:Get("e.e2") or self.menu:Get("e.e1")) and e and self.lt:ShouldCast() and self:CastE() then return end
    if r and useR and self:CastRExecute() then return end
    if r and self.menu:Get("r.r") and self.lt:ShouldCast() and self:CastR() then return end
    self.debugText = self.debugText .. " reached stun casting\n"
    if self.menu:Get("e.e1") and canE and self.lt:ShouldCast() then
        if not evade then
            if canWe then
                self.debugText = self.debugText .. "looking at WE\n"
                if (isW2 and (self:CastWEShort() or self:CastWELong()))
                    or
                    (isW1 and self:CastW1()) then return end
            else
                self.debugText = self.debugText .. "looking at QE\n"
                if self:CastQEShort() or self:CastQELong() then return end

            end
        end
    end
    self.debugText = self.debugText .. " reached combo\n"
    if isCombo and not (self.menu:Get("e.e1") and canE) then
        if w and isW2 and self:CastW2Old() then return end
        self.debugText = self.debugText .. " reached w1\n"
        self.debugText = self.debugText ..
            " w:" ..
            tostring(w) ..
            " isW1:" ..
            tostring(isW1) .. " hasWPred:" .. tostring(self:HasWPred()) .. "\n"
        if w and isW1 and self:HasWPred() and self:CastW1() then return end
        if q and self:CastQ() then return end
    end
    if isHarass and q and self:CastQ() then return end
    if isLasthit and w and isW1 and SDK.GetPlatform() == "FF15" and self:LastHitUnkillableW1() then return end
end

Syndra:__init()
