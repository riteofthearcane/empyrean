local pow, sqrt, cos, sin, acos, deg, atan, abs, min, max, huge = math.pow, math.sqrt, math.cos, math.sin, math.acos,
    math.deg, math.atan, math.abs, math.min, math.max, math.huge
local insert, remove, sort = table.insert, table.remove, table.sort
local atan2 = math.atan2
local format = string.format

local setmetatable = setmetatable
local assert = assert

local Vector = require("LeagueSDK.Api.Common.Vector")

--======== Start of the Classes ========--


---@class SDK_LINESEGMENT
---@field x SDK_VECTOR
---@field y SDK_VECTOR
local LineSegment = {}
LineSegment.__index = LineSegment
LineSegment.__call = function(self, ...)
    return self:init(...)
end
setmetatable(LineSegment, LineSegment)


function LineSegment:init(self, a, b)
    local proxy = { type = "LineSegment" }
    proxy.points = {}

    if self and not a then
        proxy.points = { Vector(self), Vector() }
    elseif not self then
        proxy.points = { Vector(), Vector() }
    else
        proxy.points = { Vector(self), Vector(a) }
    end

    return setmetatable(proxy, LineSegment)
end

function LineSegment:__eq(spatialObject)
    return spatialObject.type == "LineSegment" and
        (
        (self.points[1] == spatialObject.points[1] and self.points[2] == spatialObject.points[2]) or
            (self.points[2] == spatialObject.points[1] and self.points[1] == spatialObject.points[2]))
end

function LineSegment:GetPoints()
    return self.points
end

function LineSegment:GetLineSegments()
    return { self }
end

function LineSegment:Direction()
    return self.points[2] - self.points[1]
end

function LineSegment:Len()
    return (self.points[1] - self.points[2]):Len()
end

function LineSegment:Contains(spatialObject)
    if spatialObject.type == "Vector" then
        return spatialObject:DistanceTo(self) == 0
    elseif spatialObject.type == "LineSegment" then
        return spatialObject.points[1]:DistanceTo(self) == 0 and spatialObject.points[2]:DistanceTo(self) == 0
    end

    return false
end

function LineSegment:DistanceTo(spatialObject)
    -- if spatialObject.type == "Circle" then
    --     return spatialObject.point:distanceTo(self) - spatialObject.radius
    -- elseif spatialObject.type == "LineSegment" then
    --     --wip
    -- vector only for now
    local z1 = self.points[1].z
    local z2 = self.points[2].z
    local z3 = spatialObject.z

    local pt = { X = spatialObject.x, Y = z3 }
    local p1 = { X = self.points[1].x, Y = z1 }
    local p2 = { X = self.points[2].x, Y = z2 }

    local dx = self.points[2].x - self.points[1].x
    local dy = z2 - z1

    if ((dx == 0) and (dy == 0)) then
        dx = spatialObject.x - self.points[1].x
        dy = z3 - z1
        return sqrt(dx * dx + dy * dy)
    end

    local t = ((pt.X - p1.X) * dx + (pt.Y - p1.Y) * dy) / (dx * dx + dy * dy)

    if (t < 0) then
        dx = pt.X - p1.X
        dy = pt.Y - p1.Y
    elseif (t > 1) then
        dx = pt.X - p2.X
        dy = pt.Y - p2.Y
    else
        local closest = Vector(p1.X + t * dx, 0, p1.Y + t * dy)
        dx = pt.X - closest.x
        dy = pt.Y - closest.z
    end

    return sqrt(dx * dx + dy * dy)

end

function LineSegment:Intersects(spatialObject)
    if spatialObject.type == "LineSegment" then
        -- parameter conversion
        local L1 = { X1 = self.points[1].x, Y1 = self.points[1].z, X2 = self.points[2].x, Y2 = self.points[2].z }
        local L2 = { X1 = spatialObject.points[1].x, Y1 = spatialObject.points[1].z, X2 = spatialObject.points[2].x,
            Y2 = spatialObject.points[2].z }
        -- Denominator for ua and ub are the same, so store this calculation
        local d = (L2.Y2 - L2.Y1) * (L1.X2 - L1.X1) - (L2.X2 - L2.X1) * (L1.Y2 - L1.Y1)

        -- Make sure there is not a division by zero - this also indicates that the lines are parallel.
        -- If n_a and n_b were both equal to zero the lines would be on top of each
        -- other (coincidental).  This check is not done because it is not
        -- necessary for this implementation (the parallel check accounts for this).
        if (d == 0) then
            return false
        end

        -- n_a and n_b are calculated as seperate values for readability
        local n_a = (L2.X2 - L2.X1) * (L1.Y1 - L2.Y1) - (L2.Y2 - L2.Y1) * (L1.X1 - L2.X1)
        local n_b = (L1.X2 - L1.X1) * (L1.Y1 - L2.Y1) - (L1.Y2 - L1.Y1) * (L1.X1 - L2.X1)

        -- Calculate the intermediate fractional point that the lines potentially intersect.
        local ua = n_a / d
        local ub = n_b / d

        -- The fractional point will be between 0 and 1 inclusive if the lines
        -- intersect.  If the fractional calculation is larger than 1 or smaller
        -- than 0 the lines would need to be longer to intersect.
        if (ua >= 0 and ua <= 1 and ub >= 0 and ub <= 1) then
            local x = L1.X1 + (ua * (L1.X2 - L1.X1))
            local y = L1.Y1 + (ua * (L1.Y2 - L1.Y1))
            return true, { x = x, y = 0, z = y }
        end

        return false
        -- elseif spatialObject.type == "Circle" then
        --     return self:distanceTo(spatialObject) <= 0
    elseif spatialObject.type == "Vector" then
        return spatialObject:insideOf(self)
    end
end

function LineSegment:Closest(v)
    -- assert(VectorType(v), "closest: wrong argument types (<Vector> expected)")
    local z1 = self.points[1].z
    local z2 = self.points[2].z
    local z3 = v.z

    local pt = { X = v.x, Y = z3 }
    local p1 = { X = self.points[1].x, Y = z1 }
    local p2 = { X = self.points[2].x, Y = z2 }

    local dx = self.points[2].x - self.points[1].x
    local dy = z2 - z1

    if ((dx == 0) and (dy == 0)) then
        return self.points[1]
    end

    local t = ((pt.X - p1.X) * dx + (pt.Y - p1.Y) * dy) / (dx * dx + dy * dy)

    if (t < 0) then
        return self.points[1]
    elseif (t > 1) then
        return self.points[2]
    else
        return Vector(p1.X + t * dx, self.points[1], p1.Y + t * dy)
    end
end

return LineSegment
