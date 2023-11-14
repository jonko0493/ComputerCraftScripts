local function moveForward()
    if turtle.detect() then
        turtle.dig()
    end
    if not turtle.forward() then
        -- something's blocking us -- most likely this is just a gravity-affected block, so we'll dig until we're clear
        -- we could also be out of fuel but this is harmless
        repeat
            turtle.dig()
        until turtle.forward()
    end
end

local function moveUp()
    if turtle.detectUp() then
        turtle.digUp()
    end
    if not turtle.up() then
        -- most likely we're out of fuel
        return
    end
end

local function moveDown()
    if turtle.detectDown() then
        turtle.digDown()
    end
    if not turtle.down() then
        -- most likely we're out of fuel
        return
    end
end

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

local function turnToward(currentDir, targetDir, log)
    if currentDir == targetDir then
        return currentDir
    end
    log("Current dir: "..currentDir..", Target dir: "..targetDir)
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

local function moveToward(point, facingDir, log)
    local x, y, z = gps.locate()
    if x == point.x and y == point.y and z == point.z then
        return facingDir, true
    end
    if x == nil then
        moveForward()
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

    if dx == math.min(dx, dy, dz) then
        if x < point.x then
            facingDir = turnToward(facingDir, "+x", log)
        else
            facingDir = turnToward(facingDir, "-x", log)
        end
        moveForward()
    end
    if dy == math.min(dx, dy, dz) then
        if y < point.y then
            moveUp()
        else
            moveDown()
        end
    end
    if dz == math.min(dx, dy, dz) then
        if z < point.z then
            facingDir = turnToward(facingDir, "+z", log)
        else
            facingDir = turnToward(facingDir, "-z", log)
        end
        moveForward()
    end
    return facingDir, false
end

local function determineFacingDirection()
    x, y, z = gps.locate()
    moveForward()
    nx, ny, nz = gps.locate()
    FacingDir = reverse(FacingDir)
    moveForward()
    FacingDir = reverse(FacingDir)
    if x == nil or nx == nil then
        moveForward()
        determineFacingDirection()
        FacingDir = reverse(FacingDir)
        moveForward()
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

local function handleBlockPlaceInventory()
    if turtle.getItemCount(13) == 0 then
        turtle.select(14)
        turtle.transferTo(13)
        turtle.select(15)
        turtle.transferTo(14)
        turtle.select(16)
        turtle.transferTo(15)
    end
end

local function placeBlock()
    handleBlockPlaceInventory()
    turtle.select(13)
    if turtle.getItemCount() == 0 then
        return false
    end
    turtle.place()
    handleBlockPlaceInventory()
    return true
end

local function placeBlockDown()
    handleBlockPlaceInventory()
    turtle.select(13)
    if turtle.getItemCount() == 0 then
        return false
    end
    turtle.placeDown()
    handleBlockPlaceInventory()
    return true
end

local function placeBlockUp()
    handleBlockPlaceInventory()
    turtle.select(13)
    if turtle.getItemCount() == 0 then
        return false
    end
    turtle.placeUp()
    handleBlockPlaceInventory()
    return true
end

local function oppositeDir(dir)
    if string.sub(dir, 1, 1) == "-" then
        return "+"..string.sub(dir, 2)
    else
        return "-"..string.sub(dir, 2)
    end
end

local function spareInventoryFull()
    return turtle.getItemCount(4) > 0 and turtle.getItemCount(5) > 0 and turtle.getItemCount(6) > 0 and turtle.getItemCount(7) > 0 and turtle.getItemCount(8) > 0 and turtle.getItemCount(9) > 0 and turtle.getItemCount(10) > 0 and turtle.getItemCount(11) > 0 and turtle.getItemCount(12) > 0
end

local function placeChest(facingDir, frameDir, log)
    local originalDir = facingDir
    if turtle.getItemCount(1) == 0 then
        return facingDir, false
    end
    facingDir = turnToward(facingDir, oppositeDir(frameDir), log)
    if turtle.detect() then
        turtle.dig()
    end
    turtle.select(1)
    turtle.place()
    
    for i = 4, 12 do
        turtle.select(i)
        turtle.drop()
    end
    facingDir = turnToward(facingDir, originalDir, log)
    return facingDir, true
end

local function placeTorch(facingDir, frameDir, log)
    local originalDir = facingDir
    if turtle.getItemCount(2) == 0 then
        turtle.select(3)
        turtle.transferTo(2)
    end
    if turtle.getItemCount(2) == 0 then
        return facingDir, false
    end
    turtle.select(2)
    
    facingDir = turnToward(facingDir, oppositeDir(frameDir), log)
    turtle.place()
    assert(originalDir, "originalDir worked")
    facingDir = turnToward(facingDir, originalDir, log)
    return facingDir, true
end

return { moveForward = moveForward, moveDown = moveDown, moveUp = moveUp, determineFacingDirection = determineFacingDirection, turnLeft = turnLeft, turnRight = turnRight, reverse = reverse, oppositeDir = oppositeDir, turnToward = turnToward, moveToward = moveToward, placeBlock = placeBlock, placeBlockDown = placeBlockDown, placeBlockUp = placeBlockUp, spareInventoryFull = spareInventoryFull, placeChest = placeChest, placeTorch = placeTorch }