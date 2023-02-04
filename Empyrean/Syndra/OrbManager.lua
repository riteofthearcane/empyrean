-- ---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

local Utils = require("Common.Utils")
local Constants = require("Syndra.Constants")
local LineSegment = require("LeagueSDK.Api.Common.LineSegment")

---@class Empyrean.Syndra.OrbManager
local OrbManager = require("Common.Utils").Class()
local Debug = require("Common.Debug")


function OrbManager:_init()
    self:_InitTables()
    self:_InitEvents()
end

function OrbManager:_InitTables()
    self._orbs = {}
    self._held = {
        obj = nil,
        isOrb = false,
    }
    self._queueHeldSearch = false
    self._eBlacklist = {} -- should not E held orbs
    self._wBlacklist = {} -- should not W pushed orbs
    self.eLog = {}
end

function OrbManager:_InitEvents()
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnDraw, function() self:_OnDraw() end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnUpdate, function() self:_OnUpdate() end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnCreateObject, function(...) self:_OnCreateObject(...) end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnDeleteObject, function(...) self:_OnDeleteObject(...) end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnPlayAnimation, function(...) self:_OnPlayAnimation(...) end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnProcessSpell, function(...) self:_OnProcessSpell(...) end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnBuffGain, function(...) self:_OnBuffGain(...) end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnBuffLost, function(...) self:_OnBuffLost(...) end)
    SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnNewPath, function(...) self:_OnNewPath(...) end)
end

function OrbManager:_OnNewPath(source, pathing)
    -- if source:GetName() == "Seed" then
    --     local speed = pathing:GetDashSpeed()
    --     if speed < 400 or speed == 1200 then return end
    --     SDK.PrintChat("ONNEWPATH SPEED: " .. speed)
    --     SDK.PrintChat("ONNEWPATH DIST: " .. pathing:GetEndPos():Distance(pathing:GetStartPos()))
    --     local startPos = pathing:GetStartPos()
    --     local endPos = pathing:GetEndPos()
    --     Debug.RegisterDraw(function() SDK.Renderer:DrawCircle3D(startPos, 50, Utils.COLOR_BLUE) end, 5)
    --     Debug.RegisterDraw(function() SDK.Renderer:DrawCircle3D(endPos, 50, Utils.COLOR_BLUE) end, 5)
    -- end
end

---@param obj SDK_GameObject
---@param name string
function OrbManager:_OnPlayAnimation(obj, name)
    if obj:GetName() == "Seed" and obj:GetTeam() == myHero:GetTeam() and obj:AsAI():GetCharacterName() == "SyndraSphere"
        and name == "Death" then
        local netId = obj:GetNetworkId()
        self:_HandleOrbObjDelete(netId)
    end
end

---@param obj SDK_GameObject
---@param netId number
function OrbManager:_OnCreateObject(obj, netId)
    if obj:GetName() == "Seed" and obj:GetTeam() == myHero:GetTeam() and obj:AsAI():GetCharacterName() == "SyndraSphere" then
        self:_HandleOrbObjCreate(obj)
    end
end

---@param obj SDK_GameObject
---@param netId number
function OrbManager:_OnDeleteObject(obj, netId)
    if obj:GetName() == "Seed" and obj:GetTeam() == myHero:GetTeam() and obj:AsAI():GetCharacterName() == "SyndraSphere" then
        self:_HandleOrbObjDelete(netId)
    end
end

---@param obj SDK_GameObject
function OrbManager:_HandleOrbObjCreate(obj)
    local newOrb = {
        obj = obj,
        startTime = SDK.Game:GetTime(),
        endTime = SDK.Game:GetTime() + Constants.ORB_LIFETIME,
        isInit = true,
        netId = obj:GetNetworkId(),
        GetPos = function() return obj:GetPosition() end,
    }
    -- loop through orbs and replace if we find one with the same position
    for uuid, orb in pairs(self._orbs) do
        if orb.GetPos():Distance(newOrb.GetPos()) < 1 then
            self._orbs[uuid] = newOrb
            return
        end
    end
    local uuid = Utils.Uuid()
    self._orbs[uuid] = newOrb
end

---@param netId number
function OrbManager:_HandleOrbObjDelete(netId)
    for uuid, orb in pairs(self._orbs) do
        if orb.netId == netId then
            self._orbs[uuid] = nil
            return
        end
    end
end

---@param pos SDK_VECTOR
function OrbManager:_HandleOrbCast(pos)
    local orb = {
        obj = nil,
        startTime = SDK.Game:GetTime(),
        endTime = SDK.Game:GetTime() + Constants.Q.delay,
        isInit = false,
        netId = nil,
        GetPos = function() return pos end,
    }
    local uuid = Utils.Uuid()
    self._orbs[uuid] = orb
end

---@return table | nil
function OrbManager:_GetHeldOrb()
    -- loop through orbs
    for _, orb in pairs(self._orbs) do
        if orb.isInit and orb.obj:AsAI():IsSurpressed() then
            return {
                obj = orb.obj,
                isOrb = true,
            }
        end
    end
end

---@return table | nil
function OrbManager:_GetHeldMinion()
    local minions = SDK.ObjectManager:GetEnemyMinions()
    for _, minion in ipairs(minions) do
        local buff = minion:AsAI():GetBuff("syndrawbuff")
        if buff then
            return {
                obj = minion,
                isOrb = false,
            }
        end
    end
end

function OrbManager:_HandleOrbHeld(obj)
    -- loop through orbs
    for _, orb in pairs(self._orbs) do
        if orb.obj == obj then
            orb.endTime = SDK.Game:GetTime() + Constants.ORB_LIFETIME
            return
        end
    end
end

---@param pos SDK_VECTOR
function OrbManager:_CheckEPushedOrbs(pos)
    local diff = pos - myHero:GetPosition()
    local dir = diff:Normalized()
    local angleRad = math.rad(Constants.GetEAngle() / 2)
    local rotated1 = myHero:GetPosition() + dir:Rotated(0, angleRad, 0) * Constants.Q.range
    local rotated2 = myHero:GetPosition() + dir:Rotated(0, -angleRad, 0) * Constants.Q.range
    local seg1 = LineSegment(myHero:GetPosition(), rotated1)
    local seg2 = LineSegment(myHero:GetPosition(), rotated2)

    for uuid, orb in pairs(self._orbs) do
        local seg1Dist = seg1:DistanceTo(orb.GetPos())
        local seg2Dist = seg2:DistanceTo(orb.GetPos())
        local angle = myHero:GetPosition():AngleBetween(pos, orb.GetPos())
        if orb.GetPos():Distance(myHero:GetPosition()) < Constants.Q.range + 50 and
            (angle < Constants.GetEAngle() / 2 or seg1Dist < 100 + 5 or seg2Dist < 100 + 5) then
            self._wBlacklist[uuid] = {
                nextCheckTime = SDK.Game:GetTime() + Constants.E_ORB_CONTACT_RANGE / Constants.E.speed + 0.1,
            }
            self.eLog[uuid] = orb.GetPos():Distance(myHero:GetPosition())
        end
    end
end

---@param obj SDK_AIBaseClient
---@param buff SDK_BuffInstance
function OrbManager:_OnBuffGain(obj, buff)
    if obj:GetNetworkId() == myHero:GetNetworkId() and buff:GetName() == "syndrawtooltip" then
        self._queueHeldSearch = true
    end
end

---@param obj SDK_AIBaseClient
---@param buff SDK_BuffInstance
function OrbManager:_OnBuffLost(obj, buff)
    if obj:GetNetworkId() == myHero:GetNetworkId() and buff:GetName() == "syndrawtooltip" then
        if self._held.isOrb then
            self:_MoveOrbToEBlacklist(self._held.obj)
        end
        self._held = {
            obj = nil,
            isOrb = false,
        }
        self._queueHeldSearch = false
    end
end

function OrbManager:_MoveOrbToEBlacklist(obj)
    for uuid, orb in pairs(self._orbs) do
        if orb.netId == obj:GetNetworkId() then
            local speed = obj:AsAI():GetPathing():GetWaypointCount() >= 2 and obj:AsAI():GetPathing():GetDashSpeed() or
                nil
            local endPos = speed and obj:AsAI():GetPathing():GetWaypoint(2) or nil
            local pathTime = speed and obj:GetPosition():Distance(endPos) / speed or 0
            self._eBlacklist[uuid] = {
                nextCheckTime = SDK.Game:GetTime() + pathTime,
            }
            return
        end
    end
end

---@param obj SDK_AIBaseClient
---@param cast SDK_SpellCast
function OrbManager:_OnProcessSpell(obj, cast)
    if obj:GetNetworkId() ~= myHero:GetNetworkId() then
        return
    end
    if cast:GetName() == "SyndraQ" or cast:GetName() == "SyndraQUpgrade" then
        self:_HandleOrbCast(cast:GetEndPos())
        return
    end
    if cast:GetName() == "SyndraE" or cast:GetName() == "SyndraE5" then
        self.qCast = SDK.Game:GetTime()
        self:_CheckEPushedOrbs(cast:GetEndPos())
        return
    end
end

---@return boolean
function OrbManager:IsSearchingForHeld()
    return self._queueHeldSearch
end

---@return table{obj: SDK_GameObject, pos:SDK_VECTOR, isOrb: boolean} | nil
function OrbManager:GetGrabTarget()
    local outOfRangeOrbs = {}
    local lowTime = math.huge
    local lowOrb = nil
    for uuid, orb in pairs(self._orbs) do
        if orb.isInit and not self._wBlacklist[uuid] then
            local dist = myHero:GetPosition():Distance(orb.GetPos())
            if dist < Constants.W_GRAB_RANGE then
                if orb.endTime < lowTime then
                    lowTime = orb.endTime
                    lowOrb = orb.obj
                end
            elseif dist < Constants.W_GRAB_RANGE + Constants.W_TARGET_RANGE then
                local diff = orb.GetPos() - myHero:GetPosition()
                local pos = myHero:GetPosition() + diff:Normalized() * (Constants.W_GRAB_RANGE - 25)
                outOfRangeOrbs[uuid] = {
                    pos = pos,
                    threshold = dist - Constants.W_GRAB_RANGE,
                }
            end
        end
    end
    if lowOrb then
        return {
            obj = lowOrb,
            pos = lowOrb:GetPosition(),
            isOrb = true,
        }
    end

    local lowMinion = nil
    local minions = SDK.ObjectManager:GetEnemyMinions()
    for _, minion in ipairs(minions) do
        if Constants.W_GRAB_OBJS[minion:AsAI():GetCharacterName()] and Utils.IsValidTarget(minion) then
            local dist = myHero:GetPosition():Distance(minion:GetPosition())
            if dist < Constants.W_GRAB_RANGE then
                lowMinion = minion
            end
            for uuid, data in pairs(outOfRangeOrbs) do
                local distToOrb = minion:GetPosition():Distance(data.pos)
                if distToOrb < data.threshold then
                    outOfRangeOrbs[uuid] = nil
                end
            end
        end
    end
    local lowPos = nil
    for uuid, data in pairs(outOfRangeOrbs) do
        if self._orbs[uuid].endTime < lowTime then
            lowTime = self._orbs[uuid].endTime
            lowOrb = self._orbs[uuid].obj
            lowPos = data.pos
        end
    end
    if lowOrb then
        return {
            obj = lowOrb,
            pos = lowPos,
            isOrb = true,
        }
    end
    if lowMinion then
        return {
            obj = lowMinion,
            pos = lowMinion:GetPosition(),
            isOrb = false,
        }
    end
end

function OrbManager:_OnUpdate()
    -- expire orbs that timed out
    self:_ExpireOrbs()
    self:_ExpireWBlacklist()
    self:_ExpireEBlacklist()

    if self._queueHeldSearch then
        local res = self:_GetHeldOrb() or self:_GetHeldMinion()
        if res then
            self._held = res
            if res.isOrb then self:_HandleOrbHeld(res.obj) end
            self._queueHeldSearch = false
        end
    end
end

---@return table{obj=SDK_GameObject | nil, isOrb=boolean} | nil
function OrbManager:GetHeld()
    if self._held.obj then
        return self._held
    end
end

function OrbManager:_ExpireEBlacklist()
    for uuid, data in pairs(self._eBlacklist) do
        if not self._orbs[uuid] or SDK.Game:GetTime() > data.nextCheckTime then
            self._eBlacklist[uuid] = nil
        end
    end
end

function OrbManager:_ExpireWBlacklist()
    for uuid, data in pairs(self._wBlacklist) do
        -- entry deleted in orbs
        if not self._orbs[uuid] then
            self._wBlacklist[uuid] = nil
            -- check if pos has changed
        elseif SDK.Game:GetTime() > data.nextCheckTime then
            local obj = self._orbs[uuid] and self._orbs[uuid].obj
            if not obj or not obj:AsAI():GetPathing():IsDashing() or
                obj:AsAI():GetPathing():GetDashSpeed() ~= Constants.E_PUSH_SPEED then
                self._wBlacklist[uuid] = nil
            else
                self._wBlacklist[uuid].nextCheckTime = SDK.Game:GetTime() + 0.1
            end
        end
    end
end

function OrbManager:_ExpireOrbs()
    for uuid, orb in pairs(self._orbs) do
        if not orb.isInit and orb.endTime < SDK.Game:GetTime() then
            self._orbs[uuid] = nil
            print("ORBMANAGER: Expired not init orb")
        elseif orb.obj and orb.obj:AsAttackableUnit():GetHealth() ~= 1 then
            self._orbs[uuid] = nil
        end
    end
end

---@return SDK_VECTOR[]
function OrbManager:GetEHitOrbs()
    local res = {}
    for uuid, orb in pairs(self._orbs) do
        if orb.isInit and not self._eBlacklist[uuid] then
            table.insert(res, orb.GetPos())
        end
    end
    --TODO: add orbs not init
    return res
end

function OrbManager:_OnDraw()
    for _, orb in pairs(self._orbs) do
        -- local color = orb.isInit and Utils.COLOR_BLUE or Utils.COLOR_RED
        -- SDK.Renderer:DrawCircle3D(orb.GetPos(), 50, color)
        -- if orb.isInit and orb.obj:AsAI():GetPathing():GetWaypointCount() >= 2 then
        --     local count = orb.obj:AsAI():GetPathing():GetWaypointCount()
        --     for i = 1, count - 1 do
        --         local pos1 = orb.obj:AsAI():GetPathing():GetWaypoint(i)
        --         local pos2 = orb.obj:AsAI():GetPathing():GetWaypoint(i + 1)
        --         SDK.Renderer:DrawLine3D(pos1, pos2, Utils.COLOR_BLUE)
        --     end
        -- end
    end
    -- if self._held.obj then
    --     local color = self._held.isOrb and Utils.COLOR_BLUE or Utils.COLOR_RED
    --     SDK.Renderer:DrawCircle3D(self._held.obj:GetPosition(), 75, color)
    -- end
    -- for uuid in pairs(self._wBlacklist) do
    --     local pos = self._orbs[uuid] and self._orbs[uuid].GetPos() or nil
    --     if pos then SDK.Renderer:DrawCircle3D(pos, 100, Utils.COLOR_RED) end
    -- end
    -- for uuid in pairs(self._eBlacklist) do
    --     local pos = self._orbs[uuid] and self._orbs[uuid].GetPos() or nil
    --     if pos then SDK.Renderer:DrawCircle3D(pos, 100, Utils.COLOR_BLUE) end
    -- end
end

return OrbManager
