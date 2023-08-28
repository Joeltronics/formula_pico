
function init_minimap()

	minimap = {}

	local minimap_scale = road.minimap_scale / length_scale
	minimap_step = max(1, round(length_scale / road.minimap_scale))

	local count, x, y, dx, dy, heading = 0, 0, 0, 0, -1, start_heading
	for section in all(road) do
		for n = 1, section.length do

			if (count % minimap_step == 0) add(minimap, {x, y})

			heading -= section.angle_per_seg
			heading %= 1.0

			dx = minimap_scale * cos(heading)
			dy = minimap_scale * sin(heading)

			x += dx
			y += dy
			count += 1
		end
	end

	-- TODO: calculate minimap_x / minimap_y dynamically from this (maybe minimap_scale too?)
end

function draw_minimap()

	-- TODO: use a sprite or the map or something for this

	camera(-128 + road.minimap_x, -64 + road.minimap_y)

	-- Map
	line(0, 0, 0, 0, 7)
	for seg in all(minimap) do
		line(seg[1], seg[2])
	end

	-- Finish line
	local coord = minimap[(road[1].length - 1) \ minimap_step + 1]
	local x, y = coord[1], coord[2]
	line(x, y, x, y, 0)

	-- Car positions

	-- Other cars
	-- TODO: draw these in reverse place order, i.e. first place drawn last
	for idx = 2, #cars do
		coord = minimap[(cars[idx].segment_total - 1) \ minimap_step + 1]
		x, y = coord[1], coord[2]
		line(x, y, x, y, cars[idx].palette[8])
	end

	-- Always draw self last
	coord = minimap[(cars[1].segment_total - 1) \ minimap_step + 1]
	x, y = coord[1], coord[2]
	line(x, y, x, y, cars[1].palette[8])

	camera()
end
