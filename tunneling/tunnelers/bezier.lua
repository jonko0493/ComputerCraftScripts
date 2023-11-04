--- Borrowed from https://github.com/Kasper24/KwesomeDE/blob/579cbb2f84153b3cb61e7ee710b71d1f7c34260a/helpers/bezier.lua

--- Get a cubic Bézier curve that passes through given points (up to 4).
--
-- This function takes up to 4 values and returns the 4 control points
-- for a cubic curve
--
-- `B(t) = c0\*(1-t)^3 + 3\*c1\*t\*(1-t)^2 + 3\*c2\*t^2\*(1-t) + c3\*t^3`,
-- that takes on these values at equidistant values of the t parameter.
--
-- If only p0 is given, `B(0)=B(1)=B(for all t)=p0`.
--
-- If p0 and p1 are given, `B(0)=p0` and `B(1)=p1`.
--
-- If p0, p1 and p2 are given, `B(0)=p0`, `B(1/2)=p1` and `B(1)=p2`.
--
-- For 4 points given, `B(0)=p0`, `B(1/3)=p1`, `B(2/3)=p2`, `B(1)=p3`.
--
-- @tparam number p0
-- @tparam[opt] number p1
-- @tparam[opt] number p2
-- @tparam[opt] number p3
-- @treturn number c0
-- @treturn number c1
-- @treturn number c2
-- @treturn number c3
-- @staticfct gears.math.bezier.cubic_through_points
-- @see wibox.widget.graph.step_hook
local function bezier_cubic_through_points_1d(p0, p1, p2, p3)
    if not p1 then
        return p0, p0, p0, p0
    end
    if not p2 then
        local c1 = (2 * p0 + p1) / 3
        local c2 = (2 * p1 + p0) / 3
        return p0, c1, c2, p1
    end
    if not p3 then
        local c1 = (4 * p1 - p2) / 3
        local c2 = (4 * p1 - p0) / 3
        return p0, c1, c2, p2
    end
    local c1 = (-5 * p0 + 18 * p1 - 9 * p2 + 2 * p3) / 6
    local c2 = (-5 * p3 + 18 * p2 - 9 * p1 + 2 * p0) / 6
    return p0, c1, c2, p3
end

--- Get a cubic Bézier curve with given values and derivatives at endpoints.
--
-- This function computes the 4 control points for the cubic curve B, such that
-- `B(0)=p0`, `B'(0)=d0`, `B(1)=p3`, `B'(1)=d3`.
--
-- @tparam number d0 The value of the derivative at t=0.
-- @tparam number p0 The value of the curve at t=0.
-- @tparam number p3 The value of the curve at t=1.
-- @tparam number d3 The value of the derivative at t=1.
-- @treturn number c0
-- @treturn number c1
-- @treturn number c2
-- @treturn number c3
-- @staticfct gears.math.bezier.cubic_from_points_and_derivatives
-- @see wibox.widget.graph.step_hook
local function bezier_cubic_from_points_and_derivatives_1d(d0, p0, p3, d3)
    local c1 = p0 + d0 / 3
    local c2 = p3 - d3 / 3
    return p0, c1, c2, p3
end

--- Compute the value of a Bézier curve at a given value of the t parameter.
--
-- This function evaluates the given curve `B` of an arbitrary degree
-- at a given point t.
--
-- @tparam {number,...} c The table of control points of the curve.
-- @tparam number t The value of the t parameter to evaluate the curve at.
-- @treturn[1] number The value of `B(t)`.
-- @treturn[2] nil `nil`, if c is empty.
-- @staticfct gears.math.bezier.curve_evaluate_at
-- @see wibox.widget.graph.step_hook
local function bezier_curve_evaluate_at_1d(c, t)
    local from = c
    local tmp = {nil, nil, nil, nil}
    while #from > 1 do
        for i = 1, #from - 1 do
            tmp[i] = from[i] * (1 - t) + from[i + 1] * t
        end
        tmp[#from] = nil
        from = tmp
    end

    return from[1]
end

local function bezier_cubic_from_points_and_derivatives(d0, p0, p3, d3)
    local p0x, c1x, c2x, p3x = bezier_cubic_from_points_and_derivatives_1d(d0.x, p0.x, p3.x, d3.x)
    local p0y, c1y, c2y, p3y = bezier_cubic_from_points_and_derivatives_1d(d0.y, p0.y, p3.y, d3.y)
    local p0z, c1z, c2z, p3z = bezier_cubic_from_points_and_derivatives_1d(d0.z, p0.z, p3.z, d3.z)
    return { x = p0x, y = p0y, z = p0z }, { x = c1x, y = c1y, z = c1z }, { x = c2x, y = c2y, z = c2z }, { x = p3x, y = p3y, z = p3z }
end

local function bezier_cubic_through_points(p0, p1, p2, p3)
    local xs = {}
    local ys = {}
    local zs = {}
    if not p1 then
        xs = { bezier_cubic_through_points_1d(p0.x) }
        ys = { bezier_cubic_through_points_1d(p0.y) }
        zs = { bezier_cubic_through_points_1d(p0.z) }
    else
        if not p2 then
            xs = { bezier_cubic_through_points_1d(p0.x, p1.x) }
            ys = { bezier_cubic_through_points_1d(p0.y, p1.y) }
            zs = { bezier_cubic_through_points_1d(p0.z, p1.z) }
        else
            if not p3 then
                xs = { bezier_cubic_through_points_1d(p0.x, p1.x, p2.x) }
                ys = { bezier_cubic_through_points_1d(p0.y, p1.y, p2.y) }
                zs = { bezier_cubic_through_points_1d(p0.z, p1.z, p2.z) }
            else
                xs = { bezier_cubic_through_points_1d(p0.x, p1.x, p2.x, p3.x) }
                ys = { bezier_cubic_through_points_1d(p0.y, p1.y, p2.y, p3.y) }
                zs = { bezier_cubic_through_points_1d(p0.z, p1.z, p2.z, p3.z) }
            end
        end
    end
    return { x = xs[1], y = ys[1], z = zs[1] }, { x = xs[2], y = ys[2], z = zs[2] }, { x = xs[3], y = ys[3], z = zs[3] }, { x = xs[4], y = ys[4], z = zs[4] }
end

local function bezier_curve_evaluate_at(t, c0, c1, c2, c3)
    return { x = bezier_curve_evaluate_at_1d({ c0.x, c1.x, c2.x, c3.x }, t), y = bezier_curve_evaluate_at_1d({ c0.y, c1.y, c2.y, c3.y }, t), z = bezier_curve_evaluate_at_1d({ c0.z, c1.z, c2.z, c3.z }, t) }
end

return { cubic_through_points = bezier_cubic_through_points, cubic_from_points_and_derivative = bezier_cubic_from_points_and_derivatives, curve_evaluate_at = bezier_curve_evaluate_at }
