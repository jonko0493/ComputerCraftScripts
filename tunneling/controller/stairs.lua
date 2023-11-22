local loglib = require("loglib")
LogName = "stairs"
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
local l = tonumber(sizeStr[2])

startInfo = { width = w, length = l, stepProgress = 0, originalDir = nil, progress = 0 }

turtleId = rednet.lookup(Protocol, turtleName)
if turtleId ~= nil then
    rednet.send(turtleId, "stairs", Protocol)
    local readyId, readyMessage = rednet.receive(Protocol, 5)
    if readyMessage == "ready" then
        rednet.send(turtleId, textutils.serialize(startInfo), "stairs-start")
        local stairsId, stairsMessage = rednet.receive(Protocol, 5)
        if stairsMessage == "started" then
            write("Started building stairs!\n")
        else
            if stairsMessage ~= nil then
                write("Failed: "..stairsMessage.."\n")
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