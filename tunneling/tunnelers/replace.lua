local function act(nextTurn, location, itemFilter)
    local returnNextTurn = nextTurn
    if turtle.getItemCount() == 0 and turtle.getSelectedSlot() < 16 then
        turtle.select(turtle.getSelectedSlot() + 1)
    end
    if turtle.getSelectedSlot() >= 16 then
        return "done"
    end
    local hasBlock, data
    if location == "floor" then
        hasBlock, data = turtle.inspectDown()
        if hasBlock and not string.find(data.name, itemFilter) then
            turtle.digDown()
            turtle.placeDown()
        end
    else
        hasBlock, data = turtle.inspectUp()
        if hasBlock and not string.find(data.name, itemFilter) then
            turtle.digUp()
            turtle.placeUp()
        end
    end
    local frontHasBlock, frontBlock = turtle.inspect()
    if frontHasBlock and frontBlock.name ~= "minecraft:torch" then
        if nextTurn == "left" then
            turtle.turnLeft()
            returnNextTurn = "right"
        else
            turtle.turnRight()
            returnNextTurn = "left"
        end
        frontHasBlock, frontBlock = turtle.inspect()
        if frontHasBlock and frontBlock.name ~= "minecraft:torch" then
            return "stuck"
        end
        turtle.forward()
        if nextTurn == "left" then
            turtle.turnLeft()
            returnNextTurn = "right"
        else
            turtle.turnRight()
            returnNextTurn = "left"
        end
    else
        turtle.dig() -- get rid of torches
        turtle.forward()
    end
    return returnNextTurn
end

return { act = act }