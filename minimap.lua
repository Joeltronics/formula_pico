
function init_minimap()

	local minimap_scale = road.minimap_scale / length_scale
	minimap_step = max(1, round(length_scale / road.minimap_scale))

	local count, x, y, dx, dy, curr_angle = 0, 0, 0, 0, -1, start_angle
	for corner in all(road) do
		for n = 1, corner.length do

			if (count % minimap_step == 0) add(minimap, {x, y})

			curr_angle -= corner.angle_per_seg
			curr_angle %= 1.0

			dx = minimap_scale * cos(curr_angle)
			dy = minimap_scale * sin(curr_angle)

			x += dx
			y += dy
			count += 1
		end
	end
end

function draw_minimap()

	-- TODO: use a sprite or BG or something for this

	camera(-128 + road.minimap_x, -64 + road.minimap_y)

	-- map
	line(0, 0, 0, 0, 7)
	for seg in all(minimap) do
		line(seg[1], seg[2])
	end

	-- finish line
	-- local x, y = minimap[road.finish_seg]
	local x, y = minimap[flr((road.finish_seg - 1) / minimap_step) + 1]
	line(x, y, x, y, 0)

	-- current position
	-- local pos = minimap[camtotseg]
	local pos = minimap[flr((camtotseg - 1) / minimap_step) + 1]
	line(pos[1], pos[2], pos[1], pos[2], 8)

	camera()
end
