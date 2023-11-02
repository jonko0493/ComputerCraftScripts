local loglib = require("loglib")
LogName = "updater"
Protocol = "tunnel"

local args = { ... }
local updateFile = fs.open(args[1], "r")
local update = updateFile.readAll()
updateFile.close()

local clients = { rednet.lookup(Protocol) }
for key, client in pairs(clients) do
    if client ~= nil then
        loglib.log(LogName, "Sending update to client "..client)
        rednet.send(client, "update", Protocol)
        local id, message = rednet.receive(Protocol, 5)
        if message == "ready" then
            rednet.send(client, update, "tunnel-update")
            local updateId, updateMessage = rednet.receive(Protocol, 5)
            if updateMessage == "complete" then
                write("Device updated!\n")
            else
                write("Update timed out!\n")
            end
        else
            write("Device did not respond!\n")
        end
    end
end