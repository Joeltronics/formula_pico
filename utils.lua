
function round(val)
	return flr(val + 0.5)
end

function sgn0(val)
	return val == 0 and 0 or sgn(val)
end

function clip_num(val, minval, maxval)
	return max(minval, min(maxval, val))
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
