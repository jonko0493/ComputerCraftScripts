local function turnLeft(facingDir)
    if turtle.turnLeft() then
        if facingDir == "+x" then
            return "-z"
        end
        if facingDir == "-z" then
            return "-x"
        end
        if facingDir == "-x" then
            return "+z"
        end
        if facingDir == "+z" then
            return "+x"
        end
    end
    return facingDir
end

local function turnRight(facingDir)
    if turtle.turnRight() then
        if facingDir == "+x" then
            return "+z"
        end
        if facingDir == "+z" then
            return "-x"
        end
        if facingDir == "-x" then
            return "-z"
        end
        if facingDir == "-z" then
            return "+x"
        end
    end
    return facingDir
end

local function facingDirToDegrees(facingDir)
    if facingDir == "-z" then
        return 0
    end
    if facingDir == "+x" then
        return 90
    end
    if facingDir == "+z" then
        return 180
    end
    if facingDir == "-x" then
        return 270
    end
end

local function degreesToFacingDir(degrees)
    if degrees < 0 then
        degrees = degrees + 360
    elseif degrees >= 360 then
        degrees = degrees - 360
    end
    if degrees == 0 then
        return "-z"
    end
    if degrees == 90 then
        return "+x"
    end
    if degrees == 180 then
        return "+z"
    end
    if degrees == 270 then
        return "-x"
    end
end

local function turnToward(currentDir, targetDir)
    if currentDir == targetDir then
        return currentDir
    end
    local cDeg = facingDirToDegrees(currentDir)
    local tDeg = facingDirToDegrees(targetDir)
    local dtheta = cDeg - tDeg

    if math.abs(dtheta) > 180 then
        dtheta = dtheta / -3 -- e.g. -270 -> 90, 270 -> -90
    end

    if dtheta > 0 then
        repeat
            currentDir = turnLeft(currentDir)
        until currentDir == targetDir
    else
        repeat
            currentDir = turnRight(currentDir)
        until currentDir == targetDir
    end

    return targetDir
end

local function reverse(facingDir)
    facingDir = turnRight(facingDir)
    return turnRight(facingDir)
end

local function moveForward(facingDir)
    if turtle.detect() then
        facingDir = turnRight(facingDir)
        if turtle.detect() then
            facingDir = reverse(facingDir)
            if turtle.detect() then
                facingDir = turnRight(facingDir)
                if turtle.detectUp() then
                    if turtle.detectDown() then
                        -- we're like, stuck stuck. give up.
                        return facingDir
                    else
                        turtle.down()
                        facingDir = moveForward(facingDir)
                    end
                else
                    turtle.up()
                    facingDir = moveForward(facingDir)
                end
            else
                turtle.forward()
                facingDir = turnRight(facingDir)
                facingDir = moveForward(facingDir)
            end
        else
            turtle.forward()
            facingDir = turnLeft(facingDir)
            facingDir = moveForward(facingDir)
        end
    else
        turtle.forward()
    end
    return facingDir
end

local function moveToward(point, facingDir)
    local x, y, z = gps.locate()
    if x == point.x and y == point.y and z == point.z then
        return facingDir, true
    end
    if x == nil then
        facingDir = moveForward(facingDir)
        return facingDir, false
    end
    local dx = math.abs(point.x - x)
    local dy = math.abs(point.y - y)
    local dz = math.abs(point.z - z)

    -- we do this to "eliminate" the zeroes
    if dx == 0 then
        dx = 10000000
    end
    if dy == 0 then
        dy = 10000000
    end
    if dz == 0 then
        dz = 10000000
    end

    if dy == math.min(dx, dy, dz) then
        if y < point.y then
            if not turtle.up() then
                dy = 10000000 -- do something else first, we'll try to move up later
            end
        else
            if not turtle.down() then
                dy = 10000000 -- do something else first, we'll try to move down later
            end
        end
    end
    if dx == math.min(dx, dy, dz) then
        if x < point.x then
            facingDir = turnToward(facingDir, "+x")
        else
            facingDir = turnToward(facingDir, "-x")
        end
        moveForward()
    end
    if dz == math.min(dx, dy, dz) then
        if z < point.z then
            facingDir = turnToward(facingDir, "+z")
        else
            facingDir = turnToward(facingDir, "-z")
        end
        moveForward()
    end
    return facingDir, false
end

local function determineFacingDirection()
    x, y, z = gps.locate()
    turtle.forward()
    nx, ny, nz = gps.locate()
    FacingDir = reverse(FacingDir)
    turtle.forward()
    FacingDir = reverse(FacingDir)
    if x == nil or nx == nil then
        turtle.forward()
        determineFacingDirection()
        FacingDir = reverse(FacingDir)
        turtle.forward()
        FacingDir = reverse(FacingDir)
    end
    if nx ~= x then
        if nx - x == 1 then
            return "+x"
        else
            return "-x"
        end
    else
        if nz - z == 1 then
            return "+z"
        else
            return "-z"
        end
    end
end

local function oppositeDir(dir)
    if string.sub(dir, 1, 1) == "-" then
        return "+"..string.sub(dir, 2)
    else
        return "-"..string.sub(dir, 2)
    end
end

local function placeTorch(facingDir, frameDir)
    local originalDir = facingDir
    if turtle.getItemCount(1) == 0 then
        turtle.select(2)
        turtle.transferTo(1)
    end
    if turtle.getItemCount(1) == 0 then
        return facingDir, false
    end
    turtle.select(1)
    
    facingDir = turnToward(facingDir, oppositeDir(frameDir))
    turtle.place()
    assert(originalDir, "originalDir worked")
    facingDir = turnToward(facingDir, originalDir)
    return facingDir, true
end

return { moveForward = moveForward, determineFacingDirection = determineFacingDirection, facingDirToDegrees = facingDirToDegrees, degreesToFacingDir = degreesToFacingDir, turnLeft = turnLeft, turnRight = turnRight, reverse = reverse, oppositeDir = oppositeDir, turnToward = turnToward, moveToward = moveToward, placeTorch = placeTorch }