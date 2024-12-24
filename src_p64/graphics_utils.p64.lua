
function is_on_screen(x, y, extra_margin)
	extra_margin = extra_margin or 0
	return (x >= -extra_margin and x <= 480 + extra_margin and y >= -extra_margin and y <= 270 + extra_margin)
end

function get_ground_colors(section, sumct)

	local gndcol1 = section.gndcol1 or road.gndcol1 or 3
	local gndcol2 = section.gndcol2 or road.gndcol2 or 11

	local gndcol, gndcol_l, gndcol_r = gndcol1, section.gndcol1l, section.gndcol1r
	if (sumct % 6) >= 3 then
		gndcol, gndcol_l, gndcol_r = gndcol2, section.gndcol2l, section.gndcol2r
	end

	return gndcol, gndcol_l, gndcol_r
end

function get_racing_line_color(section, segment_idx, car)

	local speed = car.speed
	local max_speed = section.max_speed

	local col = 11
	if (max_speed < 0.999 and speed > max_speed - 0.01) col = 10
	if (need_to_brake(section, segment_idx, 0, speed, car.grip)) col = 2
	if (max_speed < 0.999 and speed > max_speed + 0.01) col = 8

	return col
end

-- p01_triangle_163 by @p01
-- https://www.lexaloffle.com/bbs/?tid=31478
-- License CC4-BY-NC-SA
function trifill(x0,y0,x1,y1,x2,y2,col)
	color(col)
	if(y1<y0)x0,x1,y0,y1=x1,x0,y1,y0
	if(y2<y0)x0,x2,y0,y2=x2,x0,y2,y0
	if(y2<y1)x1,x2,y1,y2=x2,x1,y2,y1
	col=x0+(x2-x0)/(y2-y0)*(y1-y0)
	p01_trapeze_h(x0,x0,x1,col,y0,y1)
	p01_trapeze_h(x1,col,x2,x2,y1,y2)
end
function p01_trapeze_h(l,r,lt,rt,y0,y1)
	lt,rt=(lt-l)/(y1-y0),(rt-r)/(y1-y0)
	if(y0<0)l,r,y0=l-y0*lt,r-y0*rt,0
	y1=min(y1,270)
	for y0=y0,y1 do
	 rectfill(l,y0,r,y0)
	 l+=lt
	 r+=rt
	end
end

-- Note that arguments are in "triangle strip" order (i.e. Z shaped)
function quadfill(x0,y0,x1,y1,x2,y2,x3,y3,col)
	trifill(x0, y0, x1, y1, x2, y2, col)
	trifill(x1, y1, x2, y2, x3, y3, col)
	-- Extra line to cover gap that appears
	-- TODO: make a proper quadfill that makes this not necessary
	-- line(x1, y1, x2, y2, col)
end


FILLP_GRADIENT_TABLE = {
	[0]=0x0000, -- 0
	0b0000000001000000, -- 1
	0b0000000100000100, -- 2
	0b0000000100000100, -- 3 (2)
	0b0000010100001010, -- 4
	0b0000010100001010, -- 5 (4)
	0b0000010100001010, -- 6 (4)
	0b0101101001011010, -- 7 (8)
	0b0101101001011010, -- 8
	0b0101101001011010, -- 9 (8)
	~0b0000101000000101, -- 10 (12)
	~0b0000101000000101, -- 11 (12)
	~0b0000101000000101, -- 12
	~0b0000000100000100, -- 13 (14)
	~0b0000000100000100, -- 14
	~0b0000000001000000, -- 15
	0xFFFF, -- 16
}


function fillp_gradient(level)

	level = clip_num(round(level * 16), 0, 16)

	-- TODO: use unpack for this

	-- fillp(FILLP_GRADIENT_TABLE[level])

	if level == 1 then
		fillp(
			0b00000000,
			0b01000100,
			0b00000000,
			0b00000000,
			0b00000000,
			0b00010001,
			0b00000000,
			0b00000000
		)
	elseif level == 15 then
		fillp(
			0b11111111,
			0b11111111,
			0b11111111,
			0b11101110,
			0b11111111,
			0b11111111,
			0b11111111,
			0b10111011
		)
	else
		fillp(FILLP_GRADIENT_TABLE[level])
	end

	
end
