---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

local Utils = require("Common.Utils")
local LineSegment = require("LeagueSDK.Api.Common.LineSegment")

local Geometry = {}

local DreamLoader = require("Common.DreamLoader")
local Prediction = DreamLoader.Api.Prediction

local function VectorAngleBetweenFull(src, side1, side2)
    local p1, p2 = (-src + side1), (-src + side2)
    local theta = p1:Polar() - p2:Polar()
    if theta < 0 then
        theta = theta + 360
    end
    return theta
end

---@alias posTableEntry table{pos: SDK_VECTOR, isPrio: boolean}
---@param src SDK_VECTOR
---@param spellRange number
---@param spellAngle number
---@param posTable posTableEntry[]
---@return table{pos: SDK_VECTOR, allCount: number, prioCount: number} | nil
function Geometry.BestAoeConic(src, spellRange, spellAngle, posTable)
    if not posTable then return end
    local angleTable = {}
    local zeroPos = posTable[1].pos

    for _, entry in ipairs(posTable) do
        local dist = src:Distance(entry.pos)
        if dist <= spellRange + 0.01 then
            local angle = VectorAngleBetweenFull(src, zeroPos, entry.pos)
            table.insert(angleTable, { angle = angle, isPrio = entry.isPrio })
        end
    end

    table.sort(angleTable, function(a, b) return a.angle < b.angle end)

    local maxAllCount, maxPrioCount, maxStart, maxEnd = 0, 0, nil, nil

    local function isContained(count, angle, base, over360, endAngle)
        if angle == base then
            return count == 0
        end
        if not over360 then
            if angle <= endAngle and angle >= base then
                return true
            end
        else
            if angle > base and angle <= 360 then
                return true
            elseif angle <= endAngle and angle < base then
                return true
            end
        end
        return false
    end

    for i, entry in ipairs(angleTable) do
        local base = entry.angle
        local endAngle = base + spellAngle
        local over360 = endAngle > 360
        if over360 then
            endAngle = endAngle - 360
        end

        local angle = base
        local j = i
        local count = 0
        local prioCount = 0
        local endDelta = angle
        while (isContained(count, angle, base, over360, endAngle)) do
            if angleTable[j].isPrio then prioCount = prioCount + 1 end
            endDelta = angleTable[j].angle
            count = count + 1
            j = j + 1
            if j > #angleTable then
                j = 1
            end
            angle = angleTable[j].angle
        end
        if prioCount and (prioCount > maxPrioCount or (prioCount == maxPrioCount and count > maxAllCount)) then
            maxAllCount = count
            maxStart = base
            maxEnd = endDelta
            maxPrioCount = prioCount
        end
    end
    if maxStart ~= nil then
        if maxStart + spellAngle > 360 then
            maxEnd = maxEnd + 360
        end
        local resAngle = (maxStart + maxEnd) / 2
        if resAngle > 360 then resAngle = resAngle - 360 end
        local resPos = src + (zeroPos - src):Normalized():Rotated(0, math.rad(resAngle), 0) * spellRange
        return { pos = resPos, allCount = maxAllCount, prioCount = maxPrioCount }
    end
end

---@param spellData DREAM_PRED_SPELL_INPUT
---@param ts SDK_DreamTS
---@param dir SDK_VECTOR
---@return table{pos: SDK_VECTOR | nil, closeToCenter: boolean}
function Geometry.GetAutofollowPos(spellData, ts, dir)
    local targets, preds = ts:GetTargets(spellData)
    local src = Utils.GetSourcePosition(myHero)
    for _, target in ipairs(targets) do
        local pred = preds[target:GetNetworkId()]
        if not pred then goto continue end
        local endPos = src + dir * (spellData.range + target:GetBoundingRadius())
        local col = Prediction.IsCollision(spellData, src, endPos, target)
        if not col then goto continue end
        local seg = LineSegment(src, endPos)
        local dist = seg:DistanceTo(pred.targetPosition)
        local diff = dir:Rotated(0, math.pi / 2, 0)
        local hor = diff * dist
        local pos1 = src + hor
        local pos2 = src - hor
        local adjustPos = pos1:Distance(pred.targetPosition) > pos2:Distance(pred.targetPosition) and pos2 or pos1
        local movePos = adjustPos
        local closeToCenter = false
        -- if close to center, allow vertical movement
        if dist <= target:GetBoundingRadius() + spellData.width / 2 then
            closeToCenter = true
            local mousePos = SDK.Renderer:GetMousePos3D()
            local verDist = math.sqrt((target:GetBoundingRadius() + spellData.width / 2) ^ 2 - dist ^ 2)
            local endPos2 = src - dir * (spellData.range + target:GetBoundingRadius())
            local ver = endPos:Distance(mousePos) < endPos2:Distance(mousePos) and 1 or -1
            movePos = adjustPos + ver * dir * verDist
        end
        if movePos then
            --TODO: wall can be issue
            return { pos = movePos, closeToCenter = closeToCenter }
        end
        ::continue::
    end
    return { pos = nil, closeToCenter = false }
end

return Geometry
