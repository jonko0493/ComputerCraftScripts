local function moveUp()
    if turtle.detectUp() then
        turtle.digUp()
    end
    if not turtle.up() then
        -- most likely we're out of fuel
        return
    end
end

local function moveForward()
    local has_turtle = false
    local has_block, details = turtle.inspect()
    if has_block then
        turtle.dig()
    end
    if not turtle.forward() then
        -- something's blocking us -- most likely this is just a gravity-affected block, so we'll dig until we're clear
        -- we could also be out of fuel but this is harmless
        repeat
            turtle.dig()
        until turtle.forward()
    end

    return has_turtle
end

local function moveDown()
    local has_block, details = turtle.inspectDown()
    if has_block then
        turtle.digDown()
    end
    if not turtle.down() then
        -- most likely we're out of fuel
        return
    end
end

local function turnToward(targetDir, facingDir)
    if targetDir == facingDir then
        return
    end

    if string.sub(facingDir, 2, 2) == string.sub(targetDir, 2, 2) then
        turtle.turnLeft()
        turtle.turnLeft()
        return
    end
    
    if string.sub(facingDir, 1, 1) == "+" then
        if string.sub(targetDir, 1, 1) == "+" then
            turtle.turnLeft()
        else
            turtle.turnRight()
        end
        return
    end

    if string.sub(targetDir, 1, 1) == "-" then
        turtle.turnLeft()
    else
        turtle.turnRight()
    end
end

local function moveToward(x, y, z, facingDir)
    if x == 0 and y == 0 and z == 0 then
        return true, facingDir, ""
    end

    if math.abs(x) == math.max(math.abs(x), math.abs(y), math.abs(z)) then
        if x > 0 then
            turnToward("+x", facingDir)
            moveForward()
            return false, "+x", "+x"
        else
            turnToward("-x", facingDir)
            moveForward()
            return false, "-x", "-x"
        end
    end
    if math.abs(z) == math.max(math.abs(x), math.abs(y), math.abs(z)) then
        if x > 0 then
            turnToward("+z", facingDir)
            moveForward()
            return false, "+z", "+z"
        else
            turnToward("-z", facingDir)
            moveForward()
            return false, "+-z", "-z"
        end
    end
    if math.abs(y) == math.max(math.abs(x), math.abs(y), math.abs(z)) then
        if y > 0 then
            moveUp()
            return false, facingDir, "+y"
        else
            moveDown()
            return false, facingDir, "-y"
        end
    end
end

return { moveUp = moveUp, moveForward = moveForward, moveDown = moveDown, turnToward = turnToward, moveToward = moveToward }