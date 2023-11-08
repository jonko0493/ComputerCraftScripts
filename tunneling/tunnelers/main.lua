local pathing = require("pathing")
local movement = require("movement")
local loglib = require("loglib")
local replace = require("replace")

Protocol = "tunnel"
Function = "tunnel"
Status = "Running"
TunnelInfo = {}
Curves = {}
FacingDir = nil
TorchTimer = 0

local function log(message)
    loglib.log("tunnel", message)
end

local function sendStatusMessage(recipient, status)
    local x, y, z = gps.locate()
    local nilCoalescedProgress = 0
    if TunnelInfo.progress ~= nil then
        nilCoalescedProgress = TunnelInfo.progress
    end
    rednet.send(recipient, textutils.serialize({ name = os.getComputerLabel(), x = x, y = y, z = z, fuel = turtle.getFuelLevel(), maxFuel = turtle.getFuelLimit(), progress = nilCoalescedProgress, status = status, facingDir = FacingDir }), Protocol)
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
    Function = "tunnel"
    log("There are "..#Curves.." curves calculated")
end

local function startStairs(stairsMessage)
    TunnelInfo = textutils.unserialize(stairsMessage)
    Function = "stairs"
    TunnelInfo.originalDir = FacingDir
end

local function startReplace(replaceMessage)
    TunnelInfo = textutils.unserialize(replaceMessage)
    Function = "replace"
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
    until message == "resume" or message == "start" or message == "stairs" or message == "replace"
    if message == "resume" then
        rednet.send(id, "resumed", Protocol)
        write("Sent resume message")
    else
        if message == "start" then
            rednet.send(id, "ready", Protocol)
            local startId, startMessage = rednet.receive("tunnel-start", 2)
            local tunnelInfoFile = fs.open("tunnel-info.txt", "w")
            tunnelInfoFile.write(startMessage)
            tunnelInfoFile.close()
            start(startMessage)
            rednet.send(id, "started", Protocol)
            write("Sent start message")
        elseif message == "stairs" then
            rednet.send(id, "ready", Protocol)
            local stairsId, stairsMessage = rednet.receive("stairs-start", 2)
            startStairs(stairsMessage)
            rednet.send(id, "started", Protocol)
            write("Sent start stairs message")
        elseif message == "replace" then
            rednet.send(id, "ready", Protocol)
            local replaceId, replaceMessage = rednet.receive("replace-start", 2)
            startReplace(replaceMessage)
            rednet.send(id, "started", Protocol)
            write("Sent start replace message")
        end
    end
end

function act(dt)
    if movement.spareInventoryFull() then
        local facingDir, success = movement.placeChest(FacingDir, TunnelInfo.frameDir, log)
        FacingDir = facingDir
        if not success then
            pause("Out of chests")
        end
    end
    if TunnelInfo.frameDir == nil then
        TunnelInfo.frameDir = FacingDir
    end
    local frame = pathing.getCurvePosAt(TunnelInfo.curveProgress, Curves[TunnelInfo.currentCurve])
    log("Frame determined: ("..frame.x..", "..frame.y..", "..frame.z..")")
    log("FacingDir: "..FacingDir)
    local x, y, z = gps.locate()
    if TunnelInfo.frameProgress == TunnelInfo.width * TunnelInfo.height then
        if frame.x == x and frame.y == y and frame.z == z then
            TunnelInfo.frameProgress = 0
            if TorchTimer == TunnelInfo.torchSpacing then
                TorchTimer = 0
            end
            TorchTimer = TorchTimer + 1
            log("TorchTimer: "..TorchTimer..", Torch Spacing: "..TunnelInfo.torchSpacing)
            local nextPoint
            repeat
                if TunnelInfo.curveProgress > 1 then
                    TunnelInfo.currentCurve = TunnelInfo.currentCurve + 1
                    log("Current curve: "..TunnelInfo.currentCurve..", Total curves: "..#Curves)
                    if TunnelInfo.currentCurve > #Curves then
                        pause("Complete!")
                    end
                    TunnelInfo.curveProgress = 0
                end
                nextPoint = pathing.getCurvePosAt(TunnelInfo.curveProgress + dt, Curves[TunnelInfo.currentCurve])
                if TunnelInfo.currentCurve > 1 then
                    log("Curve Progress: "..TunnelInfo.curveProgress..", Next Point: ("..nextPoint.x..", "..nextPoint.y..", "..nextPoint.z..")")
                end
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
                if nextPoint.x - x > 0 then
                    TunnelInfo.frameDir = "+x"
                else
                    TunnelInfo.frameDir = "-x"
                end
            end
            if nextPoint.x == x and nextPoint.y == y and nextPoint.z ~= z then
                TunnelInfo.frameWAxis = "x"
                TunnelInfo.frameHAxis = "y"
                if nextPoint.z - z > 0 then
                    TunnelInfo.frameDir = "+z"
                else
                    TunnelInfo.frameDir = "-z"
                end
            end
            if nextPoint.x == x and nextPoint.y ~= y and nextPoint.z == z then
                if nextPoint.y - y > 0 then
                    TunnelInfo.frameDir = "+y"
                else
                    TunnelInfo.frameDir = "-y"
                end
            end
            log("Tunnel axes calculated for frame: "..TunnelInfo.frameWAxis.." by "..TunnelInfo.frameHAxis)

            repeat
                local facingDir, success = movement.moveToward(frame, FacingDir, log)
                FacingDir = facingDir
                x, y, z = gps.locate()
            until x == frame.x and y == frame.y and z == frame.z
        else
            local facingDir, success = movement.moveToward(frame, FacingDir, log)
            FacingDir = facingDir
            return
        end
        if TunnelInfo.frameWAxis == "x" or TunnelInfo.frameWAxis == "z" then
            if TunnelInfo.frameWAxis ~= TunnelInfo.startWAxis then
                log("Frame width axis is "..TunnelInfo.frameWAxis.." which differs from starting "..TunnelInfo.startWAxis.."; turning left...")
                FacingDir = movement.turnLeft(FacingDir)
            else
                log("Frame width axis is "..TunnelInfo.frameWAxis.." which is the same as starting "..TunnelInfo.startWAxis.."; turning right...")
                FacingDir = movement.turnRight(FacingDir)
            end
        end
        TunnelInfo.frameProgress = 1
    else
        log("Start of frame info: Frame progress: "..TunnelInfo.frameProgress..", w-axis: "..TunnelInfo.frameWAxis..", h-axis: "..TunnelInfo.frameHAxis)
        if TunnelInfo.frameProgress == 0 then
            repeat
                local facingDir, success = movement.moveToward(frame, FacingDir, log)
                FacingDir = facingDir
                x, y, z = gps.locate()
            until x == frame.x and y == frame.y and z == frame.z
        end
        if TunnelInfo.frameProgress % TunnelInfo.width == 0 then
            if TorchTimer == 1 then
                if TunnelInfo.frameHAxis == "y" then
                    if y == math.floor(TunnelInfo.height / 2 + frame.y) then
                        movement.placeTorch(FacingDir, TunnelInfo.frameDir, log)
                    end
                end
            end
            -- if TunnelInfo.frameProgress ~= 0 then
            --     local has_block, data = turtle.inspect()
            --     if (has_block and (data.name == "minecraft:lava" or data.name == "minecraft:water")) or not has_block then
            --         if not movement.placeBlock() then
            --             pause("Out of placement blocks")
            --             return
            --         end
            --     end
            -- end
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
                if TunnelInfo.frameHAxis == "y" then
                    movement.moveUp()
                    if TorchTimer == 1 then
                        if y + 1 == math.floor(TunnelInfo.height / 2 + frame.y) then
                            movement.placeTorch(FacingDir, TunnelInfo.frameDir, log)
                        end
                    end
                else
                    movement.moveForward()
                    FacingDir = movement.turnRight(FacingDir)
                end
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

function actStairs()
    if movement.spareInventoryFull() then
        local facingDir, success = movement.placeChest(FacingDir, TunnelInfo.originalDir, log)
        FacingDir = facingDir
        if not success then
            pause("Out of chests")
        end
    end
    if TunnelInfo.stepProgress == TunnelInfo.width * TunnelInfo.length then
        if TunnelInfo.length % 2 == 1 then
            FacingDir = movement.reverse(FacingDir)
            for i = 1, TunnelInfo.width - 1 do
                movement.moveForward()
            end
        end
        TunnelInfo.length = TunnelInfo.length - 1
        if TunnelInfo.length == 0 then
            pause("Complete!")
        end
        FacingDir = movement.turnToward(FacingDir, movement.oppositeDir(TunnelInfo.originalDir), log)
        for i = 1, TunnelInfo.length - 1 do
            movement.moveForward()
        end
        FacingDir = movement.turnToward(FacingDir, TunnelInfo.originalDir, log)
        movement.moveDown()
        TunnelInfo.stepProgress = 0
    end
    if TunnelInfo.stepProgress == 0 then
        FacingDir = movement.turnRight(FacingDir)
        TunnelInfo.stepProgress = 1
    else
        if TunnelInfo.stepProgress % TunnelInfo.width == 0 then
            local currentDir = FacingDir
            FacingDir = movement.turnToward(FacingDir, TunnelInfo.originalDir, log)
            movement.moveForward()
            TunnelInfo.stepProgress = TunnelInfo.stepProgress + 1
            FacingDir = movement.turnToward(FacingDir, movement.oppositeDir(currentDir), log)
        end
    end
    movement.moveForward()
    TunnelInfo.stepProgress = TunnelInfo.stepProgress + 1
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
    if Function == "stairs" then
        actStairs()
    elseif Function == "replace" then
        local status = replace.act(TunnelInfo.turn, TunnelInfo.location, TunnelInfo.itemFilter)
        if status == "done" then
            pause("Complete!")
        elseif status == "stuck" then
            pause("Stuck while replacing "..TunnelInfo.location)
        else
            TunnelInfo.turn = status
        end
    else
        act(dt)
    end
end