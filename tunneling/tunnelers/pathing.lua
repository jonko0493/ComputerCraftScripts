local bezier = require("bezier")

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

local function getMagnitude(p1, p2)
    return math.sqrt((p1.x - p2.x) ^ 2 + (p1.y - p2.y) ^ 2 + (p1.z - p2.z) ^ 2)
end

local function getCurvesFromPoints(points)
    local curves = {}

    local skip = false
    local prevDir = nil
    for i = 1, #points - 1 do
        if not skip then
            p1 = points[i]
            p2 = points[i + 1]
            if p1 == p2 then
                write("Error: Points "..i.." and "..(i + 1).." are the same!")
                exit()
            end
            if segmentIsCardinal(p1, p2) then
                table.insert(curves, { bezier.cubic_through_points(p1, p2) })
                prevDir = getCardinalDirection(p1, p2)
            else
                if prevDir ~= nil then
                    if i < #points - 1 then
                        if segmentIsCardinal(p2, points[i + 2]) then
                            local nextDir = getCardinalDirection(p2, points[i + 2])
                            table.insert(curves, { bezier.cubic_from_points_and_derivative(getCardinalVector(prevDir, getMagnitude(points[i - 1], p1)), p1, p2, getCardinalVector(nextDir, getMagnitude(p2, points[i + 2]))) })
                        else
                            table.insert(curves, { bezier.cubic_through_points(p1, p2, points[i + 2]) })
                            skip = true
                        end
                    else
                        table.insert(curves, { bezier.cubic_through_points(p1, p2) })
                    end
                else
                    if i < #points - 1 then
                        if segmentIsCardinal(p2, points[i + 2]) then
                            table.insert(curves, { bezier.cubic_through_points(p1, p2) })
                        else
                            table.insert(curves, { bezier.cubic_through_points(p1, p2, points[i + 2]) })
                            skip = true
                        end
                    end
                end
            end
        else
            skip = false
        end
    end
    
    return curves
end

return { getCurvesFromPoints = getCurvesFromPoints }