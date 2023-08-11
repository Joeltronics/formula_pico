pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- Formula Pico
-- by Joel Geddert
-- License: CC BY-NC-SA 4.0

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

-->8
-- Data

bg_tree3={
	img={0, 32, 8, 16},  -- sprite image
	pos={1.5, 0},  -- position rel to side of road
	siz={1.5, 3},  -- size
	spacing=3  -- spacing
}
bg_tree4={
	img={0, 32, 8, 16},  -- sprite image
	pos={1.5, 0},  -- position rel to side of road
	siz={1.5, 3},  -- size
	spacing=4  -- spacing
}
bg_tree5={
	img={0, 32, 8, 16},  -- sprite image
	pos={1.5, 0},  -- position rel to side of road
	siz={1.5, 3},  -- size
	spacing=5  -- spacing
}
bg_tree7={
	img={0, 32, 8, 16},  -- sprite image
	pos={1.5, 0},  -- position rel to side of road
	siz={1.5, 3},  -- size
	spacing=7  -- spacing
}

bg_sign={
	img={16, 32, 8, 16},
	pos={1, 0},
	siz={1, 2},
	spacing=1,
	flip_r=true  -- flip when on right hand side
}

-- TODO: use bgc
bg_finishline = {
	img={96, 32, 32, 32},
	-- pos={1.5, 0},
	pos={0, 0},
	-- siz={10, 5},
	siz={6.8, 5},
	-- spacing=0,
	spacing=1,
	palt=11,
	flip_r=true
}
-- bg_finishline_c = {
-- 	img={96, 32, 32, 8},
-- 	pos={0, -48},
-- 	siz={10, 1},
-- 	spacing=0,
-- 	palt=11,
-- }


-- TODO: max speed per segment (including info how to ramp up & down)
-- TODO: define height and calculate pitch, like how "tu" is calculated from angle
-- TOOD: define racing line
tracks = {
{
	name="test",
	minimap_scale = 0.5,
	minimap_x = 24, -- distance from right side of screen
	minimap_y = 0, -- distance from vertical center
	finish_seg = 5,
	{length=20,
	-- , bgl=bg_finishline, bgr=bg_finishline
	-- ,  bgc=bg_finishline_c
	},
	{length=12, angle=-0.25, bgr=bg_sign},
	{length=12, pitch=-.75, bgl=bg_tree3},
	{length=8, angle=0.125, bgl=bg_sign},
	{length=20, angle=0.125, pitch=.75},
	{length=8, pitch=-.5},
	{length=10, angle=0.25},
	{length=8},
	{length=62, angle=0.25, bgl=bg_tree3, bgr=bg_tree5},

	{length=6, angle=0.25, bgl=bg_sign},
	{length=8, angle=-0.25, bgr=bg_sign},

	{length=40, bgl=bg_tree4, bgr=bg_tree5},

	{length=6, angle=0.5, bgl=bg_sign},

	{length=8},

	{length=8, angle=-0.125},
	{length=8, angle=0.125},
},
{
	name="italy",
	minimap_scale = 0.25,
	minimap_x = 24,
	minimap_y = 0,
	finish_seg = 5,
	{length=40},
	{length=6, angle=0.25}, -- 1: chicane
	{length=8, angle=-0.375}, -- 2
	{length=8, angle=0.125},
	{length=8},
	{length=64, angle=0.2}, -- 3: curva grande
	{length=12},
	{length=6, angle=-0.25}, -- 4: chicane
	{length=6, angle=0.25}, -- 5
	{length=12},
	{length=12, angle=0.25}, -- 6: lesmo
	{length=12},
	{length=12, angle=0.2}, -- 7
	{length=12},
	{length=12, angle=-0.05}, -- serraglio
	{length=40},
	{length=8, angle=-0.15}, -- 8 :ascari
	{length=8, angle=0.2}, -- 9
	{length=8, angle=-0.15}, -- 10
	{length=72},
	{length=10, angle=0.25}, -- 11: parabolica
	{length=10, angle=0.125},
	{length=30, angle=0.125},
	{length=12},
},
{
	name="belgium",
	minimap_scale = 0.25,
	minimap_x = 12,
	minimap_y = 16,
	finish_seg = 5,
	{length=28}, -- heading 0.25
	{length=8, angle=0.375}, -- 1: la source; heading 0.625
	{length=16, pitch=-0.5},
	{length=16, angle=0.075}, -- 2; heading 0.7
	{length=16, pitch=-0.25},
	{length=4, angle=-0.15}, -- , gndcol=12}, -- 3: eau rouge; heading 0.55
	{length=16, angle=0.3, pitch=2}, -- 4: raidillon; heading 0.85
	{length=16, angle=-0.15}, -- 5; heading 0.7
	{length=16, pitch=1, bgl=bg_tree7},
	{length=16, angle=0.05, pitch=0.5, bgl=bg_tree4, bgr=bg_tree7}, -- 6; heading 0.75
	{length=48, bgl=bg_tree3, pitch=0.5, bgr=bg_tree4}, -- kemmel straight
	{length=8, angle=0.25}, -- 7; high point
	{length=4},
	{length=8, angle=-0.25}, -- 8
	{length=8, pitch=-0.25},
	{length=8, angle=0.25, pitch=-0.25}, -- 9
	{length=32, pitch=-0.75},
	{length=24, angle=0.5, pitch=-0.25}, -- 10
	{length=8, pitch=-0.5},
	{length=8, angle=-0.25, pitch=-0.5}, -- 11
	{length=40, pitch=-0.75},
	{length=12, angle=-0.2, pitch=-0.5}, -- 12: pouhon
	{length=18, angle=-0.175, pitch=-0.5},
	{length=24, pitch=-0.75},
	{length=16, angle=0.25, pitch=-0.25}, -- 13
	{length=4},
	{length=16, angle=-0.25}, -- 14
	{length=8},
	{length=12, angle=0.25}, -- 15
	{length=8, pitch=-0.25},
	{length=6, angle=0.125}, -- 16; low point
	{length=18, angle=0.125, pitch=0.5},
	{length=12, pitch=0.25},
	{length=20, angle=0.125, pitch=0.25},
	{length=28, pitch=0.25},
	{length=6, angle=-0.125, pitch=0.25}, -- 17
	{length=24, pitch=0.25},
	{length=6, angle=-0.125, pitch=0.25}, -- 18
	{length=24, pitch=1},

	{length=6, angle=0.25}, -- 19: chicane
	{length=6, angle=-0.25}, -- 20
	{length=14},
},
{
	name="hill test",
	minimap_scale = 0.5,
	minimap_x = 12,
	minimap_y = -20,
	finish_seg = 5,
	{length=20},
	{length=20, pitch=1, gndcol=8},
	{length=20},
	{length=12, angle=0.5},
	{length=20},
	{length=20, pitch=-1, gndcol=1},
	{length=20},
	{length=12, angle=0.5},
}
}

-- TODO: select this at start screen
-- road = tracks[1]
-- road = tracks[2]
road = tracks[3]
-- road = tracks[4]

speed_scale = 1
-- speed_scale = 0.25
-- speed_scale = 0.125
-- speed_scale = 0.0625

length_scale = 1
-- length_scale = 2

-- Acceleration by speed, in 4 quadrants of speed 0.25
accel = {8/1024, 6/1024, 3/1024, 1/1024}

speed_to_kph = 350

-- cam_height = 1
cam_height = 2
-- cam_height = 5

road_width = 3
-- road_width = 4
center_line_width = 3/32
-- center_line_width = 0
shoulder_width = 1/8

start_angle = 0.25

--
-- runtime vars
--

camcnr, camseg, camtotseg = 1, 1, 1
car_x, subseg_z = 0, 0
angle = start_angle
sun_x = 64
curr_speed = 0

--
-- stuff at init
--

minimap = {}
sumct = 0

function _init()
	cls()

	local x, y, dx, dy, curr_angle = 0, 0, 0, -1, start_angle

	for corner in all(road) do
		corner.length *= length_scale
		-- Pitch is defined backwards - TODO: negate this where it's used instead
		corner.pitch = -(corner.pitch or 0)
		corner.angle = corner.angle or 0
	end

	local minimap_scale = road.minimap_scale / length_scale
	-- local minimap_scale = road.minimap_scale

	local tu_angle_scale = 16 * length_scale

	for corner_idx = 1, #road do
		local corner = road[corner_idx]
		local next_corner = road[corner_idx % #road + 1]

		corner.angle_per_seg= corner.angle / corner.length
		corner.tu = tu_angle_scale * corner.angle_per_seg

		corner.dpitch = (next_corner.pitch - corner.pitch) / corner.length

		corner.sumct = sumct
		sumct += corner.length

		for n = 1, corner.length do

			curr_angle -= corner.angle_per_seg
			curr_angle %= 1.0

			dx = minimap_scale * cos(curr_angle)
			dy = minimap_scale * sin(curr_angle)

			x += dx
			y += dy

			add(minimap, {x, y})
		end
	end
end

-->8
-- Utility & math functions

function round(val)
	return flr(val + 0.5)
end

function project(x, y, z)
	local scale = 64 / z
	return x * scale + 64, y * scale + 64, scale
end

function skew(x, y, z, xd, yd)
	return x + z*xd, y + z*yd, z
end

function camx()
	return car_x / 4
end

function advance(cnr, seg)
	seg += 1
	if seg > road[cnr].length then
		seg = 1
		cnr += 1
		if (cnr > #road) cnr = 1
	end
	return cnr, seg
end

function reverse(cnr, seg)
	seg -= 1
	if seg == 0 then
		cnr -= 1
		if (cnr == 0) cnr = #road
		seg = road[cnr].length
	end

	return cnr, seg
end

-->8
-- Game logic

step_handled = false
reverse_handled = false

function _update60()

	-- Left & Right

	-- TODO: don't turn left/right while stopped

	if btn(0) then
		car_x -= 0.5
	end

	if btn(1) then
		car_x += 0.5
	end

	-- debug: down to reverse

	if btn(3) then
		if not reverse_handled then
			camcnr, camseg = reverse(camcnr, camseg)
			camtotseg -= 1
			if (camtotseg == 0) camtotseg = sumct
			reverse_handled = true
		end
	else
		reverse_handled = false
	end

	-- Only advance while holding up

	if (not btn(2)) then
		curr_speed = 0
		return
	end

	-- Or, only 1 step at a time
	-- if btn(2) then
	-- 	if (step_handled) return
	-- 	step_handled = true
	-- else
	-- 	step_handled = false
	-- 	return
	-- end

	forward()
end

function forward()
	-- max speed
	-- TODO: look ahead for braking point, slow down
	-- TODO: slow down on curb & grass

	local tu = road[camcnr].tu
	local max_speed = min(1.25 - tu, 1)
	max_speed *= max_speed

	-- accelerate
	-- TODO: also factor in slope

	local a = accel[flr(min(curr_speed, 0.99) * 4) + 1]

	curr_speed = min(curr_speed + a, max_speed)

	-- TODO: sound from speed

	-- update position

	-- TODO: adjust relative to tu and x position, i.e. inside of corner is faster, outside is slower
	local dz = 0.5 * speed_scale * curr_speed

	subseg_z += dz
	if subseg_z > 1 then
		subseg_z -= 1
		camcnr, camseg = advance(camcnr, camseg)
		camtotseg += 1
		if (camcnr == 1 and camseg == 1) camtotseg = 1
	end

	-- angle & sun coordinate

	-- TODO: should this be before updating?
	angle -= road[camcnr].angle_per_seg * dz
	angle %= 1.0
	-- This has slight error due to fixed-point precision
	-- TODO: Calculate properly instead of this hack
	if (camcnr == 1 and camseg == 1) angle = start_angle

	sun_x = (angle * 512 + 192) % 512 - 256
end

-->8
-- Drawing Road

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

function draw_segment(sumct, x1, y1, scale1, x2, y2, scale2, gndcol)

	if (flr(y2) < ceil(y1)) return

	local w1 = road_width*scale1
	local w2 = road_width*scale2

	-- Ground

	if not gndcol then
		gndcol = 3
		if ((sumct % 6) >= 3) gndcol = 11
	end
	rectfill(0, y1, 128, y2, gndcol)

	-- Road

	filltrapz(x1, y1, w1, x2, y2, w2, 5)

	-- Start/finish line

	if sumct == road.finish_seg then
		fillp(0b0011001111001100)
		filltrapz(x1, y1, w1, x2, y2, w2, 0x07)
		fillp()
	end

	-- Center line

	if center_line_width > 0 and (sumct % 4) == 0 then
		local cw1, cw2 = center_line_width*scale1, center_line_width*scale2
		filltrapz(x1, y1, cw1, x2, y2, cw2, 7)
	end

	-- Shoulders

	local linecol = 7
	if (sumct % 2 == 0) linecol = 8

	local sw1, sw2 = shoulder_width*scale1, shoulder_width*scale2
	filltrapz(x1-w1, y1, sw1, x2-w2, y2, sw2, linecol)
	filltrapz(x1+w1, y1, sw1, x2+w2, y2, sw2, linecol)

	-- TODO: racing line
end

function setclip(clp)
	clip(clp[1], clp[2], clp[3]-clp[1], clp[4]-clp[2])
end

function add_bg_sprite(sp, sumct, seg, bg, side, px, py, scale, clp)

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

	add(sp, {
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

		x1, y1, x2-x1, y2-y1,

		-- s.x - s.w/2,  -- dx
		-- s.y - s.h,  -- dy
		-- s.w,  -- dw
		-- s.h,  -- dh
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
	local camang = subseg_z * corner.tu
	-- local camang = subseg_z * corner.tu + subseg_z*road[nextcnr].tu -- DEBUG
	local xd = -camang
	local yd = corner.pitch + corner.dpitch*(camseg - 1)
	local zd = 1

	-- Starting coords

	local cx, cy, cz = skew(camx(), 0, subseg_z, xd, yd)
	local x, y, z = -cx, -cy + cam_height, -cz + cam_height

	local sp = {}

	-- current clip region
	local clp={0, 0, 128, 128}
	clip()

	-- Draw road segments

	local x1, y1, scale1 = project(x, y, z)

	-- for i = 1, 30 do
	for i = 1, 60 do

		local x2, y2, scale2 = project(x, y, z)

		local sumct = road[cnr].sumct + seg

		x += xd
		y += yd
		z += zd

		draw_segment(sumct, x2, y2, scale2, x1, y1, scale1, road[cnr].gndcol)

		if sumct == road.finish_seg then
			add_bg_sprite(sp, sumct, seg, bg_finishline, -1, x2, y2, scale2, clp)
			add_bg_sprite(sp, sumct, seg, bg_finishline,  1, x2, y2, scale2, clp)
		end

		add_bg_sprite(sp, sumct, seg, road[cnr].bgl, -1, x2, y2, scale2, clp)
		add_bg_sprite(sp, sumct, seg, road[cnr].bgc,  0, x2, y2, scale2, clp)
		add_bg_sprite(sp, sumct, seg, road[cnr].bgr,  1, x2, y2, scale2, clp)

		-- reduce clip region
		clp[4] = min(clp[4], ceil(y2))
		setclip(clp)

		-- Advance
		xd += road[cnr].tu
		yd += road[cnr].dpitch
		-- yd += road[cnr].pitch -- DEBUG
		cnr, seg = advance(cnr, seg)
		x1, y1, scale1 = x2, y2, scale2
	end

	-- Draw sprites

	for i = #sp, 1, -1 do
		draw_bg_sprite(sp[i])
	end

	clip()
end

-->8
-- Drawing (Other)

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

function draw_minimap()
	camera(-128 + road.minimap_x, -64 + road.minimap_y)

	-- map
	line(0, 0, 0, 0, 7)
	for seg in all(minimap) do
		line(seg[1], seg[2])
	end

	-- finish line
	-- TODO: it's actually at road.finish_seg
	line(0, 0, 0, 0, 0)

	-- current position
	local pos = minimap[camtotseg]
	line(pos[1], pos[2], pos[1], pos[2], 8)

	camera()
end

function draw_hud()
	cursor(112, 112, 7)
	local print_speed = round(curr_speed * speed_to_kph)
	print(print_speed)
	print('kph')
end

function draw_car()
	palt(0, false)
	palt(11, true)

	local carx_display = car_x - camx()

	-- center 64
	-- car sprite 24 pix wide, half is 12
	camera(-64 + 12 - road_width*carx_display, -128 + 24 + 2)

	local tu = road[camcnr].tu
	local left = btn(0)
	local right = btn(1)

	-- TODO: optimize this - have left/right add an amount to tu (below)
	-- want logic to be a bit smarter than that though
	if (tu < -0.49 and right) or (tu > 0.49 and left) then
		spr(0, 0, 0, 3, 3)
	elseif (left or tu < 0) and not right then
		spr(3, 1, 0, 3, 3)
	elseif (right or tu > 0) and not left then
		spr(6, -1, 0, 3, 3)
	else
		spr(0, 0, 0, 3, 3)
	end

	-- if (btn(0)) tu -= 0.75
	-- if (btn(1)) tu += 0.75

	-- if tu < -0.05 then
	-- 	spr(3, 1, 0, 3, 3)
	-- elseif tu > 0.05 then
	-- 	spr(6, -1, 0, 3, 3)
	-- else
	-- 	spr(0, 0, 0, 3, 3)
	-- end

	camera()
	palt()
end

function draw_debug_overlay()
	-- cursor(0, 0, 7)
	-- cursor(0, 128-16, 7)
	cursor(92, 0, 7)
	local cpu = round(stat(1) * 100)
	print("cpu:" .. cpu)
	print("pos:" .. camcnr .. "," .. camseg)

	local corner = road[camcnr]

	print('car_x:' .. car_x)
	print('sub_z:' .. subseg_z)
	print('tu:' .. corner.tu)
	print('a:' .. angle)
	print('p:' .. corner.pitch)
	print('dp:' .. corner.dpitch)

	-- cursor(48, 0)
	-- print("camx:" .. camx)
	-- print("camy:" .. camy)
	-- print("subseg_z:" .. subseg_z)

	-- cursor(92, 0)
	-- print("ca:" .. camang)
	-- print("cx:" .. cx)
	-- print("cy:" .. cy)
	-- print("cz:" .. cz)
end

function _draw()
	draw_bg()
	draw_road()
	draw_car()
	draw_minimap()
	draw_hud()
	draw_debug_overlay()
end

__gfx__
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000
bbbbbbbbbb8888bbbbbbbbbbbbbbbbbb8888bbbbbbbbbbbbbbbbbbbbbbbb8888bbbbbbbbbbbbbbbb8888bbbbbbbbbbbb00000000000000000000000000000000
bbb000bbb888888bbb000bbbb000bbb888888bbb000bbbbbbbbbb000bbb888888bbb000bb000bbb888888bbb000bbbbb00000000000000000000000000000000
bb065588888ee888886550bb0655888888e888886550bbbbbbbb055688888e88888855600655888888e888886550bbbb00000000000000000000000000000000
bb000088888ee888880000bb6000888888ee88880000bbbbbbbb00008888ee88888800060000888888ee88880000bbbb00000000000000000000000000000000
bb000e88888ee88888e000bb60008e88888e888800e0bbbbbbbb0e008888e88888e8000600008888888e88880000bbbb00000000000000000000000000000000
bb000e555555555555e000bb0000ee555555555555e0bbbbbbbb0e555555555555ee000000002800000000000000bbbb00000000000000000000000000000000
bbb00e000000000000e00bbbb000ee000000000000ebbbbbbbbbbe000000000000ee000bb000b20000000000000bbbbb00000000000000000000000000000000
bbbbbe088000000880ebbbbbbbbbbe0880000008b0ebbbbbbbbbbe0b8000000880ebbbbbbbbbbb0880000008b0bbbbbb00000000000000000000000000000000
bbbbbb088880088880bbbbbbbbbbbb088880088880bbbbbbbbbbbb088880088880bbbbbbbbbbbb088880088880bbbbbb00000000000000000000000000000000
bbbbbb088880088880bbbbbbbbbbbb088880088880bbbbbbbbbbbb088880088880bbbbbbbbbbbb088880088880bbbbbb00000000000000000000000000000000
bbbbbb088885588880bbbbbbbbbbbb088885588880bbbbbbbbbbbb088885588880bbbbbbbbbbbb088885588880bbbbbb00000000000000000000000000000000
b0000088888668888800000bb0000088888668888800000bb0000088888668888800000bb0000088888668888800000b00000000000000000000000000000000
00665588882662888866550000665588882662888866550000665588882662888866550000665588882662888866550000000000000000000000000000000000
06655588826006288865555006655588826006288865555006655588826006288865555006655588826006288865555000000000000000000000000000000000
00000088226006228800000060000088226006228800000000000088226006228800000600000088226006228800000000000000000000000000000000000000
00000022222662222200000060000022222662222200000000000022222662222200000600000022222662222200000000000000000000000000000000000000
00000022222222222200000000000022222222222200000000000022222222222200000000000022222222222200000000000000000000000000000000000000
000000bbbbbbbbbbbb000000000000bbbbbbbbbbbb000000000000bbbbbbbbbbbb000000000000bbbbbbbbbbbb00000000000000000000000000000000000000
b00000bbbbbbbbbbbb00000bb00000bbbbbbbbbbbb00000bb00000bbbbbbbbbbbb00000bb00000bbbbbbbbbbbb00000b00000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000
0003000000000000444444440000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00007777000077770000777700007777
0003000000000000455599940000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00007777000077770000777700007777
0033000000000000495559940000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00007777000077770000777700007777
0033300000000000499555940000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00007777000077770000777700007777
0033300000000000499955540000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb77770000777700007777000077770000
033b300000000000499555940000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb77770000777700007777000077770000
03bb300000000000495559940000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb77770000777700007777000077770000
03bb330000000000455599940000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb66660000666600006666000066660000
03bbbb3000000000444444440000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82bbbb28bbbbbbbbbbbbbbbbbbbbbbbb
33bbb33300000000000660000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb882bb288bbbbbbbbbbbbbbbbbbbbbbbb
33bbb33500000000000660000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82822828bbbbbbbbbbbbbbbbbbbbbbbb
533b335500000000000660000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb8b2882b8bbbbbbbbbbbbbbbbbbbbbbbb
0533335000000000000660000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb8b2882b8bbbbbbbbbbbbbbbbbbbbbbbb
0055550000000000000660000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82822828bbbbbbbbbbbbbbbbbbbbbbbb
0004400000000000000660000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb882bb288bbbbbbbbbbbbbbbbbbbbbbbb
0004400000000000000660000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82bbbb28bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82bbbb28bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb882bb288bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82822828bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb8b2882b8bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb8b2882b8bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82822828bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb882bb288bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82bbbb28bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82bbbb28bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb882bb288bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82822828bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb8b2882b8bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb8b2882b8bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82822828bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb882bb288bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82bbbb28bbbbbbbbbbbbbbbbbbbbbbbb
