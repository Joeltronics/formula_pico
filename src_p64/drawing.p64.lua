
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

cam_x = 0

function filltrapz(cx1, y1, w1, cx2, y2, w2, col, rotate90)
	-- draw a trapezoid by stacking horizontal lines

	if y2 < y1 then
		cx1, y1, w1, cx2, y2, w2 = cx2, y2, w2, cx1, y1, w1
	end

	-- height
	local h = y2 - y1

	-- width and x deltas
	local xd, wd = (cx2 - cx1) / h, (w2 - w1) / h

	-- current position
	local x, y, w = cx1, y1, w1

	local yadj = ceil(y) - y
	x += yadj * xd
	y += yadj
	w += yadj * wd

	if y <= 0 then
		x += -y * xd
		w += -y * wd
		y = 0
	end

	local ymax
	if rotate90 then
		ymax = min(y2, 479)
	else
		ymax = min(y2, 269)
	end

	while y <= ymax do
		if rotate90 then
			rectfill(y, x - w, y, x + w, col)
		else
			rectfill(x - w, y, x + w, y, col)
		end
		x += xd
		w += wd
		y += 1
	end
end

-- function filltrapz_lr(x1_l, x1_r, y1, x2_l, x2_r, y2, col, rotate90)
-- 	filltrapz(
-- 		(x1_r + x1_l) / 2,
-- 		y1,
-- 		(x1_r - x1_l) / 2,
-- 		(x2_l + x2_r) / 2,
-- 		y2,
-- 		(x2_r - x2_l) / 2,
-- 		col,
-- 		rotate90
-- 	)
-- end

function draw_ground(section, segment_idx, sumct, x1, y1, scale1, x2, y2, scale2)

	local gndcol1 = section.gndcol1 or road.gndcol1 or 3
	local gndcol2 = section.gndcol2 or road.gndcol2 or 11

	local gndcol, gndcol_l, gndcol_r = gndcol1, section.gndcol1l, section.gndcol1r
	if ((sumct % 6) >= 3) gndcol, gndcol_l, gndcol_r = gndcol2, section.gndcol2l, section.gndcol2r
	rectfill(0, y1, 480, y2, gndcol)

	local wl1, wl2, wr1, wr2 = get_wall_locs(section, segment_idx)

	if gndcol_l and (gndcol_l != gndcol) then
		local x = min(
			x1 + 2*scale1*wl1,
			x2 + 2*scale2*wl2)
		rectfill(0, y1, x, y2, gndcol_l)
	end

	if gndcol_r and (gndcol_r != gndcol) then
		local x = max(
			x1 + 2*scale1*wr1,
			x2 + 2*scale2*wr2)
		rectfill(x, y1, 480, y2, gndcol_r)
	end
end

function draw_segment(section, segment_idx, sumct, x1, y1, scale1, x2, y2, scale2, distance)

	detail = (distance <= road_detail_draw_distance)

	y1, yt = ceil(y1), flr(y2)

	if section.tnl then
		if (enable_draw.tunnel) draw_tunnel_walls(x1, y1, scale1, x2, y2, scale2, sumct)
	elseif (y2 >= y1) and enable_draw.ground then
		draw_ground(
			section, segment_idx, sumct,
			x1, y1, scale1, x2, y2, scale2)
	end

	if (y2 < y1 or distance > road_draw_distance) return

	-- Road

	local w1, w2 = road.track_width*scale1, road.track_width*scale2
	local x1l, x1r, x2l, x2r = x1 - w1, x1 + w1, x2 - w2, x2 + w2

	-- TODO: pit lane over-draws, which wastes a bunch of extra CPU cycles
	local pit1 = (section.pit + segment_idx*section.dpit) * scale1 * pit_lane_width
	local pit2 = (section.pit + (segment_idx - 1)*section.dpit) * scale2 * pit_lane_width
	if section.pit ~= 0 then
		if ((pit1 ~= 0 or pit2 ~= 0) and enable_draw.road) filltrapz(x1 + pit1, y1, w1, x2 + pit2, y2, w2, 5)
	end

	if (enable_draw.road) filltrapz(x1, y1, w1, x2, y2, w2, 5)

	if (enable_draw.debug_extra and (detail or not enable_draw.road)) line(x2 - w2, y2, x2 + w2, y2, 6)

	-- Start/finish line

	if sumct == road[1].length + 1 and enable_draw.road then
		if detail then
			fillp(
				0b00001111,
				0b00001111,
				0b00001111,
				0b00001111,
				0b11110000,
				0b11110000,
				0b11110000,
				0b11110000)
			-- Just fill 1st 50% of segment
			filltrapz(
				x1, flr(y1 + 0.5*(y2 - y1)), 0.5*(w2 + w1),
				x2, ceil(y2), w2,
				0x07)
			fillp()
		else
			fillp(0b0101101001011010)
			filltrapz(x1, y1, w1, x2, y2, w2, 0x07)
		end
	end
	fillp()

	if enable_draw.curbs then
		-- Curbs

		if section.dpit ~= 0 then
			-- Pit entrance/exit
			if max(pit1, pit2) > 0 then
				x1r += pit1
				x2r += pit2
			else
				x1l += pit1
				x2l += pit2
			end
		end

		if detail then
			local linecol = 7
			if (sumct % 2 == 0) linecol = 8
			local sw1, sw2 = shoulder_half_width*scale1, shoulder_half_width*scale2
			filltrapz(x1l, y1, sw1, x2l, y2, sw2, linecol)
			filltrapz(x1r, y1, sw1, x2r, y2, sw2, linecol)
		else
			fillp(0b0101101001011010)
			line(x1l, y1, x2l, y2, 0x060e)
			line(x1r, y1, x2r, y2, 0x060e)
			fillp()
		end

		-- Lane lines

		local lanes = section.lanes or road.lanes
		if (sumct % 4) == 0 then
			for lane_idx = 1,lanes-1 do

				local lx_rel = 2*lane_idx/lanes - 1
				local lx1, lx2 = x1 + w1*lx_rel, x2 + w2*lx_rel

				if detail then
					local cw1, cw2 = lane_line_width*scale1, lane_line_width*scale2
					filltrapz(lx1, y1, cw1, lx2, y2, cw2, 7)
				else
					line(lx1, ceil(y1), lx2, y2, 6)
				end
			end
		end
	end
	fillp()

	-- TODO: draw start boxes for first segment

	-- Racing line

	if (not draw_racing_line) return

	local speed = cars[1].speed

	local col = 11
	if (section.max_speed < 0.999 and speed > section.max_speed - 0.01) col = 10
	if (need_to_brake(section, segment_idx, 0, speed, cars[1].grip)) col = 2
	if (section.max_speed < 0.999 and speed > section.max_speed + 0.01) col = 8

	local dx1 = section.entrance_x + segment_idx*section.racing_line_dx
	local dx2 = section.entrance_x + (segment_idx - 1)*section.racing_line_dx
	if (racing_line_sine_interp) then
		dx1, dx2 = sin(dx1), sin(dx2)
	end
	line(x1 + w1*dx1, y1, x2 + w2*dx2, y2, col)
end

function get_tunnel_rect(x, y, scale)
	local w, h = (2*road.track_width + 0.4)*scale, 4*scale
	local x1, y1, x2, y2 = ceil(x - w/2), ceil(y - h), ceil(x + w/2), ceil(y)
	return x1, y1, x2, y2
end

function clip_to_tunnel(px,py,scale,clp)
	local x1, y1, x2, y2 = get_tunnel_rect(px, py, scale)
	clp[1] = max(clp[1], x1)
	clp[2] = max(clp[2], y1)
	clp[3] = min(clp[3], x2)
	clp[4] = min(clp[4], y2)
end

function draw_tunnel_face(section, x, y, scale)
	local x1, y1, x2, y2 = get_tunnel_rect(x, y, scale)

	-- Face top
	local wh = (section.tnl_height or 8) * scale
	local face_top_y = ceil(y - wh)

	-- Left & right bounds
	local face_x1 = 0
	local face_x2 = 479
	if (section.tnl_l) face_x1 = max(0, x1 - scale * section.tnl_l)
	if (section.tnl_r) face_x2 = min(479, x2 + scale * section.tnl_r)

	-- Draw the faces
	if(y1 > 0) rectfill(face_x1, face_top_y, face_x2, y1-1, 6) -- Top
	if(x1 > 0) rectfill(face_x1, y1, x1-1, y2-1, 6) -- Left
	if(x2 < 480) rectfill(x2, y1, face_x2, y2-1, 6) -- Right
end

function draw_tunnel_walls(x1, y1, scale1, x2, y2, scale2, sumct)
	local col = 0
	if(sumct % 4 < 2) col = 1

	local x11, y11, x12, y12 = get_tunnel_rect(x1, y1, scale1)
	local x21, y21, x22, y22 = get_tunnel_rect(x2, y2, scale2)

	if(y11 > y21) rectfill(x11, y11, x12-1, y21-1, col) -- top
	if(x11 > x21) rectfill(x11, y21, x21-1, y22-1, col) -- left
	if(x12 < x22) rectfill(x22, y21, x12-1, y22-1, col) -- right
end

function setclip(clp)
	clip(clp[1], clp[2], clp[3]-clp[1], clp[4]-clp[2])
end

function draw_building(section, sumct, bg, side, px, py, scale, clp, wall)

	local pos = bg.pos or {0, 999}
	local height = pos[2]

	px += 3*scale*side + pos[1]*scale*side

	if (wall) px += 2*scale*wall

	local y0 = max(clp[2], py - height*scale)
	local y1 = min(clp[4], py)

	if y1 >= y0 then

		local x0, xy
		if side < 0 then
			-- Left side
			x0 = max(0, clp[1])
			x1 = ceil(px)
		else
			-- Right side
			x0 = flr(px - 1)
			x1 = min(clp[3], 480)
		end

		local col = section.gndcol1 or road.gndcol1 or 3
		if ((sumct % 6) >= 3) col = section.gndcol2 or road.gndcol2 or 11

		if x1 >= x0 then
			-- clip()
			-- setclip(clp)
			rectfill(x0, y0, x1, y1, col)
			-- clip()
		end
	end

	return px
end

function add_sprite(sprite_list, sumct, segment_idx, bg, side, px, py, scale, clp, wall)

	if (not bg) return

	if (bg.building) return -- Already dealt with

	if bg.spacing then
		if bg.spacing == 0 then
			if (segment_idx ~= 1) return
		elseif (sumct % bg.spacing) ~= 0 then
			return
		end
	end

	-- find position

	px += 3*scale*side
	if bg.pos then
		px += bg.pos[1]*scale*side
		py += bg.pos[2]*scale
	end

	local w, h = bg.siz[1]*scale, bg.siz[2]*scale

	if (wall) px += 2*scale*wall + 0.5*w*side

	local bounds = {
		round(px - 0.5*w),
		round(py - h),
		round(px + 0.5*w),
		round(py)
	}

	-- Don't add if completely outside clp
	if (bounds[1] > clp[3] or bounds[3] < clp[1] or bounds[2] > clp[4] or bounds[4] < clp[2]) return

	add(sprite_list, {
		bounds=bounds,
		w=w,
		h=h,
		sprite=bg.sprite,
		palette=bg.palette,
		palt=bg.palt or bg.sprite.palt,
		flip_x=(bg.flip or side > 0 and bg.flip_r),
		clp={clp[1],clp[2],clp[3],clp[4]}
	})
end

function get_wall_locs(section, segment_idx)
	local wl1 = section.wall_l + section.dwall_l * (segment_idx - 1)
	local wl2 = section.wall_l + section.dwall_l * segment_idx

	local wr1 = section.wall_r + section.dwall_r * (segment_idx - 1)
	local wr2 = section.wall_r + section.dwall_r * segment_idx

	return wl1, wl2, wr1, wr2
end

function add_wall(sprite_list, section, segment_idx, sumct, x2, y2, scale2, x1, y1, scale1, clp, detail)

	local col = section.wallcol1 or road.wallcol1 or 6
	if ((sumct % 6) >= 3) col = section.wallcol1 or road.wallcol1 or 7

	-- TODO: invisible walls if very far out

	local wl1, wl2, wr1, wr2 = get_wall_locs(section, segment_idx)

	local walls={{wl1, wl2}, {wr1, wr2}}

	if section.pit_wall then
		add(walls, {section.pit_wall, section.pit_wall})
	end

	-- local wall_l1 = section.wall_l + section.dwall_l * (segment_idx - 1)
	-- local wall_l2 = section.wall_l + section.dwall_l * segment_idx
	-- local wall_r1 = section.wall_r + section.dwall_r * (segment_idx - 1)
	-- local wall_r2 = section.wall_r + section.dwall_r * segment_idx

	add(sprite_list, {
		walls=walls,
		col=col,
		detail=detail,
		x1=x1, y1=y1, scale1=scale1,
		x2=x2, y2=y2, scale2=scale2,
		clp={clp[1],clp[2],clp[3],clp[4]}
	})
end

function draw_wall(s)

	local h1, h2 = s.scale1, s.scale2

	for w in all(s.walls) do
		local x1, x2 = s.x1 + 2*s.scale1*w[1], s.x2 + 2*s.scale2*w[2]
		if s.detail then
			filltrapz(s.y1 - 0.5*h1, x1, 0.5*h1, s.y2 - 0.5*h2, x2, 0.5*h2, s.col, true) -- Fill
		else
			line(x1, s.y1 - 0.5*h1, x2, s.y2 - 0.5*h2, s.col)
			if h1 > 2.5 then
				line(x1, s.y1 - 0.25*h1, x2, s.y2 - 0.25*h2, s.col)
				line(x1, s.y1 - 0.75*h1, x2, s.y2 - 0.75*h2, s.col)
			end
		end
		line(x1, s.y1, x2, s.y2, 6) -- Bottom
		line(x1, s.y1 - h1, x2, s.y2 - h2, 6) -- Top
	end
end

function add_car_sprite(sprite_list, car, segment_idx, x, y, scale, clp)

	-- TODO: may want to offset drawing location by 1 pixel in some cases?
	-- TODO: use track x value to add extra turn? (i.e. cars ahead after a corner)

	local car_abs_x = abs(car.x)

	if car.speed > 0 then
		-- if car_abs_x >= road[car.section_idx].wall then
		-- 	-- Touching wall
		-- 	-- TODO: add smoke, or other indicator of scraping
		-- end
		if car.off_track then
			y -= flr(rnd(2))
			-- TODO: add "flinging grass" sprite
		elseif car.on_curb and car.subseg < 0.5 then
			y -= 1
		end
	end

	local sprite_turn = car.track_angle - cam_angle_scale * cars[1].track_angle
	sprite_turn *= track_angle_sprite_turn_scale

	-- TODO: don't have to add integers, can add fractional amount
	local d_center = x - 240
	if (abs(d_center) > 32) sprite_turn -= sgn(d_center)
	if (abs(d_center) > 96) sprite_turn -= sgn(d_center)

	local palette = car.palette

	-- Tail light on/off
	if (car.engine_accel_brake <= 0) then
		-- Palettes aren't reused, so don't actually need to copy
		-- palette = shallowcopy(palette)
		palette[15] = 8
	else
		palette[15] = 0
	end

	add_sprite(
		sprite_list, sumct, segment_idx,
		{
			sprite=sprites.car[min(#sprites.car, 1 + round(abs(sprite_turn)))],
			siz={car_draw_width, car_draw_height},
			palt=11,
			palette=palette,
			flip=sprite_turn < 0,
		},
		0, x, y, scale, clp)
end

function draw_sprite(s)

	setclip(s.clp)

	if s.palt then
		palt(0, false)
		palt(s.palt, true)
	end

	if (s.palette) pal(s.palette, 0)

	if s.walls then
		draw_wall(s)
	else
		local x1 = s.bounds[1]
		local y1 = s.bounds[2]
		local x2 = s.bounds[3]
		local y2 = s.bounds[4]

		sspr(
			s.sprite.bmp,
			0, 0, s.sprite.width, s.sprite.height, -- sx, sy, sw, sh
			x1, y1, x2-x1, y2-y1, -- dx, dy, dw, dh
			s.flip_x  -- flip_x
		)
	end

	if (s.palt and not s.palette) palt()
	if (s.palette) pal()
end

function draw_road()

	local player_car = cars[1]
	local section = road[player_car.section_idx]

	-- direction
	-- TODO: look ahead a bit more than this to determine camera
	local camang = player_car.subseg * section.tu
	local xd, zd = -camang, 1
	local yd = -(section.pitch + section.dpitch*(player_car.segment_idx - 1))

	xd += sin(cam_angle_scale * player_car.track_angle)
	zd *= cos(cam_angle_scale * player_car.track_angle)

	-- Starting coords

	-- TODO: if off track, move camera even further to make sure car is in frame
	cam_x = cam_x_scale * player_car.x * (2 / road.track_width)

	-- TODO: figure out which is the better way to do this
	-- Option 1
	-- local cx, cy, cz = skew(road.track_width*cam_x, 0, player_car.subseg, xd, yd)
	-- local x, y, z = -cx, -cy + cam_dy, -cz + cam_dz
	-- Option 2
	local cx, cy, cz = skew(0, 0, player_car.subseg, xd, yd)
	local x, y, z = -cx - road.track_width*cam_x, -cy + cam_dy, -cz + cam_dz

	-- sprites
	local sp = {}

	-- current clip region
	local clp = {0, 0, 480, 270}
	local clp_prev = {0, 0, 480, 270}
	clip()

	-- Draw road segments

	local section_idx, segment_idx = player_car.section_idx, player_car.segment_idx

	-- Start 1 segment behind the player - walls and other cars have a problem with pop-in
	-- TODO: enable this - currently leads to lots of judder on corners (need to deal with skew?)
	if false then
		section_idx, segment_idx = reverse(section_idx, segment_idx - 1)
		-- TODO: why is this 2x?
		x -= 2*xd
		y -= 2*yd
		z -= 2*zd
	end

	local x1, y1, scale1 = project(x, y, z)

	local section = road[section_idx]

	local ptnl = section.tnl

	-- TODO: try dynamic draw distance, i.e. stop rendering at certain CPU pct
	for i = 1, draw_distance do

		local x_prev, y_prev, z_prev = x, y, z

		x += xd
		y += yd
		z += zd

		local x2, y2, scale2 = project(x, y, z)

		local sumct = section.sumct + segment_idx

		local tnl = section.tnl
		if tnl and not ptnl then
			if (enable_draw.tunnel) draw_tunnel_face(section, x1, y1, scale1)
			clip_to_tunnel(x1, y1, scale1, clp)
			setclip(clp)
		end

		draw_segment(section, segment_idx, sumct, x2, y2, scale2, x1, y1, scale1, i)

		local bld_l, bld_r = nil, nil
		if enable_draw.tunnel then
			if section.bgl and section.bgl.building then
				bld_l = draw_building(section, sumct, section.bgl, -1, x2, y2, scale2, clp, wl2)
			end
			if section.bgr and section.bgr.building then
				bld_r = draw_building(section, sumct, section.bgr, 1, x2, y2, scale2, clp, wr2)
			end
		end

		if i < sprite_draw_distance then
			if sumct == road[1].length and enable_draw.bg_sprites then
				add_sprite(sp, sumct, segment_idx, bg_objects['finishline_post'], -1, x2, y2, scale2, clp)
				add_sprite(sp, sumct, segment_idx, bg_objects['finishline_post'],  1, x2, y2, scale2, clp)
				add_sprite(sp, sumct, segment_idx, bg_objects['finishline_lr'],   -1, x2, y2, scale2, clp)
				add_sprite(sp, sumct, segment_idx, bg_objects['finishline_c'],     0, x2, y2, scale2, clp)
				add_sprite(sp, sumct, segment_idx, bg_objects['finishline_lr'],    1, x2, y2, scale2, clp)
			end

			local wl2 = section.wall_l + section.dwall_l * segment_idx
			local wr2 = section.wall_r + section.dwall_r * segment_idx
			assert(wl2 < 0 and wr2 > 0)

			if enable_draw.bg_sprites then
				add_sprite(sp, sumct, segment_idx, section.bgl, -1, x2, y2, scale2, clp, wl2)
				add_sprite(sp, sumct, segment_idx, section.bgc,  0, x2, y2, scale2, clp)
				add_sprite(sp, sumct, segment_idx, section.bgr,  1, x2, y2, scale2, clp, wr2)
			end

			-- Iterate in reverse order of car positions, in order to prevent Z-order problems
			-- TODO: optimize this, don't need to iterate all cars every segment
			-- FIXME: there still could be z-order problems if 1 car is lapped
			for pos = #car_positions,1,-1 do
				local car = cars[car_positions[pos]]
				if car.section_idx == section_idx and car.segment_idx == segment_idx and enable_draw.cars then
					-- TODO: figure out why 2x is necessary - seem to be confusing width & half-width somewhere
					local car_x = x_prev + car.subseg * xd + 2*car.x
					local car_y = y_prev + car.subseg * yd
					local car_z = z_prev + car.subseg * zd
					local this_car_screen_x, this_car_screen_y, this_car_scale = project(car_x, car_y, car_z)
					add_car_sprite(sp, car, segment_idx, this_car_screen_x, this_car_screen_y, this_car_scale, clp)
				end
			end
		end

		if i < wall_draw_distance and (not section.tnl) and enable_draw.walls then
			-- TODO: I think there's an off by 1 error here
			-- (Why do we have to use previous section's clip rectangle?)
			-- Also visible at tunnel entrance/exit
			add_wall(sp, section, segment_idx, sumct, x2, y2, scale2, x1, y1, scale1, clp_prev, i < road_detail_draw_distance)
		end

		-- TODO: setting this before add_wall doesn't work - why?!
		clp_prev = {clp[1], clp[2], clp[3], clp[4]}

		-- Reduce clip region
		if tnl then
			clip_to_tunnel(x2, y2, scale2, clp)
		else
			if bld_l then
				clp[1] = max(clp[1], bld_l)
			end
			if bld_r then
				clp[3] = min(clp[3], bld_r)
			end

			clp[4] = min(clp[4], ceil(y2))
		end

		-- Stop drawing if the clip window size is zero
		if (clp[3] <= clp[1] or clp[4] <= clp[2]) break

		setclip(clp)

		-- Advance
		xd += section.tu
		yd -= section.dpitch
		section_idx, segment_idx = advance(section_idx, segment_idx)
		section = road[section_idx]
		x1, y1, scale1 = x2, y2, scale2
		ptnl = tnl
	end

	-- Draw sprites

	for i = #sp, 1, -1 do
		draw_sprite(sp[i])
	end

	clip()

	if enable_draw.debug_extra then

		local playerx, subseg = player_car.x, player_car.subseg

		local xd, zd, yd = -camang, 1, -(section.pitch + section.dpitch*(player_car.segment_idx - 1))

		xd += sin(cam_angle_scale * player_car.track_angle)
		zd *= cos(cam_angle_scale * player_car.track_angle)

		local cx, cy, cz = skew(0, 0, subseg, xd, yd)
		local x, y, z = -cx - road.track_width*cam_x, -cy + cam_dy, -cz + cam_dz
		local x1, y1, scale1 = project(x, y, z)
		local x2, y2, scale2 = project(x + xd, y + yd, z + zd)

		-- TODO: these need skew to be applied differently
		local x_rel_1, y_rel_1, scale1 = project(x + xd*subseg, y + yd*subseg, z + subseg)
		local x_rel_2, y_rel_2, scale2 = project(x + xd*(1+subseg), y + yd*(1+subseg), z + zd + subseg)

		-- On-track X Ruler
		for n = -5, 5 do
			local linecol = 15
			if (n == 0) linecol = 14
			line(
				x_rel_1 - n*scale1, y_rel_1,
				x_rel_2 - n*scale2, y_rel_2,
				linecol)
		end

		-- Draw hitboxes/clipping info

		-- TODO: if there's slope, also draw that

		local car_rear_x, car_rear_y, car_rear_scale = project(
			x + subseg * xd + 2*playerx,
			y + subseg * yd,
			z + subseg * zd)

		local car_front_x, car_front_y, car_front_scale = project(
			x + subseg * xd + 2*playerx,
			y + (subseg + car_depth) * yd,
			z + (subseg + car_depth) * zd)

		local car_front_x_level, car_front_y_level, car_front_scale_level = project(
			x + subseg * xd + 2*playerx,
			y + subseg * yd,
			z + (subseg + car_depth) * zd)

		local car_rear_left_x = car_rear_x - car_width*car_rear_scale
		local car_rear_right_x = car_rear_x + car_width*car_rear_scale
		local car_front_left_x = car_front_x - car_width*car_front_scale
		local car_front_right_x = car_front_x + car_width*car_front_scale
		local car_front_left_x_level = car_front_x_level - car_width*car_front_scale_level
		local car_front_right_x_level = car_front_x_level + car_width*car_front_scale_level

		-- Hitbox if car was level
		line(car_front_left_x_level, car_front_y_level, car_front_right_x_level, car_front_y_level, 15)
		line(car_front_left_x_level, car_front_y_level, car_front_left_x, car_front_y, 15)
		line(car_front_right_x_level, car_front_y_level, car_front_right_x, car_front_y, 15)
		line(car_rear_left_x, car_rear_y, car_front_left_x_level, car_front_y_level, 15)
		line(car_rear_right_x, car_rear_y, car_front_right_x_level, car_front_y_level, 15)

		-- Hitbox on ground
		line(car_rear_left_x, car_rear_y, car_rear_right_x, car_rear_y, 10)
		line(car_front_left_x, car_front_y, car_front_right_x, car_front_y, 10)
		line(car_rear_left_x, car_rear_y, car_front_left_x, car_front_y, 10)
		line(car_rear_right_x, car_rear_y, car_front_right_x, car_front_y, 10)

		local lx, rx, front = player_car.other_car_data.lx, player_car.other_car_data.rx, player_car.other_car_data.front
		if lx then
			line(
				x1 + 2*(lx + car_half_width)*scale1, y1,
				x2 + 2*(lx + car_half_width)*scale2, y2,
				12)
		end
		if rx then
			line(
				x1 + 2*(rx - car_half_width)*scale1, y1,
				x2 + 2*(rx - car_half_width)*scale2, y2,
				8)
		end
		if front then
			local front_x, front_y, front_scale = project(
				x + (subseg + front.dz_ahead) * xd + 2*playerx,
				y + (subseg + front.dz_ahead) * yd,
				z + subseg + front.dz_ahead * zd)

			line(
				front_x - front_scale*car_width, front_y,
				front_x + front_scale*car_width, front_y,
				9
			)
		end
		-- TODO: next car too
	end
end

function draw_bg()
	clip()

	-- TODO: use the map for this, don't redraw every frame
	-- TODO: draw some hills

	local section = road[cars[1].section_idx]
	-- local horizon = 64 + 32*(section.pitch + section.dpitch*(cars[1].segment_idx - 1))
	-- TODO picotron: double check these numbers
	local horizon = 135 + 64*(section.pitch + section.dpitch*(cars[1].segment_idx - 1))

	-- Sky
	cls(12)

	-- Horizon
	if enable_draw.horizon_ground then
		local horizon_col = 256*(road.gndcol1 or 3) + (road.gndcol2 or 11)
		fillp(0b0011110000111100)
		rectfill(0, horizon, 480, 270, horizon_col)
		fillp()
	end

	-- Sun
	local sun_x = (cars[1].heading * 1920 + 720) % 1920 - 960
	if sun_x >= -64 and sun_x <= (480 + 64) then
		circfill(sun_x, horizon - 52, 8, 10)
	end

	-- Trees/Buildings
	local spr1, spr2
	if (road.tree_bg) spr1, spr2 = sprites.tree_bg_1.bmp, sprites.tree_bg_2.bmp
	if (road.city_bg) spr1, spr2 = sprites.city_bg_1.bmp, sprites.city_bg_2.bmp

	if spr1 and enable_draw.horizon_objects then
		for off = -64,480,64 do
			local x, y = sun_x % 64 + off, horizon - 7
			spr(spr1, x     , y)
			spr(spr2, x + 8 , y)
			spr(spr1, x + 16, y, true)
			spr(spr2, x + 24, y, true)
			spr(spr1, x + 32, y)
			spr(spr2, x + 40, y, true)
			spr(spr1, x + 48, y, true)
			spr(spr2, x + 56, y)
		end
	end
end

function draw_ranking()
	-- TODO: may only want to print 4 cars (self, leader, and cars before/after)
	cursor()
	palt(0, false)
	palt(11, true)
	for pos_num = 1,#car_positions do

		local y = 1 + 10 * (pos_num - 1)

		cursor(0, y)

		local car_idx = car_positions[pos_num]
		local car = cars[car_idx]
		local bgcol, fgcol = digit_to_hex_char(car.palette[8]), digit_to_hex_char(car.palette[14])

		-- For now, just use car index as car number
		local text = '\#0\f7' .. pos_num .. '\-h\#' .. bgcol .. '\f' .. fgcol .. car_idx .. '\-h\#0\f7'

		-- TODO: figure out approx time delta and print it (instead of number of laps; "1 lap" or something if lapped)

		if car.finished then
			text = text .. '▒'
		elseif car.in_pit then
			text = text .. 'pit'
		else
			text = text .. (1 + car.laps)
		end

		print(text .. '\0')
		-- Player indicator (separate print call, to reset background)
		if car_idx == 1 then
			print('\22\0')
		else
			-- local x, y = peek(0x5f26), peek(0x5f27)
			local x = 18
			local compound = tire_compounds[car.tire_compound_idx]

			-- TODO: more granular than this? (i.e. use all the colors)

			pal(compound.pal)
			spr(sprites.tire_small.bmp, x, y)

			clip(0, y, 480, round(8 - 8 * car.tire_health))
			pal(10, 0)
			spr(sprites.tire_small.bmp, x, y)
			clip()
		end
		-- print('\n\0')
	end
	pal()
	palt()
end

function draw_race_start_lights()
	palt(0, false)
	for i = 1,5 do
		if (i == 1 + race_start_num_lights) pal(palette_race_start_light_out)
		spr(sprites.race_start_light.bmp, 240 - 18*2.5 + 18*(i - 1), 48)
		spr(sprites.race_start_light.bmp, 240 - 18*2.5 + 18*(i - 1), 48 + 16)
	end
	pal()
end

function draw_hud()

	local player_car = cars[1]

	if #cars > 1 then
		draw_ranking()
	end

	if (not race_started) draw_race_start_lights()

	-- Speed & gear

	cursor(460, 250, 7)
	local speed_print = '' .. round(player_car.speed * speed_to_kph)
	if (#speed_print == 1) speed_print = ' ' .. speed_print
	if (#speed_print == 2) speed_print = ' ' .. speed_print
	print(speed_print .. '\nKPH')

	cursor(450, 254)
	print(player_car.gear)

	-- Tire status

	palt(0, false)
	palt(11, true)

	pal({[10]=0,[9]=0})
	-- spr(sprites.tire_large.bmp, 0, 270 - 16)
	spr(sprites.tire_large.bmp, 0, 270 - 32)

	-- Tire sprite is 16 tall, but colored band is 12 tall, so it starts at (y + 2) and ends at (y + 14)
	-- FIXME: for larger sprite, 32 tall but band is 26
	pal(tire_compounds[player_car.tire_compound_idx].pal)
	-- clip(0, 270 - 16 + 14 - ceil(12 * player_car.tire_health), 480, 270)
	clip(0, 270 - 32 + 29 - ceil(26 * player_car.tire_health), 480, 270)
	-- spr(sprites.tire_large.bmp, 0, 270 - 16)
	spr(sprites.tire_large.bmp, 0, 270 - 32)

	clip()
	palt()
	pal()
end

function draw_cpu_only_overlay()
	cursor(445, 0, 5)
	print("cpu:" .. round(stat(1) * 100))
end
