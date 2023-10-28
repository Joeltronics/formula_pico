
function round(val)
	return flr(val + 0.5)
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

function toward_zero(val, inc)
	if val >= 0 then
		return max(0, val - inc)
	else
		return min(0, val + inc)
	end
end

function print_centered(text, x, y, col)
	print(text, x - 2*#text, y, col)
end

function digit_to_hex_char(digit)
	return sub("0123456789abcdef", digit + 1, digit + 1)
end

function project(x, y, z)
	local scale = 64 / z
	return x * scale + 64, y * scale + 64, scale
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

--% set braking_distance_scale = speed_scale * speed_scale / (2 * brake_decel)

function braking_distance(curr_speed, brake_speed)
	return "{{ braking_distance_scale }}" * (curr_speed*curr_speed - brake_speed*brake_speed)
end

function distance_to_next_braking_point(section, seg_plus_subseg)
	return section.next_braking_distance + section.length - seg_plus_subseg
end

function need_to_brake(section, seg_plus_subseg, curr_speed, scale_braking_distance)
	if (curr_speed > section.max_speed) return true
	if (curr_speed <= section.braking_speed) return false
	return (scale_braking_distance or 1) * braking_distance(curr_speed, section.braking_speed) >= distance_to_next_braking_point(section, seg_plus_subseg)
end

function braking_distance_relative(section, seg_plus_subseg, curr_speed)

	if (curr_speed > section.max_speed) return 0
	-- if (curr_speed <= section.braking_speed) return 32767

	local dist_brake = braking_distance(curr_speed, section.braking_speed)
	if (dist_brake <= 0) return 32767

	local dist_next = distance_to_next_braking_point(section, seg_plus_subseg)

	return dist_next / dist_brake
end
