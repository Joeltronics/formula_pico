
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
	10 yellow
	11 green
	12 blue
	13 indigo
	14 pink
	15 peach
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

function draw_segment(corner, seg, sumct, x1, y1, scale1, x2, y2, scale2, gndcol, distance)

	detail = distance <= road_detail_draw_distance

	y1, yt = ceil(y1), flr(y2)

	if (y2 < y1) return

	local w1 = road_width*scale1
	local w2 = road_width*scale2

	-- Ground

	if not gndcol then
		gndcol = 3
		if ((sumct % 6) >= 3) gndcol = 11
	end
	rectfill(0, y1, 128, y2, gndcol)

	if (distance > road_draw_distance) return

	-- Road

	filltrapz(x1, y1, w1, x2, y2, w2, 5)

	-- Start/finish line

	if (not detail) fillp(0b0101101001011010)

	if sumct == road.finish_seg then
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

	if center_line_width > 0 and (sumct % 4) == 0 then
		if detail then
			local cw1, cw2 = center_line_width*scale1, center_line_width*scale2
			filltrapz(x1, y1, cw1, x2, y2, cw2, 7)
		else
			line(x1, ceil(y1), x2, y2, 6)
		end
	end

	-- Racing line

	if (not draw_racing_line) return

	-- TODO: color red in braking zone
	local col = 11

	if (not corner.apex_seg) or (seg < corner.apex_seg) then
		-- Before apex (or no apex)
		-- TODO: optimize out duplicate w1 multiplication (also below)
		line(
			-- x1 + corner.entrance_x*w1, y1,
			-- x2 + corner.entrance_x*w2, y2,
			x1 + corner.entrance_x*w1 + (1 + seg)*corner.racing_line_dx_pre_apex*w1, y1,
			x2 + corner.entrance_x*w2 + seg*corner.racing_line_dx_pre_apex*w2, y2,
			col)
	else
		-- After apex
		local past_apex = seg - corner.apex_seg
		line(
			x1 + corner.apex_x*w1 + (1 + past_apex)*corner.racing_line_dx_post_apex*w1, y1,
			x2 + corner.apex_x*w2 + past_apex*corner.racing_line_dx_post_apex*w2, y2,
			col)
	end
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
	local cnr, seg = camcnr, camseg
	local corner = road[camcnr]

	-- local nextcnr, nextseg = advance(cnr, seg)
	-- local nextcorner = road[nextcnr]

	-- direction
	-- TODO: look ahead a bit more than this to determine camera
	local camang = cam_z * corner.tu
	local xd = -camang
	local yd = -(corner.pitch + corner.dpitch*(camseg - 1))
	local zd = 1

	-- Starting coords

	-- TODO: figure out which is the better way to do this
	-- Option 1
	-- local cx, cy, cz = skew(road_width*cam_x, 0, cam_z, xd, yd)
	-- local x, y, z = -cx, -cy + cam_dy, -cz + cam_dz
	-- Option 2
	local cx, cy, cz = skew(0, 0, cam_z, xd, yd)
	local x, y, z = -cx - road_width*cam_x, -cy + cam_dy, -cz + cam_dz

	-- Car draw coords
	local car_screen_x, car_screen_y, car_scale = project(car_x, cam_dy, cam_dz)

	-- sprites
	local sp = {}

	-- current clip region
	-- TODO: only last value is ever used, can just store that one
	local clp={0, 0, 128, 128}
	clip()

	-- Draw road segments

	local x1, y1, scale1 = project(x, y, z)

	for i = 1, draw_distance do

		x += xd
		y += yd
		z += zd

		local x2, y2, scale2 = project(x, y, z)

		local sumct = road[cnr].sumct + seg

		draw_segment(road[cnr], seg, sumct, x2, y2, scale2, x1, y1, scale1, road[cnr].gndcol, i)

		if i < sprite_draw_distance then

			if sumct == road.finish_seg then
				add_bg_sprite(sp, sumct, seg, bg_finishline, -1, x2, y2, scale2, clp)
				add_bg_sprite(sp, sumct, seg, bg_finishline,  1, x2, y2, scale2, clp)
			end

			add_bg_sprite(sp, sumct, seg, road[cnr].bgl, -1, x2, y2, scale2, clp)
			add_bg_sprite(sp, sumct, seg, road[cnr].bgc,  0, x2, y2, scale2, clp)
			add_bg_sprite(sp, sumct, seg, road[cnr].bgr,  1, x2, y2, scale2, clp)
		end

		-- Reduce clip region
		clp[4] = min(clp[4], ceil(y2))
		setclip(clp)

		-- Advance
		xd += road[cnr].tu
		yd -= road[cnr].dpitch
		cnr, seg, _ = advance(cnr, seg)
		x1, y1, scale1 = x2, y2, scale2
	end

	-- Draw sprites

	for i = #sp, 1, -1 do
		draw_bg_sprite(sp[i])
	end

	clip()

	return car_screen_x, car_screen_y, car_scale
end

function draw_sunset_sky()

	-- rectfill(0, 0, 127, 64, 1) -- dark blue

	--[[

	0xC blue
	0xD indigo
	0x1 dark blue
	0x0 black

	64 pixels / 4 = 16 segments, so each color could fade in 4 segments

	]]

	local fade0 = 0b1000000000100000
	local fade1 = 0b1000001010000010
	local fade2 = 0b1010010110100101
	local fade3 = 0b0111110101111101
	local fade4 = 0b1011111111101111

	fillp()
	rectfill(0, 0, 127, 3, 0xC)
	fillp(fade0)
	rectfill(0, 4, 127, 7, 0xDC)
	fillp(fade2)
	rectfill(0, 8, 127, 11, 0xDC)
	fillp(fade4)
	rectfill(0, 12, 127, 15, 0xDC)

	fillp()
	rectfill(0, 16, 127, 19, 0xD)
	fillp(fade0)
	rectfill(0, 20, 127, 23, 0x1D)
	fillp(fade2)
	rectfill(0, 24, 127, 27, 0x1D)
	fillp(fade4)
	rectfill(0, 28, 127, 31, 0x1D)
	fillp()

	rectfill(0, 32, 127, 43, 0x1)

	fillp(fade0)
	rectfill(0, 44, 127, 47, 0x01)
	fillp(fade1)
	rectfill(0, 48, 127, 51, 0x01)
	fillp(fade2)
	rectfill(0, 52, 127, 55, 0x01)
	fillp(fade3)
	rectfill(0, 56, 127, 59, 0x01)
	fillp(fade4)
	rectfill(0, 60, 127, 63, 0x01)

	fillp()
end

function draw_sunset()

	if sun_x < -64 or sun_x > 192 then
		return
	end

	-- Circle: Y 48, R 32
	-- Top: 16
	-- Center: 48
	-- Visible bottom: 64
	-- Actual bottom: 80
	
	-- yellow = 10 = 0xA
	-- orange = 9 = 0x9
	-- peach = 15 = 0xF
	-- pink = 14 = 0xE

	-- yellow
	clip(0, 0, 128, 46)
	circfill(sun_x, 48, 32, 0xA)

	-- orange to yellow
	fillp(0b1010000110110101)
	clip(0, 46, 128, 4)
	circfill(sun_x, 48, 32, 0xA9)

	-- orange
	fillp()
	clip(0, 50, 128, 2)
	circfill(sun_x, 48, 32, 0xA9)

	-- orange -> peach
	fillp(0b1011010110100001)
	clip(0, 52, 128, 4)
	circfill(sun_x, 48, 32, 0x9F)

	-- peach
	fillp()
	clip(0, 56, 128, 2)
	circfill(sun_x, 48, 32, 0x9F)

	-- peach -> pink
	fillp(0b1010000110110101)
	clip(0, 58, 128, 4)
	circfill(sun_x, 48, 32, 0xFE)

	-- pink
	fillp()
	clip(0, 62, 128, 2)
	circfill(sun_x, 48, 32, 0xE)

	clip()

	-- for y in all({35, 40, 44, 48, 51, 54, 56, 58, 60, 62}) do
	-- 	line(0, y, 128, y, 1)
	-- end
end

function draw_day_sun()
	if sun_x >= -64 and sun_x <= 192 then
		circfill(sun_x, 12, 8, 10)
	end
end

function draw_bg()

	clip()

	-- cls() -- slow, not needed

	-- TODO: use the map for this, don't redraw every frame

	-- Daytime
	-- rectfill(0, 0, 127, 64, 12) -- light blue
	rectfill(0, 0, 128, 128, 12) -- light blue
	draw_day_sun()

	-- Nighttime
	-- draw_sunset_sky()
	-- draw_sunset()

	-- Grass
	-- rectfill(0, 64, 127, 127, 3) -- dark green (light green is super ugly)
	-- rectfill(0, 64, 127, 127, 0) -- black
end

function draw_hud()
	-- cursor(112, 110, 7)
	cursor(116, 116, 7)

	local speed_print = '' .. round(curr_speed * speed_to_kph)
	if (#speed_print == 1) speed_print = ' ' .. speed_print
	if (#speed_print == 2) speed_print = ' ' .. speed_print
	print(speed_print .. '\nkph')

	-- cursor(104, 112)
	cursor(108, 118)
	print(flr(gear))
end

function draw_car(x, y, scale)
	palt(0, false)
	palt(11, true)

	-- TODO: extra sprites for braking or on grass

	if abs(car_x) >= 1 and curr_speed > 0 then
		-- On grass; bumpy
		y -= flr(rnd(2))
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

	palt()
end

function draw_debug_overlay()
	-- cursor(0, 0, 7)
	-- cursor(0, 128-16, 7)
	cursor(88, 0, 7)
	local cpu = round(stat(1) * 100)
	print("cpu:" .. cpu)
	print(camcnr .. "," .. camseg .. ',' .. cam_z)

	local corner = road[camcnr]

	print('carx:' .. car_x)
	-- print("camx:" .. cam_x)
	-- print('tu:' .. corner.tu)
	-- print('a:' .. angle)
	-- print('p:' .. corner.pitch)
	-- print('dp:' .. corner.dpitch)

	if cam_dy ~= 2 or cam_dz ~= 2 then
		print('cam:' .. cam_x .. ',' .. cam_dy .. ',' .. cam_dz)
	else
		print('cam:' .. cam_x)
	end

	-- cursor(92, 0)
	-- print("ca:" .. camang)
	-- print("cx:" .. cx)
	-- print("cy:" .. cy)
	-- print("cz:" .. cz)
end
