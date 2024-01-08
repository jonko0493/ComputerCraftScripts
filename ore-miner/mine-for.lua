local movement = require("movement")

local scanner = peripheral.find("plethora:scanner")

local args = { ... }
local targetBlock = args[1]
local facingDir = args[2]
local maxMoves = tonumber(args[3])

local relativeOrigin = { x = 0, y = 0, z = 0}
local moves = 0

local function movementBreadcrumb(dir)
    if dir == "+x" then
        relativeOrigin.x = relativeOrigin.x - 1
    elseif dir == "-x" then
        relativeOrigin.x = relativeOrigin.x + 1
    elseif dir == "+z" then
        relativeOrigin.z = relativeOrigin.z - 1
    elseif dir == "-z" then
        relativeOrigin.z = relativeOrigin.z + 1
    elseif dir == "+y" then
        relativeOrigin.y = relativeOrigin.y - 1
    elseif dir == "-y" then
        relativeOrigin.y = relativeOrigin.y + 1
    end
end

local function act()
    while moves < maxMoves do
        local scan = scanner.scan()
        local target = nil
        for idx, block in ipairs(scan) do
            if block.name == targetBlock then
                target = { x = block.x, y = block.y, z = block.z }
                break
            end
        end
        if target ~= nil then
            local arrived, newDir, breadcrumb = movement.moveToward(target.x, target.y, target.z, facingDir)
            if not arrived then
                facingDir = newDir
                movementBreadcrumb(breadcrumb)
            end
        else
            movement.moveForward()
            movementBreadcrumb(facingDir)
        end
        moves = moves + 1
    end
end

local success, msg = pcall(act)
if not success then
    write(msg)
end

local returned = false
while not returned do
    local arrived, newDir, breadcrumb = movement.moveToward(relativeOrigin.x, relativeOrigin.y, relativeOrigin.z, facingDir)
    returned = arrived
    if not arrived then
        facingDir = newDir
        movementBreadcrumb(breadcrumb)
    end
end