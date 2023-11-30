local movement = require("movement")

peripheral.find("modem", rednet.open)
rednet.host("chunky-follower", os.getComputerLabel())

local busy = false
local facingDir = movement.determineFacingDirection()
local nextLoc

local function receiveMessage()
    local id, message = rednet.receive("chunky-follower", 5)
    if message ~= nil then
        nextLoc = textutils.unserialize(message)
        write(nextLoc.x..", "..nextLoc.y..", "..nextLoc.z.."\n")
        local x, y, z = gps.locate()
        rednet.send(id, textutils.serialize({ x = x, y = y, z = z }), "chunky-follower")
    end
    while busy do
        sleep(1)
    end
end

local function act()
    if nextLoc ~= nil then
        busy = true
        facingDir = movement.moveToward(nextLoc, facingDir)
        busy = false
    end
    sleep(1)
end

while true do
    parallel.waitForAny(receiveMessage, act)
end