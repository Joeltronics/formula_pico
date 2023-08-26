
function round(val)
	return flr(val + 0.5)
end

function print_centered(text, x, y, col)
	print(text, x - 2*#text, y, col)
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
	if (section_idx == 1 and segment_idx == 1) totseg = 1
	return section_idx, segment_idx, road[section_idx].sumct + segment_idx
end

function reverse(section_idx, segment_idx)
	segment_idx -= 1
	if segment_idx == 0 then
		section_idx -= 1
		if (section_idx == 0) section_idx = #road
		segment_idx = road[section_idx].length
	end
	return section_idx, segment_idx, road[section_idx].sumct + segment_idx
end
