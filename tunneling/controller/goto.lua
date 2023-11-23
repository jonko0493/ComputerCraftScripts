local loglib = require("loglib")
LogName = "replace"
Protocol = "tunnel"

local args = { ... }
local turtleName = args[1]

startInfo = { x = tonumber(args[2]), y = tonumber(args[3]), z = tonumber(args[4]) }

turtleId = rednet.lookup(Protocol, turtleName)
if turtleId ~= nil then
    rednet.send(turtleId, "goto", Protocol)
    local readyId, readyMessage = rednet.receive(Protocol, 5)
    if readyMessage == "ready" then
        rednet.send(turtleId, textutils.serialize(startInfo), "goto-start")
        local replaceId, gotoMessage = rednet.receive(Protocol, 5)
        if gotoMessage == "started" then
            write("Started moving toward ("..args[2]..", "..args[3]..", "..args[4]..")\n")
        else
            if gotoMessage ~= nil then
                write("Failed: "..gotoMessage.."\n")
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