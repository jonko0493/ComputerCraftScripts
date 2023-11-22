Protocol = "tunnel"

local args = { ... }
local command = args[1]
local tunnelTurtleName = args[2]

local tunnelTurtle = rednet.lookup(Protocol, tunnelTurtleName)
if tunnelTurtle ~= nil then
    rednet.send(tunnelTurtle, command, Protocol)
    local id, message = rednet.receive(Protocol, 5)
    if message == nil then
        write("Message timed out!\n")
    else
        write("Received message: "..message.."\n")
    end
else
    write("Failed to find "..tunnelTurtleName.."\n")
end