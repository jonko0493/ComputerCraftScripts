while true do
    local x, y, z = gps.locate()
    write(x..", "..y..", "..z)
    term.setCursorPos(1, 1)
    sleep(0.2)
    term.clear()
end