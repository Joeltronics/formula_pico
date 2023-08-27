
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

function draw_ground(y1, y2, sumct, gndcol)
	if not gndcol then
		gndcol = 3
		if ((sumct % 6) >= 3) gndcol = 11
	end
	rectfill(0, y1, 128, y2, gndcol)
end

function draw_segment(section, seg, sumct, x1, y1, scale1, x2, y2, scale2, gndcol, distance)

	detail = (distance <= road_detail_draw_distance)

	y1, yt = ceil(y1), flr(y2)

	if section.tnl then
		draw_tunnel_walls(x1, y1, scale1, x2, y2, scale2, sumct)
	elseif (y2 >= y1) then
		draw_ground(y1, y2, sumct, gndcol)
		-- TODO: draw walls
	end

	if (y2 < y1 or distance > road_draw_distance) return

	-- Road

	local w1, w2 = road_width*scale1, road_width*scale2

	filltrapz(x1, y1, w1, x2, y2, w2, 5)

	-- Start/finish line

	if (not detail) fillp(0b0101101001011010)

	if sumct == road[1].length then
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

	-- Racing line

	if (not draw_racing_line) return

	local col = 11

	if seg < section.apex_seg then
		-- Before apex
		if (curr_speed > section.max_speed_pre_apex) col = 8
		if (curr_speed == section.max_speed_pre_apex and section.max_speed_pre_apex < 0.99) col = 10
		line(
			x1 + w1*(section.entrance_x + seg*section.racing_line_dx_pre_apex), y1,
			x2 + w2*(section.entrance_x + (seg - 1)*section.racing_line_dx_pre_apex), y2,
			col)
	else
		-- After apex
		if (curr_speed > section.max_speed_post_apex) col = 8
		if (curr_speed == section.max_speed_post_apex and section.max_speed_post_apex < 0.99) col = 10
		local past_apex = seg - section.apex_seg
		line(
			x1 + w1*(section.apex_x + (1 + past_apex)*section.racing_line_dx_post_apex), y1,
			x2 + w2*(section.apex_x + past_apex*section.racing_line_dx_post_apex), y2,
			col)
	end
end

function get_tunnel_rect(x, y, scale)
	local w, h = (2*road_width + 0.4)*scale, 4*scale
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
	local wh = 4.5*scale
	local wy = ceil(y - wh)

	-- faces
	if(y1 > 0) rectfill(0, wy, 128, y1-1, 7)
	if(x1 > 0) rectfill(0, y1, x1-1, y2-1, 7)
	if(x2 < 128) rectfill(x2, y1, 127, y2-1, 7)
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

function add_bg_sprite(
	sprite_list, sumct, seg, bg, side, px, py, scale, clp)

	if (not bg) return

	if bg.spacing == 0 then
		if (seg ~= 1) return
	elseif (sumct % bg.spacing) ~= 0 then
		return
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
		palt=bg.palt,
		flip_x=(side > 0 and bg.flip_r),
		clp={clp[1],clp[2],clp[3],clp[4]}
	})
end

function draw_bg_sprite(s)

	setclip(s.clp)

	if s.palt then
		palt(0, false)
		palt(s.palt, true)
	end

	local x1=ceil(s.x-s.w/2)
	local x2=ceil(s.x+s.w/2)
	local y1=ceil(s.y-s.h)
	local y2=ceil(s.y)

	sspr(
		s.img[1], s.img[2], s.img[3], s.img[4], -- sx, sy, sw, wh
		x1, y1, x2-x1, y2-y1, -- dx, dy, dw, dh
		s.flip_x  -- flip_x
	)

	palt()
end

function draw_road()

	-- road position
	local sect, seg = curr_section_idx, curr_segment_idx
	local section = road[curr_section_idx]

	-- direction
	-- TODO: look ahead a bit more than this to determine camera
	local camang = curr_subseg * section.tu
	local xd = -camang
	local yd = -(section.pitch + section.dpitch*(curr_segment_idx - 1))
	local zd = 1

	-- Starting coords

	-- TODO: figure out which is the better way to do this
	-- Option 1
	-- local cx, cy, cz = skew(road_width*cam_x, 0, curr_subseg, xd, yd)
	-- local x, y, z = -cx, -cy + cam_dy, -cz + cam_dz
	-- Option 2
	local cx, cy, cz = skew(0, 0, curr_subseg, xd, yd)
	local x, y, z = -cx - road_width*cam_x, -cy + cam_dy, -cz + cam_dz

	-- Car draw coords
	local car_screen_x, car_screen_y, car_scale = project(car_x, cam_dy, cam_dz)

	-- sprites
	local sp = {}

	-- current clip region
	local clp = {0, 0, 128, 128}
	clip()

	-- Draw road segments

	local x1, y1, scale1 = project(x, y, z)

	local section = road[sect]

	local ptnl = section.tnl

	for i = 1, draw_distance do

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

		draw_segment(section, seg, sumct, x2, y2, scale2, x1, y1, scale1, section.gndcol, i)

		if i < sprite_draw_distance then

			if sumct == road[1].length then
				add_bg_sprite(sp, sumct, seg, bg_finishline, -1, x2, y2, scale2, clp)
				add_bg_sprite(sp, sumct, seg, bg_finishline,  1, x2, y2, scale2, clp)
			end

			add_bg_sprite(sp, sumct, seg, section.bgl, -1, x2, y2, scale2, clp)
			add_bg_sprite(sp, sumct, seg, section.bgc,  0, x2, y2, scale2, clp)
			add_bg_sprite(sp, sumct, seg, section.bgr,  1, x2, y2, scale2, clp)
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
		sect, seg, _ = advance(sect, seg)
		section = road[sect]
		x1, y1, scale1 = x2, y2, scale2
		ptnl = tnl
	end

	-- Draw sprites

	for i = #sp, 1, -1 do
		draw_bg_sprite(sp[i])
	end

	clip()

	return car_screen_x, car_screen_y, car_scale
end

function draw_bg()
	clip()

	-- TODO: use the map for this, don't redraw every frame
	-- TODO: draw some hills

	local section = road[curr_section_idx]
	local horizon = 64 + 32*(section.pitch + section.dpitch*(curr_segment_idx - 1))

	-- Sky
	rectfill(0, 0, 128, horizon - 1, 12)

	-- Horizon
	fillp(0b0011110000111100)
	rectfill(0, horizon, 128, 128, 0xB3)
	fillp()

	-- Sun
	local sun_x = (heading * 512 + 192) % 512 - 256
	if sun_x >= -64 and sun_x <= 192 then
		circfill(sun_x, horizon - 52, 8, 10)
	end

	-- Trees
	local tree_y = horizon - 7
	for off = -64,128,64 do
		local tree_x = sun_x % 64 + off
		spr(112, tree_x, tree_y, 2, 1)
		spr(112, tree_x + 16, tree_y, 1, 1, true)
		spr(113, tree_x + 24, tree_y, 1, 1, true)
		spr(112, tree_x + 32, tree_y)
		spr(112, tree_x + 40, tree_y, 2, 1, true)
		spr(113, tree_x + 56, tree_y)
	end
end

function draw_hud()
	cursor(116, 116, 7)
	local speed_print = '' .. round(curr_speed * speed_to_kph)
	if (#speed_print == 1) speed_print = ' ' .. speed_print
	if (#speed_print == 2) speed_print = ' ' .. speed_print
	print(speed_print .. '\nkph')

	cursor(108, 118)
	print(gear)
end

function init_car_palettes(team_idx)
	car_palette = palettes[team_idx]
	car_palette = {
		[8]=car_palette[1],  -- main
		[14]=car_palette[2],  -- accent 1
		[2]=car_palette[3],  -- dark
		[13]=car_palette[4],  -- floor
	}
end

function draw_car(x, y, scale)
	if (car_palette) pal(car_palette, 0)
	palt(0, false)
	palt(11, true)

	-- TODO: extra sprites for braking or on grass

	if curr_speed > 0 then
		if abs(car_x) >= road[curr_section_idx].wall then
			-- Touching wall
			-- TODO: add smoke, or other indicator of scraping
		end

		if abs(car_x) >= 1 then
			-- On grass; bumpy
			y -= flr(rnd(2))
			-- TODO: add "flinging grass" sprite
		end
	end

	-- DEBUG
	local use_scale = false
	-- local use_scale = (scale ~= 32)

	if use_scale then
		camera()
		local size = scale * 24 / 32
		sspr(0, 0, 24, 24, x - size/2, y - size, size, size)
	else
		-- Car sprite is 24x24, x & y define bottom center
		camera(-x + 12, -y + 24)
		if car_sprite_turn < -1 then
			-- TODO: sprite for this
			spr(3, 1, 0, 3, 3)
		elseif car_sprite_turn < 0 then
			spr(3, 1, 0, 3, 3)
		elseif car_sprite_turn > 1 then
			-- TODO: sprite for this
			spr(6, -1, 0, 3, 3)
		elseif car_sprite_turn > 0 then
			spr(6, -1, 0, 3, 3)
		else
			spr(0, 0, 0, 3, 3)
		end
		camera()
	end

	pal()
	palt()
end

function draw_cpu_only_overlay()
	cursor(100, 0, 7)
	local cpu = round(stat(1) * 100)
	print("cpu:" .. cpu)
end

function draw_debug_overlay()
	local section = road[curr_section_idx]
	local cpu = round(stat(1) * 100)
	local mem = round(stat(0) * 100 / 2048)

	cursor(88, 0, 7)
	print("cpu:" .. cpu)
	print("mem:" .. mem)
	print(curr_section_idx .. "," .. curr_segment_idx .. ',' .. curr_subseg)
	print('carx:' .. car_x)

	if cam_dy ~= 2 or cam_dz ~= 2 then
		print('cam:' .. cam_x .. ',' .. cam_dy .. ',' .. cam_dz)
	else
		print('cam:' .. cam_x)
	end

	-- local pitch = (section.pitch + section.dpitch*(curr_segment_idx - 1))
	-- print('pi:' .. pitch)
end
