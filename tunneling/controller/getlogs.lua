local loglib = require("loglib")
Protocol = "tunnel"

local args = { ... }
local logsTarget = args[1]

local client = rednet.lookup(Protocol, logsTarget)
if client ~= nil then
    rednet.send(client, "logs", Protocol)
    local logsId, logsMessage = rednet.receive("tunnel-logs", 5)
    write(logsMessage)
    if logsMessage ~= nil then
        loglib.log(logsTarget, logsMessage)
    else
        write("Logs were not sent!\n")
    end
    write("Device did not respond!\n")
end
