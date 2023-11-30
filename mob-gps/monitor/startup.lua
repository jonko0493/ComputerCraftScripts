local CHANNEL = "mob-report"

local function contains(table, value)
    for key, val in ipairs(table) do
        if val == value then
            return true
        end
    end
    return false
end

peripheral.find("modem", rednet.open)
local cart = peripheral.find("cartographer")
if not contains(cart.getMarkerSets(), "mobs") then
    cart.addMarkerSet("mobs", "Mobs")
end

while true do
    local id, message = rednet.receive(CHANNEL, 2)
    if message ~= nil then
        -- this limits us to only one instance of mob tracking per dimension
        -- a limitation we can overcome in the future if we desire
        cart.clearMarkerSet("mobs")
        local mob_report = textutils.unserialize(message)
        for idx, mob in pairs(mob_report) do
            cart.addPOIMarker("mobs", mob.id, mob.name, mob.name, mob.x, mob.y, mob.z, mob.icon)
        end
    end
end