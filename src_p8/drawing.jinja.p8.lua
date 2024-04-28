
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

	local ymax = min(y2, 127)
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

function draw_ground(y1, y2, sumct, gndcol1, gndcol2)
	local gndcol = gndcol1
	if ((sumct % 6) >= 3) gndcol = gndcol2
	rectfill(0, y1, 128, y2, gndcol)
end

function draw_segment(section, seg, sumct, x1, y1, scale1, x2, y2, scale2, distance)

	detail = (distance <= "{{ road_detail_draw_distance }}")

	y1, yt = ceil(y1), flr(y2)

	if section.tnl then
		draw_tunnel_walls(x1, y1, scale1, x2, y2, scale2, sumct)
	elseif (y2 >= y1) then
		draw_ground(y1, y2, sumct,
			section.gndcol1 or road.gndcol1 or 3,
			section.gndcol2 or road.gndcol2 or 11)
	end

	if (y2 < y1 or distance > "{{ road_draw_distance }}") return

	-- Road

	local w1, w2 = road.track_width*scale1, road.track_width*scale2
	local x1l, x1r, x2l, x2r = x1 - w1, x1 + w1, x2 - w2, x2 + w2

	local pit1 = section.pit + seg*section.dpit
	local pit2 = section.pit + (seg - 1)*section.dpit
	-- if (pit1 ~= 0 or pit2 ~= 0) filltrapz(x1 + pit1*scale1*"{{ pit_lane_width }}", y1, w1, x2 + pit2*scale2*"{{ pit_lane_width }}", y2, w2, 5)
	pit1 *= scale1 * "{{ pit_lane_width }}"
	pit2 *= scale2 * "{{ pit_lane_width }}"
	if (pit1 ~= 0 or pit2 ~= 0) filltrapz(x1 + pit1, y1, w1, x2 + pit2, y2, w2, 5)

	filltrapz(x1, y1, w1, x2, y2, w2, 5)

	-- Start/finish line

	if (not detail) fillp(0b0101101001011010)

	if sumct == road[1].length + 1 then
		if detail then
			fillp(0b0011001111001100)
			-- Just fill 1st 50% of segment
			filltrapz(
				x1, flr(y1 + 0.5*(y2 - y1)), w1,
				x2, ceil(y2), w2,
				0x07)
			fillp()
		else
			filltrapz(x1, y1, w1, x2, y2, w2, 0x07)
		end
	end

	-- Curbs

	if section.dpit ~= 0 then
		-- Pit entrance/exit
		if max(pit1, pit2) > 0 then
			-- TODO
			x1r += pit1
			x2r += pit2
		else
			-- TODO: is sign right?
			x1l += pit1
			x2l += pit2
		end
	end

	if detail then
		local linecol = 7
		if (sumct % 2 == 0) linecol = 8
		local sw1, sw2 = "{{ shoulder_half_width }}"*scale1, "{{ shoulder_half_width }}"*scale2
		-- filltrapz(x1-w1, y1, sw1, x2-w2, y2, sw2, linecol)
		-- filltrapz(x1+w1, y1, sw1, x2+w2, y2, sw2, linecol)
		filltrapz(x1l, y1, sw1, x2l, y2, sw2, linecol)
		filltrapz(x1r, y1, sw1, x2r, y2, sw2, linecol)
	else
		-- line(x1-w1, y1, x2-w2, y2, 0x6e)
		-- line(x1+w1, y1, x2+w2, y2, 0x6e)
		line(x1l, y1, x2l, y2, 0x6e)
		line(x1r, y1, x2r, y2, 0x6e)
		fillp()
	end

	-- Lane lines

	local lanes = section.lanes or road.lanes
	if (sumct % 4) == 0 then
		for lane_idx = 1,lanes-1 do

			local lx_rel = 2*lane_idx/lanes - 1
			local lx1, lx2 = x1 + w1*lx_rel, x2 + w2*lx_rel

			if detail then
				local cw1, cw2 = "{{ lane_line_width }}"*scale1, "{{ lane_line_width }}"*scale2
				filltrapz(lx1, y1, cw1, lx2, y2, cw2, 7)
			else
				line(lx1, ceil(y1), lx2, y2, 6)
			end
		end
	end

	-- TODO: draw start boxes for first segment

	-- Racing line

	if (not draw_racing_line) return

	local speed = cars[1].speed

	local col = 11
	if (section.max_speed < 0.999 and speed > section.max_speed - 0.01) col = 10
	if (need_to_brake(section, seg, 0, speed, cars[1].grip)) col = 2
	if (section.max_speed < 0.999 and speed > section.max_speed + 0.01) col = 8

	local dx1 = section.entrance_x + seg*section.racing_line_dx
	local dx2 = section.entrance_x + (seg - 1)*section.racing_line_dx
--% if racing_line_sine_interp
	dx1, dx2 = sin(dx1), sin(dx2)
--% endif
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

function draw_tunnel_face(x, y, scale)
	local x1, y1, x2, y2 = get_tunnel_rect(x, y, scale)

	-- tunnel wall top
	-- TODO: variable tunnel height per section
	local wh = 8*scale
	local wy = ceil(y - wh)

	-- faces
	if(y1 > 0) rectfill(0, wy, 128, y1-1, 6)
	if(x1 > 0) rectfill(0, y1, x1-1, y2-1, 6)
	if(x2 < 128) rectfill(x2, y1, 127, y2-1, 6)
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

function add_bg_sprite(sprite_list, sumct, seg, bg, side, px, py, scale, clp)

	if (not bg) return

	if bg.spacing then
		if bg.spacing == 0 then
			if (seg ~= 1) return
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

	add(sprite_list, {
		x=px,
		y=py,
		w=w,
		h=h,
		img=bg.img,
		palette=bg.palette,
		palt=bg.palt,
		flip_x=bg.flip,
		clp={clp[1],clp[2],clp[3],clp[4]}
	})
end

function add_wall(sprite_list, section, seg, sumct, x2, y2, scale2, x1, y1, scale1, clp, detail)

	local col = section.wallcol1 or road.wallcol1 or 6
	if ((sumct % 6) >= 3) col = section.wallcol1 or road.wallcol1 or 7

	-- TODO: invisible walls if very far out

	local walls={{
		section.wall_l + section.dwall_l * (seg - 1),
		section.wall_l + section.dwall_l * seg
	}, {
		section.wall_r + section.dwall_r * (seg - 1),
		section.wall_r + section.dwall_r * seg
	}}

	if section.pit_wall then
		add(walls, {section.pit_wall, section.pit_wall})
	end

	-- local wall_l1 = section.wall_l + section.dwall_l * (seg - 1)
	-- local wall_l2 = section.wall_l + section.dwall_l * seg
	-- local wall_r1 = section.wall_r + section.dwall_r * (seg - 1)
	-- local wall_r2 = section.wall_r + section.dwall_r * seg

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

	local h1, h2 = s.scale1 / 2, s.scale2 / 2
	local cy1, cy2 = s.y1 - h1, s.y2 - h2

	for w in all(s.walls) do
		local x1, x2 = s.x1 + 2*s.scale1*w[1], s.x2 + 2*s.scale2*w[2]
		if s.detail then
			filltrapz(cy1, x1, h1, cy2, x2, h2, s.col, true) -- Fill
			line(x1, s.y1, x2, s.y2, 6) -- Bottom
		else
			line(x1, cy1, x2, cy2, s.col) -- Center
		end
		line(x1, s.y1 - 2*h1, x2, s.y2 - 2*h2, 6) -- Top
	end
end

function add_car_sprite(sprite_list, car, seg, x, y, scale, clp)

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
	sprite_turn *= "{{ track_angle_sprite_turn_scale }}"

	-- TODO: don't have to add integers, can add fractional amount
	local d_center = x - 64
	if (abs(d_center) > 16) sprite_turn -= sgn(d_center)
	if (abs(d_center) > 48) sprite_turn -= sgn(d_center)

	add_bg_sprite(
		sprite_list, sumct, seg,
		{
			img={
				24 * min(3, round(abs(sprite_turn))),
				0, 24, 16},
			siz={"{{ car_draw_width }}", "{{ car_draw_height }}"},
			palt=11,
			palette=car.palette,
			flip=sprite_turn < 0,
		},
		0, x, y, scale, clp)
end

function draw_bg_sprite(s)

	setclip(s.clp)

	if s.palt then
		palt(0, false)
		palt(s.palt, true)
	end

	if (s.palette) pal(s.palette, 0)

	if s.walls then
		draw_wall(s)
	else
		local x1=ceil(s.x-s.w/2)
		local x2=ceil(s.x+s.w/2)
		local y1=ceil(s.y-s.h)
		local y2=ceil(s.y)

		sspr(
			s.img[1], s.img[2], s.img[3], s.img[4], -- sx, sy, sw, sh
			x1, y1, x2-x1, y2-y1, -- dx, dy, dw, dh
			s.flip_x  -- flip_x
		)
	end

	-- Don't know how slow these are - might be worth saving the tokens and juist always calling pal()?
	if (s.palt and not s.palette) palt()
	if (s.palette) pal()
end

function draw_road()

	local player_car = cars[1]
	local section_idx, segment_idx, subseg = player_car.section_idx, player_car.segment_idx, player_car.subseg
	local section, sect, seg = road[section_idx], section_idx, segment_idx

	-- direction
	-- TODO: look ahead a bit more than this to determine camera
	local camang = subseg * section.tu
	local xd, zd = -camang, 1
	local yd = -(section.pitch + section.dpitch*(segment_idx - 1))

	xd += sin(cam_angle_scale * player_car.track_angle)
	zd *= cos(cam_angle_scale * player_car.track_angle)

	-- Starting coords

	-- TODO: if off track, move camera even further to make sure car is in frame
	cam_x = cam_x_scale * player_car.x * (2 / road.track_width)

	-- TODO: figure out which is the better way to do this
	-- Option 1
	-- local cx, cy, cz = skew(road.track_width*cam_x, 0, subseg, xd, yd)
	-- local x, y, z = -cx, -cy + cam_dy, -cz + cam_dz
	-- Option 2
	local cx, cy, cz = skew(0, 0, subseg, xd, yd)
	local x, y, z = -cx - road.track_width*cam_x, -cy + cam_dy, -cz + cam_dz

	-- sprites
	local sp = {}

	-- current clip region
	local clp = {0, 0, 128, 128}
	local clp_prev = {0, 0, 128, 128}
	clip()

	-- Draw road segments

	-- TODO: start 1 segment behind the player - walls and other cars have a problem with pop-in

	local x1, y1, scale1 = project(x, y, z)

	local section = road[sect]

	local ptnl = section.tnl

	-- TODO: try dynamic draw distance, i.e. stop rendering at certain CPU pct
	for i = 1, "{{ draw_distance }}" do

		local x_prev, y_prev, z_prev = x, y, z

		x += xd
		y += yd
		z += zd

		local x2, y2, scale2 = project(x, y, z)

		local sumct = section.sumct + seg

		local tnl = section.tnl
		if tnl and not ptnl then
			draw_tunnel_face(x1, y1, scale1)
			clip_to_tunnel(x1, y1, scale1, clp)
			setclip(clp)
		end

		draw_segment(section, seg, sumct, x2, y2, scale2, x1, y1, scale1, i)

		if i < "{{ sprite_draw_distance }}" then
			-- TODO: token optimizations - a lot of repeated stuff here
			if sumct == road[1].length then
				add_bg_sprite(sp, sumct, seg, bg_objects['finishline_post'], -1, x2, y2, scale2, clp)
				add_bg_sprite(sp, sumct, seg, bg_objects['finishline_post'],  1, x2, y2, scale2, clp)
				add_bg_sprite(sp, sumct, seg, bg_objects['finishline_lr'],   -1, x2, y2, scale2, clp)
				add_bg_sprite(sp, sumct, seg, bg_objects['finishline_c'],     0, x2, y2, scale2, clp)
				add_bg_sprite(sp, sumct, seg, bg_objects['finishline_lr'],    1, x2, y2, scale2, clp)
			end

			-- Iterate in reverse order of car positions, in order to prevent Z-order problems
			-- TODO: optimize this, don't need to iterate all cars every segment
			-- FIXME: there still could be z-order problems if 1 car is lapped
			for pos = #car_positions,1,-1 do
				local car = cars[car_positions[pos]]
				if car.section_idx == sect and car.segment_idx == seg then
					-- TODO: figure out why 2x is necessary - seem to be confusing width & half-width somewhere
					local car_x = x_prev + car.subseg * xd + 2*car.x
					local car_y = y_prev + car.subseg * yd
					local car_z = z_prev + car.subseg * zd
					local this_car_screen_x, this_car_screen_y, this_car_scale = project(car_x, car_y, car_z)
					add_car_sprite(sp, car, seg, this_car_screen_x, this_car_screen_y, this_car_scale, clp)
				end
			end
		end

		if i < "{{ wall_draw_distance }}" and not section.tnl then
			-- TODO: I think there's an off by 1 error here
			-- (Why do we have to use previous section's clip rectangle?)
			-- Also visible at tunnel entrance/exit
			add_wall(sp, section, seg, sumct, x2, y2, scale2, x1, y1, scale1, clp_prev, i < "{{ road_detail_draw_distance }}")
		end

		-- TODO: setting this before add_wall doesn't work - why?!
		clp_prev = {clp[1], clp[2], clp[3], clp[4]}

		-- Reduce clip region
		if tnl then
			clip_to_tunnel(x2, y2, scale2, clp)
		else
			clp[4] = min(clp[4], ceil(y2))
		end

		-- Stop drawing if the clip window size is zero
		if (clp[3] <= clp[1] or clp[4] <= clp[2]) break

		setclip(clp)

		-- Advance
		xd += section.tu
		yd -= section.dpitch
		sect, seg = advance(sect, seg)
		section = road[sect]
		x1, y1, scale1 = x2, y2, scale2
		ptnl = tnl
	end

	-- Draw sprites

	for i = #sp, 1, -1 do
		draw_bg_sprite(sp[i])
	end

	clip()

--% if enable_debug and debug_draw_extra

	if (not debug) return

	-- DEBUG: on-track stuff

	local playerx, player_subseg = player_car.x, player_car.subseg

	local xd, zd, yd = -camang, 1, -(section.pitch + section.dpitch*(segment_idx - 1))

	xd += sin(cam_angle_scale * player_car.track_angle)
	zd *= cos(cam_angle_scale * player_car.track_angle)

	local cx, cy, cz = skew(0, 0, subseg, xd, yd)
	local x, y, z = -cx - road.track_width*cam_x, -cy + cam_dy, -cz + cam_dz
	local x1, y1, scale1 = project(x, y, z)
	local x2, y2, scale2 = project(x + xd, y + yd, z + zd)

	-- On-track X Ruler
	for n = -5, 5 do
		line(x1 - n*scale1, y1, x2 - n*scale2, y2, 15)
	end

	-- Draw hitboxes/clipping info

	local car_rear_x, car_rear_y, car_rear_scale = project(
		x + player_subseg * xd + 2*playerx,
		y + player_subseg * yd,
		z + player_subseg * zd)

	local car_front_x, car_front_y, car_front_scale = project(
		x + player_subseg * xd + 2*playerx,
		y + (player_subseg + "{{ car_depth }}") * yd,
		z + (player_subseg + "{{ car_depth }}") * zd)

	local car_rear_left_x = car_rear_x - "{{ car_width }}"*car_rear_scale
	local car_rear_right_x = car_rear_x + "{{ car_width }}"*car_rear_scale
	local car_front_left_x = car_front_x - "{{ car_width }}"*car_front_scale
	local car_front_right_x = car_front_x + "{{ car_width }}"*car_front_scale

	line(car_rear_left_x, car_rear_y, car_rear_right_x, car_rear_y, 10)
	line(car_front_left_x, car_front_y, car_front_right_x, car_front_y, 10)
	line(car_rear_left_x, car_rear_y, car_front_left_x, car_front_y, 10)
	line(car_rear_right_x, car_rear_y, car_front_right_x, car_front_y, 10)

	local lx, rx, front = player_car.other_car_data.lx, player_car.other_car_data.rx, player_car.other_car_data.front
	if lx then
		line(
			x1 + 2*(lx + "{{ car_half_width }}")*scale1, y1,
			x2 + 2*(lx + "{{ car_half_width }}")*scale2, y2,
			12)
	end
	if rx then
		line(
			x1 + 2*(rx - "{{ car_half_width }}")*scale1, y1,
			x2 + 2*(rx - "{{ car_half_width }}")*scale2, y2,
			8)
	end
	if front then
		local front_x, front_y, front_scale = project(
			x + (player_subseg + front.dz_ahead) * xd + 2*playerx,
			y + (player_subseg + front.dz_ahead) * yd,
			z + player_subseg + front.dz_ahead * zd)

		line(
			front_x - front_scale*"{{ car_width }}", front_y,
			front_x + front_scale*"{{ car_width }}", front_y,
			9
		)
	end
	-- TODO: next car too
--% endif
end

function draw_bg()
	clip()

	-- TODO: use the map for this, don't redraw every frame
	-- TODO: draw some hills

	local section = road[cars[1].section_idx]
	local horizon = 64 + 32*(section.pitch + section.dpitch*(cars[1].segment_idx - 1))

	-- Sky
	rectfill(0, 0, 128, horizon - 1, 12)

	-- Horizon
	local horizon_col = 16*(road.gndcol1 or 3) + (road.gndcol2 or 11)
	fillp(0b0011110000111100)
	rectfill(0, horizon, 128, 128, horizon_col)
	fillp()

	-- Sun
	local sun_x = (cars[1].heading * 512 + 192) % 512 - 256
	if sun_x >= -64 and sun_x <= 192 then
		circfill(sun_x, horizon - 52, 8, 10)
	end

	-- Trees/Buildings
	local spr1
	if (road.tree_bg) spr1 = 112
	if (road.city_bg) spr1 = 114
	if (not spr1) return
	for off = -64,128,64 do
		local x, y = sun_x % 64 + off, horizon - 7
		spr(spr1, x, y, 2, 1)
		spr(spr1, x + 16, y, 1, 1, true)
		spr(spr1 + 1, x + 24, y, 1, 1, true)
		spr(spr1, x + 32, y)
		spr(spr1, x + 40, y, 2, 1, true)
		spr(spr1 + 1, x + 56, y)
	end
end

function draw_ranking()
	-- TODO: may only want to print 4 cars (self, leader, and cars before/after)
	cursor()
	palt(0, false)
	palt(11, true)
	for pos_num = 1,#car_positions do
		local car_idx = car_positions[pos_num]
		local car = cars[car_idx]
		local bgcol, fgcol = digit_to_hex_char(car.palette[8]), digit_to_hex_char(car.palette[14])

		-- For now, just use car index as car number
		local text = '\#0\f7' .. pos_num .. '\-h\#' .. bgcol .. '\f' .. fgcol .. car_idx .. '\-h\#0\f7'

		-- TODO: print tire status (once that's implemented)
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
			print('◀\0')
		else
			-- local x, y, colors = peek(0x5f26), peek(0x5f27), tire_compounds[car.tire_compound_idx].color
			local x, y, compound = peek(0x5f26), peek(0x5f27), tire_compounds[car.tire_compound_idx]

			-- TODO: more granular than this? (i.e. use all the colors)

			-- pal(10, colors[1])
			pal(compound.pal)
			spr(60, x, y)

			clip(0, y, 128, round(6 - 6 * car.tire_health))
			pal(10, 0)
			spr(60, x, y)
			clip()
		end
		print('\n\0')
	end
	pal()
	palt()
end

function draw_race_start_lights()
	palt(0, false)
	for i = 1,5 do
		if (i == 1 + race_start_num_lights) pal(palette_race_start_light_out)
		spr(48, 30 + 10*i, 24)
		spr(48, 30 + 10*i, 32)
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

	cursor(116, 116, 7)
	local speed_print = '' .. round(player_car.speed * "{{ speed_to_kph }}")
	if (#speed_print == 1) speed_print = ' ' .. speed_print
	if (#speed_print == 2) speed_print = ' ' .. speed_print
	print(speed_print .. '\nkph')

	cursor(108, 118)
	print(player_car.gear)

	-- Tire status

	palt(0, false)
	palt(11, true)

	pal({[10]=0,[9]=0})
	spr(46, 0, 112, 2, 2)

	-- Tire sprite is 16 tall, but colored band is 12 tall, so it starts at (y + 2) and ends at (y + 14)
	pal(tire_compounds[player_car.tire_compound_idx].pal)
	clip(0, "{{ 112 + 14 }}" - ceil(12 * player_car.tire_health), 128, 128)
	spr(46, 0, 112, 2, 2)

	clip()
	palt()
	pal()
end

function draw_cpu_only_overlay()
	cursor(100, 0, 5)
	print("cpu:" .. round(stat(1) * 100))
end
