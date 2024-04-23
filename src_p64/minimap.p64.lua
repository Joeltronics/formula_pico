
function init_minimap()
	if (not enable_minimap) return

	minimap = {}

	-- TODO: auto calculate minimap_scale, minimap_offset_x, minimap_offset_y here
	-- This is a holdover from Pico-8 where that had to be pre-calculated
	-- possibly minimap_step too?

	local minimap_scale = 2 * road.minimap_scale
	minimap_step = road.minimap_step

	local count, x, y, dx, dy, heading = 0, 0, 0, 0, -1, road.start_heading
	for section in all(road) do
		for n = 1, section.length do

			if (count % minimap_step == 0) add(minimap, {round(x), round(y)})

			heading -= section.angle_per_seg
			heading %= 1.0

			dx = minimap_scale * cos(heading)
			dy = minimap_scale * sin(heading)

			x += dx
			y += dy
			count += 1
		end
	end
end

function draw_minimap()
	if (not enable_minimap) return

	-- TODO: use a sprite or the map or something for this, don't redraw the lines every frame

	camera(-478 + 2*road.minimap_offset_x, -135 + 2*road.minimap_offset_y)

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
		circfill(x, y, 1, cars[idx].palette[8])
	end

	-- Always draw self last
	coord = minimap[(cars[1].segment_total - 1) \ minimap_step + 1]
	x, y = coord[1], coord[2]
	circfill(x, y, 1, cars[1].palette[8])

	camera()
end
