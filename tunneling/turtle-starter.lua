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

local startWAxis = args[4]
local startHAxis = args[5]

startInfo = { width = w, height = h, points = points, frameProgress = 0, frameWAxis = startWAxis, frameHAxis = startHAxis, currentCurve = 1, curveProgress = 0, progress = 0 }

turtleId = rednet.lookup(Protocol, turtleName)
if turtleId ~= nil then
    rednet.send(turtleId, "start", Protocol)
    local readyId, readyMessage = rednet.receive(Protocol, 5)
    if readyMessage == "ready" then
        rednet.send(turtleId, textutils.serialize(startInfo), "tunnel-start")
        local startId, startMessage = rednet.receive(Protocol, 5)
        if startMessage == "started" then
            write("Started tunneling!\n")
        else
            if startMessage ~= nil then
                write("Failed: "..startMessage.."\n")
            else
                write("Failed nonresponsively!\n")
            end
        end
    else
        write("Device did not respond\n")
    end
else
    write("Failed to find "..turtleName.."\n")
end