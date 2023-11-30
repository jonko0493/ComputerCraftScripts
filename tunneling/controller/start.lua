local loglib = require("loglib")
local angleslib = require("tunnelers.angles")
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
local followerName = args[2]

local sizeStr = split(args[3], "x")
local w = tonumber(sizeStr[1])
local h = tonumber(sizeStr[2])

local points = {}
local pointsStr = split(args[4], ":")
for idx, point in pairs(pointsStr) do
    local pointVals = split(point, ",")
    points[idx] = { x = tonumber(pointVals[1]), y = tonumber(pointVals[2]), z = tonumber(pointVals[3]), t = angleslib.angles[pointVals[4]] }
end

local startWAxis = args[5]
local startHAxis = args[6]

local torchSpacing = tonumber(args[7])

local currentCurve
local advanced = false
local startDistance = 0
if args[8] == nil then
    currentCurve = 1
elseif args[8] == "advanced" then
    currentCurve = 1
    advanced = true
    if args[9] ~= nil then
        startDistance = tonumber(args[9])
    end
else
    currentCurve = tonumber(args[8])
end

startInfo = { follower = followerName, width = w, height = h, points = points, frameProgress = 0, frameWAxis = startWAxis, frameHAxis = startHAxis, startWAxis = startWAxis, startHAxis = startHAxis, prevXDir = nil, prevZDir = nil, frameDir = nil, currentCurve = currentCurve, advanced = advanced, curveProgress = 0, torchSpacing = torchSpacing, progress = 0, startDistance = startDistance }

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