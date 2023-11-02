Protocol = "tunnel"

local function sendStatusMessage(recipient, progress, status)
    local x, y, z = gps.locate()
    rednet.send(recipient, textutils.serialize({ name = os.getComputerLabel(), x = x, y = y, z = z, fuel = turtle.getFuelLevel(), maxFuel = turtle.getFuelLimit(), progress = progress, status = status }), Protocol)
end

local function doUpdate(id)
    write("Received update message; updating...")
    rednet.send(id, "ready", Protocol)
    local updateId, update = rednet.receive("tunnel-update", 2)
    local scriptFile = fs.open("startup.lua", "w")
    scriptFile.write(update)
    scriptFile.close()
    rednet.send(id, "complete", Protocol)
    os.reboot()
end

local function pause()
    local id = 0
    local message = nil
    repeat
        id, message = rednet.receive(Protocol, 0.1)
        if message == "status" then
            sendStatusMessage(id, 0, "Paused")
        end
        if message == "update" then
            doUpdate(id)
        end
    until message == "start"
    rednet.send(id, "started", Protocol)
    write("Sent start message")
end

peripheral.find("modem", rednet.open)
turtle.refuel()
write("Refueled, fuel level is now "..turtle.getFuelLevel().." out of "..turtle.getFuelLimit())
rednet.host(Protocol, os.getComputerLabel())

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
        if message == "update" then
            doUpdate(id)
        end
        if message == "status" then
            sendStatusMessage(id, 0, "Running")
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