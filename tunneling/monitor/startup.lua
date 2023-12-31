local loglib = require("loglib")
local pathing = require("pathing")
LogName = "turtle-monitor"
Protocol = "tunnel"

Turtles = {}
local function turtleIsKnown(id)
    local myId = os.getComputerID()
    if (id == myId) then
        return true
    end 
    for key, turtleData in pairs(Turtles) do
        if turtleData.id == id then
            return true
        end
    end
    loglib.log(LogName, "Could not find ID "..id)
    return false
end

local function addTurtle(id, w)
    local randColor = "#"..string.format("%02x", math.random(0, 255))..string.format("%02x", math.random(0, 255))..string.format("%02x", math.random(0, 255))
    table.insert(Turtles, { id = id, name = "", follower = "", color = randColor, x = 0, y = 0, z = 0, fuel = 0, maxFuel = 1, progress = 0, status = "Unknown", route = {}, preview = false, lastMessageReceived = os.epoch() / 72000 })
    loglib.log(LogName, "Added turtle "..id..". There are now "..#Turtles.." turtles.")
end

local function updateTurtle(id, turtleData)
    local idx = 1
    for key, turtleData in pairs(Turtles) do
        if turtleData.id == id then
            break
        end
        idx = idx + 1
    end
    if idx > #Turtles then
        loglib.log(LogName, "Error: could not find index "..id.." in turtle array")
        return
    end
    Turtles[idx].name = turtleData.name
    Turtles[idx].follower = turtleData.follower
    Turtles[idx].x = turtleData.x
    Turtles[idx].y = turtleData.y
    Turtles[idx].z = turtleData.z
    Turtles[idx].fuel = turtleData.fuel
    Turtles[idx].maxFuel = turtleData.maxFuel
    Turtles[idx].progress = turtleData.progress
    Turtles[idx].status = turtleData.status
    Turtles[idx].route = turtleData.route
    Turtles[idx].preview = turtleData.preview
    Turtles[idx].lastMessageReceived = os.epoch() / 72000
end

local function contains(table, value)
    for key, val in ipairs(table) do
        if val == value then
            return true
        end
    end

    return false
end

peripheral.find("modem", rednet.open)
-- local monitor = peripheral.find("monitor")
-- monitor.clear()
-- local w, h = monitor.getSize()

-- term.redirect(monitor)
-- paintutils.drawFilledBox(0, 0, w, h, colors.black)
-- paintutils.drawFilledBox(w / 2 - 8, h / 2 - 4, w / 2 + 8, h / 2 + 4, colors.red)
-- for i=1,3 do
--     paintutils.drawLine(w / 2 + i - 1, h / 2 - (i - 3), w / 2 + i - 1, h / 2 + (i - 3), colors.white)
-- end

-- repeat
--     local event, side, x, y = os.pullEvent("monitor_touch")
-- until x >= w / 2 - 8 and x <= w / 2 + 8 and y >= h / 2 - 4 and y <= h / 2 + 4

-- term.clear()
-- local scale = 1.5
-- monitor.setTextScale(scale)
-- paintutils.drawFilledBox(0, 0, w, h, colors.black)
-- term.setBackgroundColor(colors.black)
-- term.setTextColor(colors.white)

local cart = peripheral.find("cartographer")
if not contains(cart.getMarkerSets(), "turtles") then
    cart.addMarkerSet("turtles", "Turtles")
end
if not contains(cart.getMarkerSets(), "chunky-turtles") then
    cart.addMarkerSet("chunky-turtles", "Chunky Turtles")
end
if not contains(cart.getMarkerSets(), "turtlePreviews") then
    cart.addMarkerSet("turtlePreviews", "Tunneling Routes")
end

local function updateFollower(hostname, route, progress)
    if progress > 2.5 then
        local follower = rednet.lookup("chunky-follower", hostname)
        if follower ~= nil then
            local nextPos = pathing.getCurvePosAtDistance(progress - 2.5, route)
            rednet.send(follower, textutils.serialize(nextPos), "chunky-follower")
            local id, msg = rednet.receive("chunky-follower", 2)
            if msg ~= nil then
                local currentPos = textutils.unserialize(msg)
                cart.removeMarker("chunky-turtles", "chunky"..id)
                cart.addPOIMarker("chunky-turtles", "chunky"..id, hostname, hostname, currentPos.x, currentPos.y, currentPos.z, "https://docs.siredvin.site/images/turtlematic/chunk_vial_turtle.png")
            end
        end
    end
end

while true do
    local clients = { rednet.lookup(Protocol) }
    for key, client in pairs(clients) do
        if client ~= nil and not(turtleIsKnown(client))  then
            loglib.log(LogName, "Found client "..client)
            addTurtle(client, w)
        end
    end
    
    if #Turtles > 0 then
        for idx, tunnelTurtle in pairs(Turtles) do
            -- Get turtle status
            rednet.send(tunnelTurtle.id, "status", Protocol)
            local id, message = rednet.receive(Protocol, 3)
            if message ~= nil and message ~= "started" and message ~= "paused" then
                local progressData = textutils.unserialize(message)
                updateTurtle(id, progressData)
                updateFollower(progressData.follower, progressData.route[progressData.currentCurve], progressData.progress / 100 * progressData.route[progressData.currentCurve].length)
            end

            cart.removeMarker("turtles", "turtle"..tunnelTurtle.id)
            cart.removeMarker("turtlePreviews", "turtle"..tunnelTurtle.id.."preview")
            cart.addPOIMarker("turtles", "turtle"..tunnelTurtle.id, tunnelTurtle.name, tunnelTurtle.status..": "..tunnelTurtle.progress.."% \n"..tunnelTurtle.fuel.." / "..tunnelTurtle.maxFuel, tunnelTurtle.x, tunnelTurtle.y, tunnelTurtle.z, "https://www.computercraft.info/wiki/images/8/85/Grid_turtle.png")

            if (tunnelTurtle.preview) then
                local previewPoints = {}
                for curveIdx, curve in pairs(tunnelTurtle.route) do
                    for t = 0,1,0.05 do
                        table.insert(previewPoints, pathing.getCurvePosAt(t, curve))
                    end
                end
                cart.addLineMarker("turtlePreviews", "turtle"..tunnelTurtle.id.."preview", tunnelTurtle.name.." Route Preview", tunnelTurtle.name.." Route Preview", tunnelTurtle.color, 0.75, 3, previewPoints)
            end

            -- -- Clear section of screen
            -- paintutils.drawFilledBox(0, 8 * (idx - 1), w, 8 * (idx - 1) + 7, colors.black)

            -- -- Draw name and status
            -- term.setBackgroundColor(colors.black)
            -- term.setTextColor(colors.white)
            -- term.setCursorPos(2, 8 * (idx - 1) + 1)
            -- term.write(tunnelTurtle.name)
            -- term.setCursorPos(w / 2, 8 * (idx - 1) + 1)
            -- if message == nil then
            --     term.write("Offline")
            -- else
            --     term.write(tunnelTurtle.status)
            -- end

            -- -- Draw fuel bar
            -- paintutils.drawBox(2, 8 * (idx - 1) + 2, w / 2 - 2, 8 * (idx - 1) + 4, colors.white)
            -- term.setCursorPos(3, 8 * (idx - 1) + 2)
            -- term.setTextColor(colors.black) 
            -- term.setBackgroundColor(colors.white)
            -- term.write("Fuel")

            -- local lineColor = colors.lime
            -- if tunnelTurtle.fuel / tunnelTurtle.maxFuel <= 0.4 then
            --     lineColor = colors.yellow
            -- end
            -- if tunnelTurtle.fuel / tunnelTurtle.maxFuel <= 0.15 then
            --     lineColor = colors.red
            -- end
            -- paintutils.drawLine(3, 8 * (idx - 1) + 3, (w / 2 - 6) * (tunnelTurtle.fuel / tunnelTurtle.maxFuel) + 3, 8 * (idx - 1) + 3, lineColor)

            -- -- Draw progress bar
            -- paintutils.drawBox(w / 2, 8 * (idx - 1) + 2, w - 2, 8 * (idx - 1) + 4, colors.white)
            -- term.setCursorPos(w / 2 + 1, 8 * (idx - 1) + 2)
            -- term.setTextColor(colors.black) 
            -- term.setBackgroundColor(colors.white)
            -- term.write("Progress")

            -- paintutils.drawLine(w / 2 + 1, 8 * (idx - 1) + 3, (w / 2 - 4) * tunnelTurtle.progress + w / 2 + 1, 8 * (idx - 1) + 3, colors.cyan)
            
            -- -- Write current location
            -- term.setBackgroundColor(colors.black)
            -- term.setTextColor(colors.white)
            -- term.setCursorPos(2, 8 * (idx - 1) + 6)
            -- term.write("("..tunnelTurtle.x..", "..tunnelTurtle.y..", "..tunnelTurtle.z..")")
        end
    end

    sleep(5)
end