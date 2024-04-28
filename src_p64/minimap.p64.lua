
function init_minimap()
	if (not enable_minimap) return

	minimap = {}

	-- 1st pass: determine scale, x & y offset, step
	-- TODO: could optimize this, do 1 pass and then update in-place

	local x_min, x_max, y_min, y_max = 0, 0, 0, 0
	local x, y, dx, dy, heading = 0, 0, 0, -1, road.start_heading
	for section in all(road) do
		for n = 1, section.length do

			x_min = min(x_min, x)
			y_min = min(y_min, y)
			x_max = max(x_max, x)
			y_max = max(y_max, y)

			heading -= section.angle_per_seg
			heading %= 1.0

			dx = cos(heading)
			dy = sin(heading)

			x += dx
			y += dy
		end
	end

	local width, height = x_max - x_min, y_max - y_min
	assert(width >= 0 and height >= 0)
	local scale_w = minimap_max_width / (width + 1)
	local scale_h = minimap_max_height / (height + 1)
	local scale = min(scale_w, scale_h)

	minimap.width = ceil(width * scale)
	minimap.height = ceil(height * scale)
	assert(minimap.width <= minimap_max_width)
	assert(minimap.height <= minimap_max_height)

	minimap.step = flr(1.0 / scale)

	-- 2nd pass, actually calculate the minimap

	x = -x_min
	y = -y_min
	heading = road.start_heading
	local count = 0
	for section in all(road) do
		for n = 1, section.length do

			if (count % minimap.step == 0) then

				local map_x = round(scale * x)
				local map_y = round(scale * y)

				add(minimap, {map_x, map_y})
			end

			heading -= section.angle_per_seg
			heading %= 1.0

			dx = cos(heading)
			dy = sin(heading)

			x += dx
			y += dy
			count += 1
		end
	end
end

function draw_minimap(x, y)
	if (not enable_minimap) return

	-- TODO: use a sprite or the map or something for this, don't redraw the lines every frame

	if x then
		-- Centered
		x = x - minimap.width\2
	else
		-- Right-aligned
		x = 476 - minimap.width
	end
	y = y or 135

	camera(-x, -y + minimap.height\2)

	-- Map
	line(minimap[1][1], minimap[1][2], minimap[1][1], minimap[1][2], 7)
	for seg in all(minimap) do
		line(seg[1], seg[2])
	end

	-- Finish line
	local coord = minimap[(road[1].length - 1) \ minimap.step + 1]
	local x, y = coord[1], coord[2]
	line(x, y, x, y, 0)

	if #cars > 0 then
		-- Car positions

		-- Other cars
		-- TODO: draw these in reverse place order, i.e. first place drawn last
		for idx = 2, #cars do
			coord = minimap[(cars[idx].segment_total - 1) \ minimap.step + 1]
			x, y = coord[1], coord[2]
			circfill(x, y, 1, cars[idx].palette[8])
		end

		-- Always draw self last
		coord = minimap[(cars[1].segment_total - 1) \ minimap.step + 1]
		x, y = coord[1], coord[2]
		circfill(x, y, 1, cars[1].palette[8])
	end

	camera()
end
