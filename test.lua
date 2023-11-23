local angleslib = require("tunneling.tunnelers.angles")
local pathing = require("lib.pathing")

local angles = angleslib.angles

TunnelInfo = { width = 5, height = 5, currentCurve = 1 }

Distance = 0
BlocksCleared = {}
TargetBlocks = {}
Target = {}

local INCREMENT = 0.01

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

local pointsArg = "-16,121,3,W:39,121,174,E"
local points = {}
local pointsStr = split(pointsArg, ":")
for idx, point in pairs(pointsStr) do
    local pointVals = split(point, ",")
    points[idx] = { x = tonumber(pointVals[1]), y = tonumber(pointVals[2]), z = tonumber(pointVals[3]), t = angles[pointVals[4]] }
end

local curves = pathing.getCurvesFromPoints(points)

local function tprint (tbl, indent)
  if not indent then indent = 0 end
  local toprint = string.rep(" ", indent) .. "{\r\n"
  indent = indent + 2 
  for k, v in pairs(tbl) do
    toprint = toprint .. string.rep(" ", indent)
    if (type(k) == "number") then
      toprint = toprint .. "[" .. k .. "] = "
    elseif (type(k) == "string") then
      toprint = toprint  .. k ..  "= "   
    end
    if (type(v) == "number") then
      toprint = toprint .. v .. ",\r\n"
    elseif (type(v) == "string") then
      toprint = toprint .. "\"" .. v .. "\",\r\n"
    elseif (type(v) == "table") then
      toprint = toprint .. tprint(v, indent + 2) .. ",\r\n"
    else
      toprint = toprint .. "\"" .. tostring(v) .. "\",\r\n"
    end
  end
  toprint = toprint .. string.rep(" ", indent-2) .. "}"
  return toprint
end

local function tableContainsVector(table, vector)
    for idx, vec in pairs(table) do
        if vec.x == vector.x and vec.y == vector.y and vec.z == vector.z then
            return true
        end
    end
    return false
end

local function calculateNextTarget()
    if #TargetBlocks == 0 then
        local railAngle = pathing.getRailAngle(curves[TunnelInfo.currentCurve], Distance)
        local pos1 = { x = -0.5, y = 0, z = -TunnelInfo.width / 2 }
        local pos2 = { x = pos1.x, y = pos1.y + TunnelInfo.height, z = pos1.z + TunnelInfo.width }
        local pos3 = { x = pos1.x + 1, y = pos1.y, z = pos1.z }
        local pos4 = { x = pos1.x + 1, y = pos1.y + TunnelInfo.height, z = pos1.z + TunnelInfo.width }
        pos1 = pathing.yRot(pos1, railAngle)
        pos2 = pathing.yRot(pos2, railAngle)
        pos3 = pathing.yRot(pos3, railAngle)
        pos4 = pathing.yRot(pos4, railAngle)
        local actualPos = pathing.getCurvePosAt(Distance, curves[TunnelInfo.currentCurve])
        pos1 = { x = math.floor(pos1.x + actualPos.x + 0.5), y = math.floor(pos1.y + actualPos.y + 0.5), z = math.floor(pos1.z + actualPos.z + 0.5) }
        pos2 = { x = math.floor(pos2.x + actualPos.x + 0.5), y = math.floor(pos2.y + actualPos.y + 0.5), z = math.floor(pos2.z + actualPos.z + 0.5) }
        pos3 = { x = math.floor(pos3.x + actualPos.x + 0.5), y = math.floor(pos3.y + actualPos.y + 0.5), z = math.floor(pos3.z + actualPos.z + 0.5) }
        pos4 = { x = math.floor(pos4.x + actualPos.x + 0.5), y = math.floor(pos4.y + actualPos.y + 0.5), z = math.floor(pos4.z + actualPos.z + 0.5) }
        for x = actualPos.x - TunnelInfo.width,actualPos.x + TunnelInfo.width do
            for y = actualPos.y,actualPos.y + TunnelInfo.height do
                for z = actualPos.z - TunnelInfo.width,actualPos.z + TunnelInfo.width do
                    local block = { x = x, y = y, z = z }
                    if pathing.rectangularPrismContainsPoint(pos1, pos2, pos3, pos4, pos1.y, pos4.y, block) and not tableContainsVector(BlocksCleared, block) then
                        table.insert(TargetBlocks, block)
                    end
                end
            end
        end
    end

    Distance = Distance + INCREMENT

    Target = TargetBlocks[1]
    table.insert(BlocksCleared, Target)
    table.remove(TargetBlocks, 1)
end

for i = 1, #curves do
  print(tprint(curves[i]))
  print(math.abs(curves[i].tEnd1 - curves[i].tStart1) + math.abs(curves[i].tEnd2 - curves[i].tStart2))
  for j = 0, 1, 0.05 do
    local pos = pathing.getCurvePosAt(j, curves[i])
    print("Curve "..i..", progress "..j..": ("..pos.x..", "..pos.y..", "..pos.z..")")
  end
  
  calculateNextTarget()
  
end