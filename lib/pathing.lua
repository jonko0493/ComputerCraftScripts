local acceptableThreshold = 0.0001

local function segmentIsCardinal(p1, p2)
    return (p1.x == p2.x and p1.y == p2.y) or (p1.y == p2.y and p1.z == p2.z) or (p1.x == p2.x and p1.z == p2.z)
end

local function getCardinalDirection(p1, p2)
    if not segmentIsCardinal(p1, p2) then
        return nil
    end
    if p1.x ~= p2.x then
        return "x"
    else
        if p1.z ~= p2.z then
            return "z"
        else
            return "y"
        end
    end
end

local function getCardinalVector(dir, mag)
    if dir == "x" then
        return { x = mag, y = 0, z = 0 }
    end
    if dir == "y" then
        return { x = 0, y = mag, z = 0 }
    end
    if dir == "z" then
        return { x = 0, y = 0, z = mag }
    end
end

local function getOppositeAngle(t)
    local opposite = 180 - t
    if opposite < 0 then
        opposite = opposite + 360
    end
    return opposite
end

local function getMagnitude(p1, p2)
    return math.sqrt((p1.x - p2.x) ^ 2 + (p1.y - p2.y) ^ 2 + (p1.z - p2.z) ^ 2)
end

local function isParallel(p1, p2)
    return (math.abs(180 - p1.t) == math.abs(180 - p2.t)) or (math.abs(180 - p1.t) == math.abs(getOppositeAngle(180 - p2.t)))
end

local function yRot(vec, yaw)
    local f = math.cos(math.rad(yaw))
    local g = math.sin(math.rad(yaw))
    local d = vec.x * f + vec.z * g
    local e = vec.y
    local h = vec.z * f - vec.x * g
    return { x = d, y = e, z = h, t = 0 }
end

local function getTBounds1(x, h, z, k, r)
    return math.atan2(z - k, x - h) * r
end

local function getTBounds(x, h, z, k, r, tStart, reverse)
    local t = getTBounds1(x, h, z, k, r)
    if t < tStart and not reverse then
        return t + 2 * math.pi * r
    elseif t > tStart and reverse then
        return t - 2 * math.pi * r
    else
        return t
    end
end

local function signum(num)
    if num > 0 then
        return 1
    elseif num < 0 then
        return -1
    else
        return 0
    end
end

-- this function is translated from the MTR source code
local function getCurve(p1, p2)
    local h1, k1, r1, tStart1, tEnd1, h2, k2, r2, tStart2, tEnd2, reverseT1, reverseT2, isStraight1, isStraight2
    local vecDifference = { x = p2.x - p1.x, y = 0, z = p2.z - p1.z, t = 0 }
    local vecDifferenceRotated = yRot(vecDifference, p1.t)

    local deltaForward = vecDifferenceRotated.z
    local deltaSide = vecDifferenceRotated.x
    if isParallel(p1, p2) then -- 1
        if math.abs(deltaForward) < acceptableThreshold then -- 1a
            h1 = math.cos(math.rad(p1.t))
            k1 = math.sin(math.rad(p1.t))
            if math.abs(h1) >= 0.5 and math.abs(k1) >= 0.5 then
                r1 = (h1 * p1.z - k1 * p1.x) / h1 / h1
                tStart1 = p1.x / h1
                tEnd1 = p2.x / h1
            else
                local div = math.cos(math.rad(p1.t) + math.rad(p1.t))
                r1 = (h1 * p1.z - k1 * p1.x) / div
                tStart1 = (h1 * p1.x - k1 * p1.z) / div
                tEnd1 = (h1 * p2.x - k1 * p2.z) / div
            end
            h2 = 0
            k2 = 0
            r2 = 0
            reverseT1 = tStart1 > tEnd1
            reverseT2 = false
            isStraight1 = true
            isStraight2 = true
            tStart2 = 0
            tEnd2 = 0
        else -- 1b
            if math.abs(deltaSide) > acceptableThreshold then
                local radius = (deltaForward * deltaForward + deltaSide * deltaSide) / (4 * deltaForward)
                r1 = math.abs(radius)
                r2 = math.abs(radius)
                h1 = p1.x - radius * math.sin(math.rad(p1.t))
                k1 = p1.z + radius * math.cos(math.rad(p1.t))
                h2 = p2.x - radius * math.sin(math.rad(p2.t))
                k2 = p2.z + radius * math.cos(math.rad(p2.t))
                reverseT1 = (deltaForward < 0) ~= (deltaSide < 0)
                reverseT2 = not reverseT1
                tStart1 = getTBounds1(p1.x, h1, p1.z, k1, r1)
                tEnd1 = getTBounds(p1.x + vecDifference.x / 2, h1, p1.z + vecDifference.z / 2, k1, r1, tStart1, reverseT1)
                tStart2 = getTBounds1(p1.x + vecDifference.x / 2, h2, p1.z + vecDifference.z / 2, k2, r2)
                tEnd2 = getTBounds(p2.x, h2, p2.z, k2, r2, tStart2, reverseT2)
                isStraight1 = false
                isStraight2 = false
            else
                -- banned node perpendicular to the rail nodes direction
                h1 = 0
                k1 = 0
                h2 = 0
                k2 = 0
                r1 = 0
                r2 = 0
                tStart1 = 0
                tStart2 = 0
                tEnd1 = 0
                tEnd2 = 0
                reverseT1 = false
                reverseT2 = false
                isStraight1 = true
                isStraight2 = true
            end
        end
    else -- 3
        local newFacingStart, newFacingEnd
        if vecDifferenceRotated.x < -acceptableThreshold then
            newFacingStart = getOppositeAngle(p1.t)
        else
            newFacingStart = p1.t
        end 
        if math.cos(math.rad(p2.t)) * vecDifference.x + math.sin(math.rad(p2.t)) * vecDifference.z < -acceptableThreshold then
            newFacingEnd = getOppositeAngle(p2.t)
        else
            newFacingEnd = p2.t
        end
        local angleForward = math.atan(deltaForward, deltaSide)
        local railAngleDifference = newFacingEnd - newFacingStart
        local angleDifference = math.rad(railAngleDifference)

        if signum(angleForward) == signum(angleDifference) then
            local absAngleForward = math.abs(angleForward)

            if absAngleForward - math.abs(angleDifference / 2) < acceptableThreshold then -- Segment First
                local offsetSide = math.abs(deltaForward / math.tan(math.rad(railAngleDifference) / 2))
                local remainingSide = deltaSide - offsetSide
                local deltaXEnd = p1.x + remainingSide * math.cos(math.rad(newFacingStart))
                local deltaZEnd = p1.z + remainingSide * math.sin(math.rad(newFacingStart))
                h1 = math.cos(math.rad(newFacingStart))
                k1 = math.sin(math.rad(newFacingStart))
                if math.abs(h1) >= 0.5 and math.abs(k1) >= 0.5 then
                    r1 = (h1 * p1.z - k1 * p1.x) / h1 / h1
                    tStart1 = p1.x / h1
                    tEnd1 = deltaXEnd / h1
                else
                    local div = math.cos(math.rad(newFacingStart * 2))
                    r1 = (h1 * p1.z - k1 * p1.x) / div
                    tStart1 = (h1 * p1.x - k1 * p1.z) / div
                    tEnd1 = (h1 * deltaXEnd - k1 * deltaZEnd) / div
                end
                isStraight1 = true
                reverseT1 = tStart1 > tEnd1
                local radius = deltaForward / (1 - math.cos(math.rad(railAngleDifference)))
                r2 = math.abs(radius)
                h2 = deltaXEnd - radius * math.sin(math.rad(newFacingStart))
                k2 = deltaZEnd + radius * math.cos(math.rad(newFacingStart))
                reverseT2 = deltaForward < 0
                tStart2 = getTBounds1(deltaXEnd, h2, deltaZEnd, k2, r2)
                tEnd2 = getTBounds(p2.x, h2, p2.z, k2, r2, tStart2, reverseT2)
                isStraight2 = false
            elseif absAngleForward - math.abs(angleDifference) < acceptableThreshold then
                local crossSide = deltaForward / math.tan(math.rad(railAngleDifference))
                local remainingSide = (deltaSide - crossSide) * (1 + math.cos(math.rad(railAngleDifference)))
                local remainingForward = (deltaSide - crossSide) * (math.sin(math.rad(railAngleDifference)))
                local deltaXEnd = p1.x + remainingSide * math.cos(math.rad(newFacingStart)) - remainingForward * math.sin(math.rad(newFacingStart))
                local deltaZEnd = p1.z + remainingSide * math.sin(math.rad(newFacingStart)) + remainingForward * math.cos(math.rad(newFacingStart))
                local radius = (deltaSide - deltaForward / math.tan(math.rad(railAngleDifference))) / math.tan(math.rad(railAngleDifference) / 2)
                r1 = math.abs(radius)
                h1 = p1.x - radius * math.sin(math.rad(newFacingStart))
                k1 = p1.z + radius * math.cos(math.rad(newFacingStart))
                isStraight1 = false
                reverseT1 = deltaForward < 0
                tStart1 = getTBounds1(p1.x, h1, p1.z, k1, r1)
                tEnd1 = getTBounds(deltaXEnd, h1, deltaZEnd, k1, r1, tStart1, reverseT1)
                h2 = math.cos(math.rad(newFacingEnd))
                k2 = math.sin(math.rad(newFacingEnd))
                if math.abs(h2) >= 0.5 and math.abs(k2) >= 0.5 then
                    r2 = (h2 * deltaZEnd - k2 * deltaXEnd) / h2 / h2
                    tStart2 = deltaXEnd / h2
                    tEnd2 = p2.x / h2
                else
                    local div = math.cos(math.rad(newFacingEnd * 2))
                    r2 = (h2 * deltaZEnd - k2 * deltaXEnd) / div
                    tStart2 = (h2 * deltaXEnd - k2 * deltaZEnd) / div
                    tEnd2 = (h2 * p2.x - k2 * p2.z) / div
                end
                isStraight2 = true
                reverseT2 = tStart2 > tEnd2
            else -- out of available range
                h1 = 0
                k1 = 0
                h2 = 0
                k2 = 0
                r1 = 0
                r2 = 0
                tStart1 = 0
                tStart2 = 0
                tEnd1 = 0
                tEnd2 = 0
                reverseT1 = false
                reverseT2 = false
                isStraight1 = true
                isStraight2 = true
            end
        else -- 3b, apparently a TODO for a very complex one
            h1 = 0
            k1 = 0
            h2 = 0
            k2 = 0
            r1 = 0
            r2 = 0
            tStart1 = 0
            tStart2 = 0
            tEnd1 = 0
            tEnd2 = 0
            reverseT1 = false
            reverseT2 = false
            isStraight1 = true
            isStraight2 = true
        end
    end

    return { h1 = h1, k1 = k1, r1 = r1, tStart1 = tStart1, tEnd1 = tEnd1, h2 = h2, k2 = k2, r2 = r2, tStart2 = tStart2, tEnd2 = tEnd2, reverseT1 = reverseT1, reverseT2 = reverseT2, isStraight1 = isStraight1, isStraight2 = isStraight2, y1 = p1.y, y2 = p2.y }
end

local function getCurvesFromPoints(points)
    local curves = {}

    for i = 1, #points - 1 do
        local p1 = points[i]
        local p2 = points[i + 1]
        table.insert(curves, getCurve(p1, p2))
    end
    
    return curves
end

local function getPositionXZ(h, k, r, t, radiusOffset, isStraight, y)
    if isStraight then
        local x
        if math.abs(h) >= 0.5 and math.abs(k) >= 0.5 then
            x = h * t + k * radiusOffset + 0.5
        else
            x = h * t + k * (r + radiusOffset) + 0.5
        end
        local z = k * t + h * (r - radiusOffset) + 0.5
        return { x = x, y = y, z = z }
    else
        return { x = h + (r + radiusOffset) * math.cos(t / r) + 0.5, y = y, z = k + (r + radiusOffset) * math.sin(t / r) + 0.5 }
    end
end

local function getCurvePosAt(t, curve)
    local count1 = math.abs(curve.tEnd1 - curve.tStart1)
    local count2 = math.abs(curve.tEnd2 - curve.tStart2)
    local value = t * (count1 + count2)
    local y = curve.y1

    if value <= count1 then
        local tloc = 1
        if curve.reverseT1 then
            tloc = -1
        end
        local pos = getPositionXZ(curve.h1, curve.k1, curve.r1, tloc * value + curve.tStart1, 0, curve.isStraight1, y)
        pos.x = math.floor(pos.x + 0.5)
        pos.z = math.floor(pos.z + 0.5)
        return pos
    else
        local tloc = 1
        if curve.reverseT2 then
            tloc = -1
        end
        local pos = getPositionXZ(curve.h2, curve.k2, curve.r2, tloc * (value - count1) + curve.tStart2, 0, curve.isStraight2, y)
        pos.x = math.floor(pos.x + 0.5)
        pos.z = math.floor(pos.z + 0.5)
        return pos
    end
end

return { getCurvesFromPoints = getCurvesFromPoints, getCurvePosAt = getCurvePosAt }