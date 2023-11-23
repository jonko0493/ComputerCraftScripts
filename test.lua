local angleslib = require("tunneling.tunnelers.angles")
local pathing = require("lib.pathing")

local angles = angleslib.angles

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

for i = 1, #curves do
  print(tprint(curves[i]))
  print(math.abs(curves[i].tEnd1 - curves[i].tStart1) + math.abs(curves[i].tEnd2 - curves[i].tStart2))
  for j = 0, 1, 0.05 do
    local pos = pathing.getCurvePosAt(j, curves[i])
    print("Curve "..i..", progress "..j..": ("..pos.x..", "..pos.y..", "..pos.z..")")
  end
end