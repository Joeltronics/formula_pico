
--[[
Colors:
	0 black
	1 dark blue
	2 dark purple
	3 dark green
	4 brown
	5 dark grey
	6 light grey
	7 white
	8 red
	9 orange
	10/0xA yellow
	11/0xB green
	12/0xC blue
	13/0xD indigo
	14/0xE pink
	15/0xF peach
]]

function draw_bg_overhead()
	local col = 256*(road.gndcol1 or 3) + (road.gndcol2 or 11)
	-- fillp(0b0101101001011010)
	fillp(0b0011110000111100)
	rectfill(0, 0, 480, 270, col)
	fillp()
end

function draw_racing_line_overhead(
		section, segment_idx,
		x0, y0, nx0, ny0,
		x1, y1, nx1, ny1)

	local col = get_racing_line_color(section, segment_idx, cars[1])

	local w = road.track_width

	local rlx0 = section.entrance_x + (segment_idx - 1)*section.racing_line_dx
	local rlx1 = section.entrance_x + segment_idx*section.racing_line_dx
	if (racing_line_sine_interp) then
		rlx0, rlx1 = sin(rlx0), sin(rlx1)
	end

	line(
		x0 + w*rlx0*nx0, y0 + w*rlx0*ny0,
		x1 + w*rlx1*nx1, y1 + w*rlx1*ny1,
		col)
end

function draw_segment_overhead(
		section, section_idx, segment_idx,
		x0, y0, dx0, dy0, heading0,
		x1, y1, dx1, dy1, heading1,
		sprite_list)

	local sumct = section.sumct + segment_idx
	local player_car = cars[1]
	local w = road.track_width
	local tnl = section.tnl
	local pitch = section.pitch + section.dpitch*(segment_idx - 1)

	local curb_start = w - shoulder_half_width
	local curb_end = w + shoulder_half_width

	local roadcol
	if pitch <= 0 then
		-- Downhill - lighter - fade 5 (dark grey) -> 6 (light grey)
		roadcol = 6*256 + 5
		-- If tunnel, fade 1 (dark blue) -> 5 (dark grey)
		if (tnl) roadcol = 5*256 + 1
	else
		-- Uphill - darker - fade 5 (dark grey) -> 1 (dark blue)
		roadcol = 1*256 + 5
		-- If tunnel, fade 1 (dark blue) -> 0 (black)
		if (tnl) roadcol = 1
	end

	-- local road_fillp_gradient = abs(pitch)
	local road_fillp_gradient = 0.5 * abs(pitch)

	-- Normals
	local nx0, ny0 = -dy0, dx0
	local nx1, ny1 = -dy1, dx1

	local wl0, wl1, wr0, wr1 = get_wall_locs(section, segment_idx)

	-- TODO: handle pit lane & dpit

	-- if enable_draw.ground then
	-- 	local gndcol, gndcol_l, gndcol_r = get_ground_colors(section, sumct)
	-- 	-- TODO: draw ground extending out
	-- end

	-- Technically could also use when dy0 == dy1 == 0 too, but this case is rare and would need to be tested
	local can_use_rectfill = (dx0 == 0) and (dx1 == 0)

	-- Road
	if enable_draw.road then
		if sumct == road[1].length + 1 then
			-- Start/finish line
			roadcol = 7

			-- TODO: this doesn't move with the track, which is weird
			-- Use smaller fillp until this is fixed (less noticeable)
			-- fillp(
			-- 	0b00001111,
			-- 	0b00001111,
			-- 	0b00001111,
			-- 	0b00001111,
			-- 	0b11110000,
			-- 	0b11110000,
			-- 	0b11110000,
			-- 	0b11110000)
			fillp(0b0011001111001100)

		else
			fillp_gradient(road_fillp_gradient)
		end

		-- TODO: use curb_start instead of w

		if can_use_rectfill then
			rectfill(
				x0 - nx0 * w, y0 - ny0 * w,
				x1 + nx1 * w, y1 + ny1 * w,
				roadcol)

		else

			--[[
			C                 D
			*-----------------*
			/                 /
			*-----------------*
			A                 B ]]

			local xa, ya = x0 - nx0 * w, y0 - ny0 * w
			local xb, yb = x0 + nx0 * w, y0 + ny0 * w
			local xc, yc = x1 - nx1 * w, y1 - ny1 * w
			local xd, yd = x1 + nx1 * w, y1 + ny1 * w

			quadfill(xa, ya, xb, yb, xc, yc, xd, yd, roadcol)

			-- HACK: draw extra lines to cover gaps
			line(xa, ya, xb, yb, roadcol)
			line(xb, yb, xc, yc, roadcol)
		end

		fillp()

		-- Lane lines
		if (sumct % 4) == 0 then
			local lanes = section.lanes or road.lanes
			for lane_idx = 1,lanes-1 do
				local lx_rel = 2*lane_idx/lanes - 1  -- Range [-1, 1]
				line(
					x0 + nx0 * w * lx_rel, y0 + ny0 * w * lx_rel,
					x1 + nx1 * w * lx_rel, y1 + ny1 * w * lx_rel,
					6)
			end
		end
	end

	-- Curbs
	if enable_draw.curbs then
		local even = sumct % 2 == 0

		local curbcol = 7
		if (even) curbcol = 8

		if (tnl) curbcol = 0
		if (tnl and even) curbcol = 1

		if can_use_rectfill then
			rectfill(
				x0 - nx0 * curb_start, y0 - ny0 * curb_start,
				x1 - nx1 * curb_end, y1 - ny1 * curb_end,
				curbcol)
			rectfill(
				x0 + nx0 * curb_start, y0 + ny0 * curb_start,
				x1 + nx1 * curb_end, y1 + ny1 * curb_end,
				curbcol)
		else
			quadfill(
				x0 - nx0 * curb_start, y0 - ny0 * curb_start,
				x0 - nx0 * curb_end, y0 - ny0 * curb_end,
				x1 - nx1 * curb_start, y1 - ny1 * curb_start,
				x1 - nx1 * curb_end, y1 - ny1 * curb_end,
				curbcol)
			quadfill(
				x0 + nx0 * curb_start, y0 + ny0 * curb_start,
				x0 + nx0 * curb_end, y0 + ny0 * curb_end,
				x1 + nx1 * curb_start, y1 + ny1 * curb_start,
				x1 + nx1 * curb_end, y1 + ny1 * curb_end,
				curbcol)
		end
	end

	if draw_racing_line then
		draw_racing_line_overhead(
			section, segment_idx,
			x0, y0, nx0, ny0,
			x1, y1, nx1, ny1)
	end

	if enable_draw.cars then
		for car in all(cars) do
			if car.section_idx == section_idx and car.segment_idx == segment_idx then

				local car_x = x0 + car.subseg * (x1 - x0)
				local car_y = y0 + car.subseg * (y1 - y0)
	
				-- FIXME: 2x
				car_x += 2 * car.x * (nx0 + car.subseg*(nx1 - nx0))
				car_y += 2 * car.x * (ny0 + car.subseg*(ny1 - ny0))
	
				local sprite_angle = car.track_angle - heading0 - car.subseg*(heading1 - heading0)
	
				add(sprite_list, {
					x=car_x,
					y=car_y,
					angle=sprite_angle,
					palt=11,
					palette=car.palette,
				})
			end
		end
	end

	if enable_draw.walls then

		-- TODO: draw with thickness

		-- local wallcol = 7
		local wallcol = 0

		-- Left
		line(
			x0 + 2 * nx0 * wl0, y0 + 2 * ny0 * wl0,
			x1 + 2 * nx1 * wl1, y1 + 2 * ny1 * wl1,
			wallcol)
		-- Right
		line(
			x0 + 2 * nx0 * wr0, y0 + 2 * ny0 * wr0,
			x1 + 2 * nx1 * wr1, y1 + 2 * ny1 * wr1,
			wallcol)

		local pw = section.pit_wall
		if pw then
			line(
				x0 + 2 * nx0 * pw, y0 + 2 * ny0 * pw,
				x1 + 2 * nx1 * pw, y1 + 2 * ny1 * pw,
				wallcol)
		end
	end

	-- DEBUG: Segment lines

	-- local seg_line_col = 8
	-- if (section.angle_per_seg ~= 0) seg_line_col = 15
	-- line(x0 - nx0 * w, y0 - ny0 * w, x0 + nx0 * w, y0 + ny0 * w, 8)
	-- line(x0, y0, x1, y1, seg_line_col)
end

function draw_sprite_overhead(sprite)

	-- Right now, cars are the only sprites in overhead view

	local angle = -sprite.angle
	local col = sprite.palette[8]

	local dx, dy = cos(angle), sin(angle)
	local nx, ny = -dy, dx

	-- TODO: for some reason this seems to draw slightly skewed

	-- FIXME: 2x (should use car_half_width)
	local xa = sprite.x - nx * overhead_scale * car_width
	local ya = sprite.y - ny * overhead_scale * car_width
	local xb = sprite.x + nx * overhead_scale * car_width
	local yb = sprite.y + ny * overhead_scale * car_width

	local xc = xa + dx * overhead_scale * car_depth
	local yc = ya + dy * overhead_scale * car_depth
	local xd = xb + dx * overhead_scale * car_depth
	local yd = yb + dy * overhead_scale * car_depth

	-- Direction vector
	line(
		sprite.x,
		sprite.y,
		sprite.x + 8 * dx,
		sprite.y + 8 * dy,
		7)

	-- Bounding box
	line(xa, ya, xb, yb, col)
	line(xc, yc, xd, yd, col)
	line(xa, ya, xc, yc, col)
	line(xb, yb, xd, yd, col)

	-- Corners
	pset(xa, ya, 0)
	pset(xb, yb, 0)
	pset(xc, yc, 0)
	pset(xd, yd, 0)
end


function draw_road_overhead()
	clip()

	-- Extra margin for detecting if a segment is close enough to on-screen that we should draw it
	local screen_margin = 1.25 * overhead_scale * road.track_width

	local screen_margin_behind = screen_margin
	-- local screen_margin_behind = 2 * overhead_scale * road.track_width

	local player_car = cars[1]
	local section = road[player_car.section_idx]

	-- Proportion up the screen that the car is, i.e. 4 = 1/4 from the bottom
	local car_y_location_proportion = 6

	local x = 480 \ 2
	local y = (270 * (car_y_location_proportion - 1)) \ car_y_location_proportion
	-- Add angle*subseg to fix judder
	local heading = 0.25 + section.angle_per_seg * player_car.subseg
	y += player_car.subseg * overhead_scale

	-- Sprites
	local sprite_list = {}

	local section_idx, segment_idx = player_car.section_idx, player_car.segment_idx

	-- Reverse a few segments (until offscreen), to draw behind car
	local draw_behind = true
	if draw_behind then
		for i = 1, (draw_distance \ car_y_location_proportion) do
			section_idx, segment_idx = reverse(section_idx, segment_idx)

			local section = road[section_idx]

			local heading1 = heading
			heading += section.angle_per_seg
			heading %= 1.0
			local heading0 = heading

			local dx0, dy0 = overhead_scale * cos(heading0), overhead_scale * sin(heading0)
			local dx1, dy1 = overhead_scale * cos(heading1), overhead_scale * sin(heading1)

			local x1, y1 = x, y
			x -= dx1
			y -= dy1
			local x0, y0 = x, y

			if not (is_on_screen(x0, y0, screen_margin_behind) or is_on_screen(x1, y1, screen_margin_behind)) then
				break
			end
		end
	end

	local initial_section_idx, initial_segment_idx = section_idx, segment_idx

	-- TODO: figure out draw distance to use here
	for i = 1, draw_distance do
	-- for i = 1, 9999 do

		local section = road[section_idx]

		local heading0 = heading
		heading -= section.angle_per_seg
		heading %= 1.0
		local heading1 = heading

		-- Road direction vectors
		-- TODO: optimize this, can use result of previous iteration
		local dx0, dy0 = overhead_scale * cos(heading0), overhead_scale * sin(heading0)
		local dx1, dy1 = overhead_scale * cos(heading1), overhead_scale * sin(heading1)

		local x0, y0 = x, y
		-- TODO: properly make this an isoceles trapezoid
		-- x += 0.5 * (dx0 + dx1)
		-- y += 0.5 * (dy0 + dy1)
		x += dx1
		y += dy1
		local x1, y1 = x, y

		local draw_segment = is_on_screen(x0, y0, screen_margin) or is_on_screen(x1, y1, screen_margin)
		if draw_segment then
			draw_segment_overhead(
				section, section_idx, segment_idx,
				x0, y0, dx0, dy0, heading0,
				x1, y1, dx1, dy1, heading1,
				sprite_list)
		end

		section_idx, segment_idx = advance(section_idx, segment_idx)

		if (section_idx == initial_section_idx and segment_idx == initial_segment_idx) then
			-- Wrapped all the way around
			break
		end
	end

	for sprite in all(sprite_list) do
		draw_sprite_overhead(sprite)
	end
end
