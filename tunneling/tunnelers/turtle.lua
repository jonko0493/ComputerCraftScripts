local pathing = require("pathing")

Protocol = "tunnel"
Status = "Running"
TunnelInfo = {}

local function sendStatusMessage(recipient, status)
    local x, y, z = gps.locate()
    local nilCoalescedProgress = 0
    if TunnelInfo.progress ~= nil then
        nilCoalescedProgress = TunnelInfo.progress
    end
    rednet.send(recipient, textutils.serialize({ name = os.getComputerLabel(), x = x, y = y, z = z, fuel = turtle.getFuelLevel(), maxFuel = turtle.getFuelLimit(), progress = nilCoalescedProgress, status = status }), Protocol)
end

local function refuel(id)
    turtle.refuel()
    rednet.send(id, "Refueled, fuel level is now "..turtle.getFuelLevel().." out of "..turtle.getFuelLimit(), Protocol)
end

local function doUpdate(id, targetFile)
    write("Received update message; updating...")
    rednet.send(id, "ready", Protocol)
    local updateId, update = rednet.receive("tunnel-update", 2)
    if update ~= nil then
        local scriptFile = fs.open(targetFile, "w")
        scriptFile.write(update)
        scriptFile.close()
        rednet.send(id, "complete", Protocol)
        os.reboot()
    else
        while true do
            local errorId, errorMessage = rednet.receive(Protocol, 0.1)
            if message == "status" then
                sendStatusMessage(id, "Update failed!")
            end
        end
    end
end

local function pause()
    local id = 0
    local message = nil
    repeat
        id, message = rednet.receive(Protocol, 0.1)
        if message == "ping" then
            rednet.send(id, "alive", Protocol)
        end
        if message == "refuel" then
            refuel(id)
        end
        if message == "status" then
            sendStatusMessage(id, "Paused")
        end
        if message ~= nil and string.sub(message, 1, 6) == "update" then
            doUpdate(id, string.sub(message, 8))
        end
    until message == "resume" or message == "start"
    if message == "resume" then
        rednet.send(id, "resumed", Protocol)
        write("Sent resume message")
    else
        rednet.send(id, "ready", Protocol)
        local startId, startMessage = rednet.receive("tunnel-start", 2)
        fs.open("tunnel-info.txt", "w")
        fs.write(startMessage)
        fs.close()
        TunnelInfo = textutils.unserialize(startMessage)
        rednet.send(id, "started", Protocol)
        write("Sent start message")
    end
end

peripheral.find("modem", rednet.open)
rednet.host(Protocol, os.getComputerLabel())

if fs.exists("tunnel-info.txt") then
    local tunnelInfoFile = fs.open("tunnel-info.txt", "r")
    TunnelInfo = textutils.unserialize(tunnelInfoFile.readAll())
    tunnelInfoFile.close()
end

pause()
while true do
    if turtle.getFuelLevel() <= 0 then
        os.pullEvent("turtle_inventory")
    end
    turtle.forward()
    local id, message = rednet.receive(Protocol, 0.1)
    if id then
        if message == "ping" then
            rednet.send(id, "alive", Protocol)
        end
        if message == "refuel" then
            refuel(id)
        end
        if message ~= nil and string.sub(message, 1, 6) == "update" then
            doUpdate(id, string.sub(message, 8))
        end
        if message == "status" then
            sendStatusMessage(id, Status)
        end
        if message == "pause" then
            rednet.send(id, "paused", Protocol)
            write("Received pause message; pausing...")
            pause()
        end
        if message == "stop" then
            rednet.send(id, "stopped", Protocol)
            write("Received stop message; shutting down...")
            os.shutdown()
        end
    end
end