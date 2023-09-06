
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

function filltrapz(cx1, y1, w1, cx2, y2, w2, col)
	-- draw a trapezoid by stacking horizontal lines

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
		rectfill(x - w, y, x + w, y, col)
		x += xd
		w += wd
		y += 1
	end
end

function draw_ground(y1, y2, sumct, gndcol1, gndcol2)
	local gndcol = gndcol1
	if ((sumct % 6) >= 3) gndcol = gndcol2
	rectfill(0, y1, 128, y2, gndcol)
end

function draw_segment(section, seg, sumct, x1, y1, scale1, x2, y2, scale2, distance)

	detail = (distance <= road_detail_draw_distance)

	y1, yt = ceil(y1), flr(y2)

	if section.tnl then
		draw_tunnel_walls(x1, y1, scale1, x2, y2, scale2, sumct)
	elseif (y2 >= y1) then
		draw_ground(y1, y2, sumct,
			section.gndcol1 or road.gndcol1 or 3,
			section.gndcol2 or road.gndcol2 or 11)
		-- TODO: draw walls
	end

	if (y2 < y1 or distance > road_draw_distance) return

	-- Road

	local w1, w2 = road.track_width*scale1, road.track_width*scale2

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

	-- Shoulders

	if detail then
		local linecol = 7
		if (sumct % 2 == 0) linecol = 8
		local sw1, sw2 = shoulder_width*scale1, shoulder_width*scale2
		filltrapz(x1-w1, y1, sw1, x2-w2, y2, sw2, linecol)
		filltrapz(x1+w1, y1, sw1, x2+w2, y2, sw2, linecol)
	else
		line(x1-w1, y1, x2-w2, y2, 0x6e)
		line(x1+w1, y1, x2+w2, y2, 0x6e)
		fillp()
	end

	-- Center line

	if road.street and (sumct % 4) == 0 then
		if detail then
			local cw1, cw2 = center_line_width*scale1, center_line_width*scale2
			filltrapz(x1, y1, cw1, x2, y2, cw2, 7)
		else
			line(x1, ceil(y1), x2, y2, 6)
		end
	end

	-- Racing line

	if (not draw_racing_line) return

	local col = 11
	local speed = cars[1].speed

	if seg < section.apex_seg then
		-- Before apex
		if (speed > section.max_speed_pre_apex) col = 8
		if (speed == section.max_speed_pre_apex and section.max_speed_pre_apex < 0.99) col = 10
		line(
			x1 + w1*(section.entrance_x + seg*section.racing_line_dx_pre_apex), y1,
			x2 + w2*(section.entrance_x + (seg - 1)*section.racing_line_dx_pre_apex), y2,
			col)
	else
		-- After apex
		if (speed > section.max_speed_post_apex) col = 8
		if (speed == section.max_speed_post_apex and section.max_speed_post_apex < 0.99) col = 10
		local past_apex = seg - section.apex_seg
		line(
			x1 + w1*(section.apex_x + (1 + past_apex)*section.racing_line_dx_post_apex), y1,
			x2 + w2*(section.apex_x + past_apex*section.racing_line_dx_post_apex), y2,
			col)
	end
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
		flip_x=(bg.flip or side > 0 and bg.flip_r),
		clp={clp[1],clp[2],clp[3],clp[4]}
	})
end

function add_car_sprite(sprite_list, car, seg, x, y, scale, clp)

	-- TODO: may want to offset drawing location by 1 pixel in some cases?
	-- TODO: use track x value to add extra turn? (i.e. cars ahead after a corner)

	local car_abs_x = abs(car.x)

	if car.speed > 0 then
		if car_abs_x >= road[car.section_idx].wall then
			-- Touching wall
			-- TODO: add smoke, or other indicator of scraping
		end

		if car_abs_x >= road.half_width then
			-- On grass; bumpy
			y -= flr(rnd(2))
			-- TODO: add "flinging grass" sprite
		end
	end

	local sprite_turn = car.sprite_turn

	local d_center = x - 64
	if (abs(d_center) > 16) sprite_turn -= sgn(d_center)
	if (abs(d_center) > 48) sprite_turn -= sgn(d_center)

	add_bg_sprite(
		sprite_list, sumct, seg,
		{
			img={
				24 * min(4, ceil(abs(sprite_turn))),
				0, 24, 16},
			siz={car_width, car_height},
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

	local x1=ceil(s.x-s.w/2)
	local x2=ceil(s.x+s.w/2)
	local y1=ceil(s.y-s.h)
	local y2=ceil(s.y)

	sspr(
		s.img[1], s.img[2], s.img[3], s.img[4], -- sx, sy, sw, wh
		x1, y1, x2-x1, y2-y1, -- dx, dy, dw, dh
		s.flip_x  -- flip_x
	)

	if (s.palette) pal()
	if (s.palt) palt()
	-- pal()
	-- palt()
end

function draw_road()

	-- road position
	local section_idx = cars[1].section_idx
	local segment_idx = cars[1].segment_idx
	local subseg = cars[1].subseg
	local sect, seg = section_idx, segment_idx
	local section = road[section_idx]

	-- direction
	-- TODO: look ahead a bit more than this to determine camera
	local camang = subseg * section.tu
	local xd = -camang
	local yd = -(section.pitch + section.dpitch*(segment_idx - 1))
	local zd = 1

	-- Starting coords

	-- TODO: if off track, move camera even further to make sure car is in frame
	cam_x = cam_x_scale * cars[1].x * (2 / road.track_width)

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
	clip()

	-- Draw road segments

	-- TODO: start 1 segment behind the player - other sprites have a problem with pop-in

	local x1, y1, scale1 = project(x, y, z)

	local section = road[sect]

	local ptnl = section.tnl

	for i = 1, draw_distance do

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

		-- DEBUG
		-- if (debug and i == 1) then
		-- 	for n = -5, 5 do
		-- 		line(x1 - n*scale1, y1, x2 - n*scale2, y2, 10)
		-- 	end
		-- end

		if i < sprite_draw_distance then
			if sumct == road[1].length then
				add_bg_sprite(sp, sumct, seg, bg_objects['finishline'], -1, x2, y2, scale2, clp)
				add_bg_sprite(sp, sumct, seg, bg_objects['finishline'],  1, x2, y2, scale2, clp)
			end

			add_bg_sprite(sp, sumct, seg, section.bgl, -1, x2, y2, scale2, clp)
			add_bg_sprite(sp, sumct, seg, section.bgc,  0, x2, y2, scale2, clp)
			add_bg_sprite(sp, sumct, seg, section.bgr,  1, x2, y2, scale2, clp)

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

		-- Reduce clip region
		if tnl then
			clip_to_tunnel(x2, y2, scale2, clp)
		else
			clp[4] = min(clp[4], ceil(y2))
		end
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
	local spr1 = nil
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
		if (car_idx == 1) print('◀\0')
		print('\n\0')
	end
end

function draw_hud()

	if #cars > 1 then
		draw_ranking()
	end

	cursor(116, 116, 7)
	local speed_print = '' .. round(cars[1].speed * speed_to_kph)
	if (#speed_print == 1) speed_print = ' ' .. speed_print
	if (#speed_print == 2) speed_print = ' ' .. speed_print
	print(speed_print .. '\nkph')

	cursor(108, 118)
	print(cars[1].gear)
end

function draw_cpu_only_overlay()
	cursor(100, 0, 5)
	print("cpu:" .. round(stat(1) * 100))
end

function draw_debug_overlay()

	-- local section = road[cars[1].section_idx]

	cursor(88, 0, 5)
	print("cpu:" .. round(stat(1) * 100))
	print("mem:" .. round(stat(0) * 100 / 2048))
	print(cars[1].section_idx .. "," .. cars[1].segment_idx .. ',' .. cars[1].subseg)
	print('carx:' .. cars[1].x)
	-- print('hw:' .. road.half_width)
	-- print('wall:' .. section.wall)

	print('st:' .. cars[1].sprite_turn)

	if cam_dy ~= 2 or cam_dz ~= 2 then
		print('cam:' .. cam_x .. ',' .. cam_dy .. ',' .. cam_dz)
	else
		print('cam:' .. cam_x)
	end

	-- local pitch = (section.pitch + section.dpitch*(segment_idx - 1))
	-- print('pi:' .. pitch)
end
