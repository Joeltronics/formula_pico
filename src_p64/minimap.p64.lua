
function init_minimap()
	if (not enable_minimap) return

	minimap = {}
	set_draw_target(minimap_spr)
	cls(11)

	-- TODO: add pit lane

	-- 1st pass: determine scale, x & y offset, step

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
	local scale_w = (minimap_max_width - 4) / (width + 1)
	local scale_h = (minimap_max_height - 4) / (height + 1)
	local scale = min(scale_w, scale_h)

	minimap.width = ceil(width * scale)
	minimap.height = ceil(height * scale)
	assert(minimap.width <= minimap_max_width)
	assert(minimap.height <= minimap_max_height)

	minimap.step = max(1, flr(0.5 / scale))

	-- 2nd pass, actually calculate the minimap coordinates, and draw outline into sprite

	-- TODO: could do outline & main line in 1 pass - use blending tables to prioritize foreground

	x = -x_min + 4
	y = -y_min + 4
	heading = road.start_heading
	local count = 0

	local map_x = round(scale * x)
	local map_y = round(scale * y)

	line(map_x, map_y, map_x, map_y, 0) -- init pen location & color

	for section in all(road) do
		for n = 1, section.length do

			if (count % minimap.step == 0) then

				map_x = round(scale * x)
				map_y = round(scale * y)

				add(minimap, {map_x, map_y})

				line(map_x - 1, map_y - 1)
				line(map_x - 1, map_y + 2)
				line(map_x + 2, map_y + 2)
				line(map_x + 2, map_y - 1)
				line(map_x - 1, map_y - 1)
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

	-- 3rd pass: draw the main line

	line(minimap[1][1], minimap[1][2], minimap[1][1], minimap[1][2], 6) -- init pen
	for seg in all(minimap) do
		line(seg[1], seg[2])
		line(seg[1], seg[2] + 1)
		line(seg[1] + 1, seg[2] + 1)
		line(seg[1] + 1, seg[2])
		line(seg[1], seg[2])
	end

	-- Finish line
	fillp(0b0101101001011010)
	local coord = minimap[(road[1].length - 1) \ minimap.step + 1]
	rectfill(
		coord[1] - 1, coord[2] - 1,
		coord[1] + 2, coord[2] + 2,
		0x0007
	)
	fillp()

	set_draw_target()
end

function draw_minimap(x, y)
	if (not enable_minimap) return

	if x then
		-- Centered
		x = x - minimap.width\2
	else
		-- Right-aligned
		x = 476 - minimap.width
	end
	y = y or 135

	camera(-x, -y + minimap.height\2)

	palt(0, false)
	palt(11, true)
	spr(minimap_spr, 0, 0)
	palt()

	if #cars > 0 then
		-- Car positions

		-- Other cars
		-- Draw these in reverse place order, i.e. first place drawn last, except player is always last
		for pos = #car_positions,1,-1 do
			local car_idx = car_positions[pos]
			if car_idx ~= 1 then
				local car = cars[car_idx]
				coord = minimap[(car.segment_total - 1) \ minimap.step + 1]
				x, y = coord[1], coord[2]
				-- TODO: see if using a sprite for this would be better optimized than needing 2 draw calls
				-- circfill() didn't work, center & radius have to be integers
				-- TODO: use different color if identical to minimap bg
				rectfill(x, y-1, x+1, y+2, car.palette[8])
				rectfill(x-1, y, x+2, y+1, car.palette[8])
			end
		end

		-- Always draw self last
		coord = minimap[(cars[1].segment_total - 1) \ minimap.step + 1]
		x, y = coord[1], coord[2]
		rectfill(x, y-1, x+1, y+2, cars[1].palette[8])
		rectfill(x-1, y, x+2, y+1, cars[1].palette[8])

		fillp()
	end

	camera()
end
