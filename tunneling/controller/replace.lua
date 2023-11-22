local loglib = require("loglib")
LogName = "replace"
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

startInfo = { location = args[2], itemFilter = args[3], turn = args[4] }

turtleId = rednet.lookup(Protocol, turtleName)
if turtleId ~= nil then
    rednet.send(turtleId, "replace", Protocol)
    local readyId, readyMessage = rednet.receive(Protocol, 5)
    if readyMessage == "ready" then
        rednet.send(turtleId, textutils.serialize(startInfo), "replace-start")
        local replaceId, replaceMessage = rednet.receive(Protocol, 5)
        if replaceMessage == "started" then
            write("Started replacing "..args[2].."!\n")
        else
            if replaceMessage ~= nil then
                write("Failed: "..replaceMessage.."\n")
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