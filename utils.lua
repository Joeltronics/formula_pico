
function round(val)
	return flr(val + 0.5)
end

function project(x, y, z)
	local scale = 64 / z
	return x * scale + 64, y * scale + 64, scale
end

function skew(x, y, z, xd, yd)
	return x + z*xd, y + z*yd, z
end

function advance(cnr, seg)
	seg += 1
	if seg > road[cnr].length then
		seg = 1
		cnr += 1
		if (cnr > #road) cnr = 1
	end
	return cnr, seg
end

function reverse(cnr, seg)
	seg -= 1
	if seg == 0 then
		cnr -= 1
		if (cnr == 0) cnr = #road
		seg = road[cnr].length
	end

	return cnr, seg
end
