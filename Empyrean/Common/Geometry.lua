---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

local Geometry = {}

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

return Geometry
