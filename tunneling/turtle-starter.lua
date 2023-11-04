local loglib = require("loglib")
LogName = "starter"
Protocol = "tunnel"

local function split(inputstr, sep)
    if sep == nil then
            sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end

local args = { ... }
local turtleName = args[1]

local sizeStr = split(args[2], "x")
local w = tonumber(sizeStr[1])
local h = tonumber(sizeStr[2])

local points = {}
local pointsStr = split(args[3], ":")
for idx, point in pairs(pointsStr) do
    local pointVals = split(point, ",")
    points[idx] = { x = tonumber(pointVals[1]), y = tonumber(pointVals[2]), z = tonumber(pointVals[3]) }
end

startInfo = { width = w, height = h, points = points, progress = 0 }

turtleId = rednet.lookup(Protocol, turtleName)
if turtleId ~= nil then
    rednet.send(turtleId, "start", Protocol)
    local readyId, readyMessage = rednet.receive(Protocol, 5)
    if readyMessage == "ready" then
        rednet.send(turtleId, textutils.serialize(startInfo), "tunnel-start")
        local startId, startMessage = rednet.receive(Protocol, 5)
        if startMessage == "started" then
            write("Started tunneling!")
        else
            if startMessage ~= nil then
                write("Failed: "..startMessage)
            else
                write("Failed nonresponsively!")
            end
        end
    else
        write("Device did not respond")
    end
else
    write("Failed to find "..turtleName)
end