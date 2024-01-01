local pathing = require("pathing")
local movement = require("movement")
local loglib = require("loglib")
local replace = require("replace")

Protocol = "tunnel"
Function = "tunnel"
Paused = true
PauseMessage = "Not yet started"
Status = "Running"
Calculating = false
Preview = false
TunnelInfo = {}
Curves = {}
FacingDir = nil
TorchTimer = 0
BlocksCleared = {}
TargetBlocks = {}
Target = nil
Distance = 0

local dt = 0.001
local INCREMENT = 0.5

local function log(message)
    loglib.log("tunnel", message)
end

local function sendStatusMessage(recipient)
    local x, y, z = gps.locate()
    local nilCoalescedProgress = 0
    if TunnelInfo.curveProgress ~= nil then
        nilCoalescedProgress = TunnelInfo.curveProgress * 100
    end
    if Function == "advanced-tunnel" then
        nilCoalescedProgress = Distance / Curves[TunnelInfo.currentCurve].length * 100
    end
    local statusMessage
    if Paused then
        statusMessage = PauseMessage
    else
        statusMessage = Status
    end
    rednet.send(recipient, textutils.serialize({ name = os.getComputerLabel(), follower = TunnelInfo.follower, x = x, y = y, z = z, fuel = turtle.getFuelLevel(), maxFuel = turtle.getFuelLimit(), progress = nilCoalescedProgress, status = statusMessage, facingDir = FacingDir, route = Curves, currentCurve = TunnelInfo.currentCurve, preview = Preview }), Protocol)
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
    local logs = fs.open("logs/tunnel.log", "r")
    rednet.send(id, logs.readAll(), "tunnel-logs")
    logs.close()
end

local function start(startMessage)
    TunnelInfo = textutils.unserialize(startMessage)
    Curves = pathing.getCurvesFromPoints(TunnelInfo.points)
    if TunnelInfo.advanced then
        Function = "advanced-tunnel"
    else
        Function = "tunnel"
    end
    Paused = false
    Status = "Tunnelling"
    Target = nil
    ClearedBlocks = {}
    Distance = TunnelInfo.startDistance / 100 * Curves[TunnelInfo.currentCurve].length
    log("There are "..#Curves.." curves calculated")
end

local function startStairs(stairsMessage)
    TunnelInfo = textutils.unserialize(stairsMessage)
    Function = "stairs"
    Paused = false
    Status = "Building stairs"
    TunnelInfo.originalDir = FacingDir
end

local function startReplace(replaceMessage)
    TunnelInfo = textutils.unserialize(replaceMessage)
    Function = "replace"
    Status = "Replacing blocks"
    Paused = false
end

local function startGoto(gotoMessage)
    Target = textutils.unserialize(gotoMessage)
    Function = "goto"
    Status = "Navigating to ("..Target.x..", "..Target.y..", "..Target.z..")"
    Paused = false
end

local function saveProgress()
    local tunnelInfoFile = fs.open("tunnel-info.txt", "w")
    tunnelInfoFile.write(textutils.serialize(TunnelInfo))
    tunnelInfoFile.close()
end

local function pause(statusMessage)
    Paused = true
    PauseMessage = statusMessage
end

local function act()
    Calculating = true
    if movement.spareInventoryFull() then
        local facingDir, success = movement.placeChest(FacingDir, TunnelInfo.frameDir, log)
        FacingDir = facingDir
        if not success then
            pause("Out of chests")
        end
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
                    TunnelInfo.prevXDir = "+x"
                else
                    TunnelInfo.frameDir = "-x"
                    TunnelInfo.prevXDir = "-x"
                end
            end
            if nextPoint.x == x and nextPoint.y == y and nextPoint.z ~= z then
                TunnelInfo.frameWAxis = "x"
                TunnelInfo.frameHAxis = "y"
                if nextPoint.z - z > 0 then
                    TunnelInfo.frameDir = "+z"
                    TunnelInfo.prevZDir = "+z"
                else
                    TunnelInfo.frameDir = "-z"
                    TunnelInfo.prevZDir = "-z"
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
                local facingDir, success, _ = movement.moveToward(frame, FacingDir, log)
                FacingDir = facingDir
                x, y, z = gps.locate()
            until x == frame.x and y == frame.y and z == frame.z
        else
            local facingDir, success, _ = movement.moveToward(frame, FacingDir, log)
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
                local facingDir, success, _ = movement.moveToward(frame, FacingDir, log)
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
            if TunnelInfo.frameProgress == 0 then
                if TunnelInfo.frameWAxis == "x" and TunnelInfo.prevXDir ~= nil then
                    FacingDir = movement.turnToward(FacingDir, TunnelInfo.prevXDir, log)
                elseif  TunnelInfo.frameWAxis == "z" and TunnelInfo.prevZDir ~= nil then
                    FacingDir = movement.turnToward(FacingDir, TunnelInfo.prevZDir, log)
                elseif TunnelInfo.frameWAxis ~= "y" then
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
    Calculating = false
end

-- local function calculateNextTarget()
--     local startTime = os.clock()
--     while (os.clock() - startTime < 0.002) do
--         local pos1 = pathing.getCurvePosAt(Distance, Curves[TunnelInfo.currentCurve])
--         Distance = Distance + INCREMENT
--         local pos2 = pathing.getCurvePosAt(Distance, Curves[TunnelInfo.currentCurve])
--         local vec3 = { x = pos2.x - pos1.x, y = 0, z = pos2.z - pos1.z }
--         local d = math.sqrt(vec3.x * vec3.x + vec3.y * vec3.y + vec3.z * vec3.z)
--         vec3 = { x = vec3.x / d, y = vec3.y / d, z = vec3.z / d }
--         vec3 = pathing.yRot(vec3, math.pi / 2)

--         for x = -TunnelInfo.width,TunnelInfo.width,INCREMENT do
--             local editPos = { x = pos1.x + vec3.x * x, y = pos1.y, z = pos1.z + vec3.z * x }
--             local wholeNumber = math.floor(editPos.y) == math.ceil(editPos.y)
--             if (math.abs(x) > TunnelInfo.width - INCREMENT) then
--                 for y = 0,TunnelInfo.height do
--                     if y < TunnelInfo.height and not wholeNumber then
--                         Target = { x = editPos.x, y = editPos + y, z = editPos.z }
--                     end
--                 end
--             else
--                 local yAdjust = TunnelInfo.height
--                 if wholeNumber then
--                     yAdjust = TunnelInfo.height - 1
--                 end
--                 Target = { x = editPos.x, y = editPos.y + math.max(0, yAdjust), z = editPos.z }
--             end
--         end

--         if Curves[TunnelInfo.currentCurve].length - Distance < INCREMENT then
--             return true
--         end
--     end

--     return false
-- end

local function tableContainsVector(table, vector)
    for idx, vec in pairs(table) do
        if vec.x == vector.x and vec.y == vector.y and vec.z == vector.z then
            return true
        end
    end
    return false
end

local function calculateNextTarget()
    if #TargetBlocks == 0 then
        log(Distance)
        local railAngle = pathing.getRailAngleAtDistance(Curves[TunnelInfo.currentCurve], Distance)
        local pos1 = { x = -0.5, y = 0, z = -TunnelInfo.width / 2 }
        local pos2 = { x = pos1.x, y = pos1.y + TunnelInfo.height - 1, z = pos1.z + TunnelInfo.width }
        local pos3 = { x = pos1.x + 1, y = pos1.y, z = pos1.z }
        local pos4 = { x = pos1.x + 1, y = pos1.y + TunnelInfo.height - 1, z = pos1.z + TunnelInfo.width }
        pos1 = pathing.yRot(pos1, railAngle)
        pos2 = pathing.yRot(pos2, railAngle)
        pos3 = pathing.yRot(pos3, railAngle)
        pos4 = pathing.yRot(pos4, railAngle)
        local actualPos = pathing.getCurvePosAtDistance(Distance, Curves[TunnelInfo.currentCurve])
        pos1 = { x = math.floor(pos1.x + actualPos.x + 0.5), y = math.floor(pos1.y + actualPos.y + 0.5), z = math.floor(pos1.z + actualPos.z + 0.5) }
        pos2 = { x = math.floor(pos2.x + actualPos.x + 0.5), y = math.floor(pos2.y + actualPos.y + 0.5), z = math.floor(pos2.z + actualPos.z + 0.5) }
        pos3 = { x = math.floor(pos3.x + actualPos.x + 0.5), y = math.floor(pos3.y + actualPos.y + 0.5), z = math.floor(pos3.z + actualPos.z + 0.5) }
        pos4 = { x = math.floor(pos4.x + actualPos.x + 0.5), y = math.floor(pos4.y + actualPos.y + 0.5), z = math.floor(pos4.z + actualPos.z + 0.5) }
        for x = actualPos.x - TunnelInfo.width,actualPos.x + TunnelInfo.width do
            for y = actualPos.y,actualPos.y + TunnelInfo.height do
                for z = actualPos.z - TunnelInfo.width,actualPos.z + TunnelInfo.width do
                    local block = { x = x, y = y, z = z }
                    if pathing.rectangularPrismContainsPoint(pos1, pos2, pos3, pos4, pos1.y, pos4.y, block) and not tableContainsVector(BlocksCleared, block) then
                        table.insert(TargetBlocks, block)
                    end
                end
            end
        end
        Distance = Distance + INCREMENT
    end

    Target = TargetBlocks[1]
    table.insert(BlocksCleared, Target)
    table.remove(TargetBlocks, 1)
end

local function advancedTunnel()
    Calculating = true
    if movement.spareInventoryFull() then
        local facingDir, success = movement.placeChest(FacingDir, FacingDir, log)
        FacingDir = facingDir
        if not success then
            pause("Out of chests")
        end
    end
    if Target == nil then
        calculateNextTarget()
        if Target == nil and Distance >= Curves[TunnelInfo.currentCurve].length then
            pause("Complete")
            return
        end
    end
    if Target ~= nil then
        local newFacingDir, arrived, has_turtle = movement.moveToward(Target, FacingDir, log)
        FacingDir = newFacingDir
        if arrived or has_turtle then
            if not has_turtle then
                if Target.y == pathing.getCurvePosAtDistance(Distance, Curves[TunnelInfo.currentCurve]).y then
                    local has_block, data = turtle.inspectDown()
                    if (has_block and (data.name == "minecraft:lava" or data.name == "minecraft:water")) or not has_block then
                        if not movement.placeBlockDown() then
                            pause("Out of placement blocks")
                            return
                        end
                    end
                end
                if Target.y == pathing.getCurvePosAtDistance(Distance, Curves[TunnelInfo.currentCurve]).y + TunnelInfo.height - 1 then
                    local has_block, data = turtle.inspectUp()
                    if (has_block and (data.name == "minecraft:lava" or data.name == "minecraft:water")) or not has_block then
                        if not movement.placeBlockUp() then
                            pause("Out of placement blocks")
                            return
                        end
                    end
                end
            end
            calculateNextTarget()
            if Target == nil and Distance >= Curves[TunnelInfo.currentCurve].length then
                pause("Complete")
                return
            end
        end
    end
    Calculating = false
end

local function actStairs()
    Calculating = true
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
    Calculating = false
end

local function poll()
    id, message = rednet.receive(Protocol, 2)
    if message == "ping" then
        rednet.send(id, "alive", Protocol)
    elseif message == "refuel" then
        refuel(id)
    elseif message == "status" then
        sendStatusMessage(id)
    elseif message == "preview" then 
        rednet.send(id, "Toggled preview", Protocol)
        Preview = not Preview
        write("Sent preview message")
    elseif message ~= nil and string.sub(message, 1, 6) == "update" then
        doUpdate(id, string.sub(message, 8))
    elseif message == "logs" then
        sendLogs(id)
    elseif message == "pause" then
        rednet.send(id, "paused", Protocol)
        pause("Paused")
        write("Sent pause message")
    elseif message == "resume" then
        rednet.send(id, "resumed", Protocol)
        Paused = false
        write("Sent resume message")
    elseif message == "start" then
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
    elseif message == "goto" then
        rednet.send(id, "ready", Protocol)
        local gotoId, gotoMessage = rednet.receive("goto-start", 2)
        startGoto(gotoMessage)
        rednet.send(id, "started", Protocol)
        write("Sent start goto message")
    end
    -- there are some routines that if interrupted destroy state 
    -- chest placement is one of those
    -- we need to allow those to finish
    while Calculating do
        sleep(1)
    end
end

local function decide()
    if Paused then
        sleep(1)
        return
    end
    if turtle.getFuelLevel() <= 6 then
        pause("Out of fuel!")
    end
    if Function == "stairs" then
        actStairs()
    elseif Function == "replace" then
        Calculating = true
        local status = replace.act(TunnelInfo.turn, TunnelInfo.location, TunnelInfo.itemFilter)
        if status == "done" then
            pause("Complete!")
        elseif status == "stuck" then
            pause("Stuck while replacing "..TunnelInfo.location)
        else
            TunnelInfo.turn = status
        end
        Calculating = false
    elseif Function == "goto" then
        Calculating = true
        local newFacingDir, _, _ = movement.moveToward(Target, FacingDir, log)
        FacingDir = newFacingDir
        Calculating = false
    elseif Function == "advanced-tunnel" then
        advancedTunnel()
    else
        act()
    end
end

-- Start

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
while true do
    parallel.waitForAny(poll, decide)
end