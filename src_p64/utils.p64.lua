
function shallowcopy(tbl)
	out = {}
	for key, value in pairs(tbl) do
		out[key] = value
	end
	return out
end

function round(val, multiple_of)
	if (not multiple_of) return flr(val + 0.5)
	val /= multiple_of
	val = flr(val + 0.5)
	val *= multiple_of
	return val
end

function sgn0(val)
	return val == 0 and 0 or sgn(val)
end

function clip_num(val, minval, maxval)
	return max(minval, min(maxval, val))
end

function asin(val)
	return atan2(sqrt(1 - val*val), val)
end

function move_toward(curr, rate, dest)
	dest = dest or 0
	if (curr >= dest) return max(dest, curr - rate)
	return min(dest, curr + rate)
end

function print_centered(text, x, y, col)
	print(text, round(x - 2.5*#text), y, col)
end

function digit_to_hex_char(digit)
	return sub("0123456789abcdef", digit + 1, digit + 1)
end

function project(x, y, z)
	if (z <= 0) return 480, 270, 240

	local scale = 135 / z
	return x * scale + 240, y * scale + 135, scale
end

function skew(x, y, z, xd, yd)
	return x + z*xd, y + z*yd, z
end

function advance(section_idx, segment_idx)
	segment_idx += 1
	if segment_idx > road[section_idx].length then
		segment_idx = 1
		section_idx += 1
		if (section_idx > #road) section_idx = 1
	end
	return section_idx, segment_idx
end

function reverse(section_idx, segment_idx)
	segment_idx -= 1
	if segment_idx == 0 then
		section_idx -= 1
		if (section_idx == 0) section_idx = #road
		segment_idx = road[section_idx].length
	end
	return section_idx, segment_idx
end

function adjust_speed_for_grip(speed, grip)
	--[[
	Scaling section speed for grip:

	Centripetal acceleration: 
		a_c = v^2 / r
		v = sqrt(a_c / r)

	section.braking_speed is for grip=1
	a_c is linearly proportional to grip

	So if grip != 1, then scale speed by sqrt(grip)
	]]
	return speed * sqrt(grip)
end

--[[
	Braking distance:
		Vf^2 = Vi^2  + 2 * a * d
		d = (Vf^2 - Vi^2) / (2 * a)

	brake_decel is positive deceleration, so we want -a:
		d = (Vi^2 - Vf^2) / (2 * -a)

	Speeds are scaled by speed_scale, so true speeds Vi & Vf are:
		s = current speed, in game units
		b = braking speed, in game units
		C = speed_scale
		Vi = s * C
		Vf = b * C

		d = ((s*C)^2 - (b*C)^2) / (2 * -a)
		d = (s^2 - b^2) * C^2 / (2 * -a)

		d = SCALE * (s^2 - b^2)
		SCALE = C^2 / (2 * -a)
]]

braking_distance_scale = speed_scale * speed_scale / (2 * brake_decel)

function braking_distance(curr_speed, brake_speed)
	-- TODO: decel should depend on grip (it doesn't currently)
	return braking_distance_scale * (curr_speed*curr_speed - brake_speed*brake_speed)
end

function distance_to_next_braking_point(section, seg_plus_subseg)
	return section.next_braking_distance + section.length - seg_plus_subseg
end

function need_to_brake(section, seg_plus_subseg, curr_speed, scale_braking_distance, grip)

	local brake_speed = adjust_speed_for_grip(section.braking_speed, grip)
	if (curr_speed > adjust_speed_for_grip(section.max_speed, grip)) return true
	if (curr_speed <= brake_speed) return false
	return (scale_braking_distance or 1) * braking_distance(curr_speed, brake_speed) >= distance_to_next_braking_point(section, seg_plus_subseg)
end

function braking_distance_relative(section, seg_plus_subseg, curr_speed, grip)

	if (curr_speed > adjust_speed_for_grip(section.max_speed, grip)) return 0
	-- if (curr_speed <= adjust_speed_for_grip(section, grip)) return 32767

	local dist_brake = braking_distance(curr_speed, adjust_speed_for_grip(section.braking_speed, grip))
	if (dist_brake <= 0) return 32767

	return distance_to_next_braking_point(section, seg_plus_subseg) / dist_brake
end

-- p01_triangle_163 by @p01
-- https://www.lexaloffle.com/bbs/?tid=31478
-- License CC4-BY-NC-SA
function trifill(x0,y0,x1,y1,x2,y2,col)
	color(col)
	if(y1<y0)x0,x1,y0,y1=x1,x0,y1,y0
	if(y2<y0)x0,x2,y0,y2=x2,x0,y2,y0
	if(y2<y1)x1,x2,y1,y2=x2,x1,y2,y1
	col=x0+(x2-x0)/(y2-y0)*(y1-y0)
	p01_trapeze_h(x0,x0,x1,col,y0,y1)
	p01_trapeze_h(x1,col,x2,x2,y1,y2)
end
function p01_trapeze_h(l,r,lt,rt,y0,y1)
	lt,rt=(lt-l)/(y1-y0),(rt-r)/(y1-y0)
	if(y0<0)l,r,y0=l-y0*lt,r-y0*rt,0
	y1=min(y1,128)
	for y0=y0,y1 do
	 rectfill(l,y0,r,y0)
	 l+=lt
	 r+=rt
	end
end
