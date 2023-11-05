local pathing = require("pathing")
local movement = require("movement")
local loglib = require("loglib")

Protocol = "tunnel"
Status = "Running"
TunnelInfo = {}
Curves = {}
FacingDir = nil

local function log(message)
    loglib.log("tunnel", message)
end

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

local function sendLogs(id)
    write("Received logs message; sending logs...\n")
    logs = fs.open("logs/tunnel.log", "r")
    rednet.send(id, logs.readAll(), "tunnel-logs")
    logs.close()
end

local function start(startMessage)
    TunnelInfo = textutils.unserialize(startMessage)
    Curves = pathing.getCurvesFromPoints(TunnelInfo.points)
end

local function saveProgress()
    local tunnelInfoFile = fs.open("tunnel-info.txt", "w")
    tunnelInfoFile.write(textutils.serialize(TunnelInfo))
    tunnelInfoFile.close()
end

local function pause(statusMessage)
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
            sendStatusMessage(id, statusMessage)
        end
        if message ~= nil and string.sub(message, 1, 6) == "update" then
            doUpdate(id, string.sub(message, 8))
        end
        if message == "logs" then
            sendLogs(id)
        end
    until message == "resume" or message == "start"
    if message == "resume" then
        rednet.send(id, "resumed", Protocol)
        write("Sent resume message")
    else
        rednet.send(id, "ready", Protocol)
        local startId, startMessage = rednet.receive("tunnel-start", 2)
        local tunnelInfoFile = fs.open("tunnel-info.txt", "w")
        tunnelInfoFile.write(startMessage)
        tunnelInfoFile.close()
        start(startMessage)
        rednet.send(id, "started", Protocol)
        write("Sent start message")
    end
end

function act(dt)
    if movement.spareInventoryFull() then
        local facingDir, success = movement.placeChest(FacingDir)
        FacingDir = facingDir
        if not success then
            pause("Out of chests")
        end
    end
    local frame = pathing.getCurvePosAt(TunnelInfo.curveProgress, Curves[TunnelInfo.currentCurve])
    log("Frame determined: ("..frame.x..", "..frame.y..", "..frame.z..")")
    local x, y, z = gps.locate()
    if TunnelInfo.frameProgress == TunnelInfo.width * TunnelInfo.height then
        if frame.x == x and frame.y == y and frame.z == z then
            TunnelInfo.frameProgress = 0
            local nextPoint
            repeat
                if TunnelInfo.curveProgress > 1 then
                    TunnelInfo.currentCurve = TunnelInfo.currentCurve + 1
                end
                nextPoint = pathing.getCurvePosAt(TunnelInfo.curveProgress + dt, Curves[TunnelInfo.currentCurve])
                if math.abs(nextPoint.x - x) > 1 or math.abs(nextPoint.y - y) > 1 or math.abs(nextPoint.z - z) > 1 then
                    dt = dt / 2
                    nextPoint = { x = x, y = y, z = z } -- reset so we can try again
                else
                    TunnelInfo.curveProgress = TunnelInfo.curveProgress + dt
                end
            until nextPoint.x ~= x or nextPoint.y ~= y or nextPoint.z ~= z
            log("Next point calculated: "..nextPoint.x..","..nextPoint.y..","..nextPoint.z)
            frame = nextPoint

            if nextPoint.x ~= x and nextPoint.y == y and nextPoint.z == z then
                TunnelInfo.frameWAxis = "z"
                TunnelInfo.frameHAxis = "y"
            end
            if nextPoint.x == x and nextPoint.y == y and nextPoint.z ~= z then
                TunnelInfo.frameWAxis = "x"
                TunnelInfo.frameHAxis = "y"
            end
            log("Tunnel axes calculated for frame: "..TunnelInfo.frameWAxis.." by "..TunnelInfo.frameHAxis)

            repeat
                FacingDir = movement.moveToward(frame, FacingDir)
                x, y, z = gps.locate()
            until x == frame.x and y == frame.y and z == frame.z
        else
            FacingDir = movement.moveToward(frame, FacingDir)
        end
    else
        log("Start of frame info: Frame progress: "..TunnelInfo.frameProgress..", w-axis: "..TunnelInfo.frameWAxis..", h-axis: "..TunnelInfo.frameHAxis)
        if TunnelInfo.frameProgress == 0 then
            repeat
                FacingDir = movement.moveToward(frame, FacingDir)
                x, y, z = gps.locate()
            until x == frame.x and y == frame.y and z == frame.z
        end
        if TunnelInfo.frameProgress % TunnelInfo.width == 0 then
            if TunnelInfo.frameProgress ~= 0 then
                local has_block, data = turtle.inspect()
                if (has_block and (data.name == "minecraft:lava" or data.name == "minecraft:water")) or not has_block then
                    if not movement.placeBlock() then
                        pause("Out of placement blocks")
                        return
                    end
                end
            end
            if TunnelInfo.frameProgress == 0 then
                if TunnelInfo.frameWAxis == "x" or TunnelInfo.frameWAxis == "z" then
                    FacingDir = movement.turnRight(FacingDir)
                end
            else
                if TunnelInfo.frameWAxis == "x" or TunnelInfo.frameWAxis == "z" then
                    FacingDir = movement.reverse(FacingDir)
                else
                    FacingDir = movement.turnRight(FacingDir)
                end
            end
            if TunnelInfo.frameHAxis == "y" then
                movement.moveUp()
            else
                movement.moveForward()
                movement.turnRight()
            end
        else
            movement.moveForward()
        end
        if (math.floor(TunnelInfo.frameProgress / TunnelInfo.width) == 0) then
            local has_block, data = turtle.inspectDown()
            if (has_block and (data.name == "minecraft:lava" or data.name == "minecraft:water")) or not has_block then
                if not movement.placeBlockDown() then
                    pause("Out of placement blocks")
                    return
                end
            end
        end
        if (math.floor(TunnelInfo.frameProgress / TunnelInfo.width) == TunnelInfo.height - 1) then
            local has_block, data = turtle.inspectUp()
            if (has_block and (data.name == "minecraft:lava" or data.name == "minecraft:water")) or not has_block then
                if not movement.placeBlockUp() then
                    pause("Out of placement blocks")
                    return
                end
            end
        end
        TunnelInfo.frameProgress = TunnelInfo.frameProgress + 1
    end
    saveProgress()
end

peripheral.find("modem", rednet.open)
rednet.host(Protocol, os.getComputerLabel())

if fs.exists("tunnel-info.txt") then
    local tunnelInfoFile = fs.open("tunnel-info.txt", "r")
    start(tunnelInfoFile.readAll())
    tunnelInfoFile.close()
end

if FacingDir == nil then
    FacingDir = movement.determineFacingDirection()
end

pause("Not yet started")
local dt = 0.001
while true do
    if turtle.getFuelLevel() <= 0 then
        os.pullEvent("turtle_inventory")
    end
    act(dt)
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
        if message == "logs" then
            sendLogs(id)
        end
        if message == "status" then
            sendStatusMessage(id, Status)
        end
        if message == "pause" then
            rednet.send(id, "paused", Protocol)
            write("Received pause message; pausing...")
            pause("Paused")
        end
        if message == "stop" then
            rednet.send(id, "stopped", Protocol)
            write("Received stop message; shutting down...")
            os.shutdown()
        end
    end
end