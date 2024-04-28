

row_zidx = 0
track_zidx = 0
team_zidx = 0
mode = 0

if enable_debug then
	num_rows = 6
else
	num_rows = 5
end

last_row_zidx = num_rows - 1


function init_title_screen()
	load_track(track_zidx + 1)
	init_minimap()
end

-- debug_test = 0

function update_title_screen()
	-- DEBUG
	-- debug_test = (debug_test + 1) % 256


	-- X
	if (btnp(5) and row_zidx > 0) row_zidx -= 1

	-- O
	if btnp(4) then
		if row_zidx == last_row_zidx then
			return init_game(
				1 + track_zidx,
				1 + team_zidx,
				mode >= 1, -- is_race
				false, -- ghost (TODO)
				mode >= 1 and 7 or 0, -- num_other_cars
				(mode == 2) -- ai_only
			)
		end
		row_zidx += 1
	end

	-- Up/Down
	if (btnp(2)) row_zidx -= 1
	if (btnp(3)) row_zidx += 1
	row_zidx %= num_rows

	-- Left/Right
	local incr = 0
	if (btnp(0)) incr -= 1
	if (btnp(1)) incr += 1

	if (incr == 0) return

	if (row_zidx == 0) mode += incr
	mode %= 3
	if row_zidx == 1 then
		track_zidx += incr
		track_zidx %= #tracks
		road = tracks[track_zidx + 1]
		load_track(track_zidx + 1)
		init_minimap()
	end
	if (row_zidx == 2) team_zidx += incr
	team_zidx %= #palettes

	if (row_zidx == 3) brake_assist = not brake_assist

	if enable_debug then
		-- TODO: add separate debug option to print CPU or not
		if (row_zidx == 4) debug = not debug
	end
end

function draw_title_screen()

	cls()

	local xoff = 240 - 64
	local yoff = 64

	-- fillp(0b0011001111001100)
	fillp(
		0b11110000,
		0b11110000,
		0b11110000,
		0b11110000,
		0b00001111,
		0b00001111,
		0b00001111,
		0b00001111)
	rectfill(0, 56, 43 + xoff, 71, 7)
	rectfill(84 + xoff, 56, 480, 71, 7)
	fillp()

	print_centered('Formula', 240, 57, 8)
	print_centered('Pico', 240, 65, 8)

	local mode_str = ''
	if (mode == 0) mode_str = 'Practice'
	-- if (mode == 1) mode_str = 'Time Trial'
	if (mode == 1) mode_str = 'Race'
	if (mode == 2) mode_str = 'AI only'

	print_centered("Mode: " .. mode_str, 240, 64 + yoff, 7)
	print_centered("Track: " .. tracks[track_zidx+1].name, 240, 72 + yoff, 7)
	-- TODO: print team in its color
	print_centered("Team: " .. palettes[team_zidx+1].name, 240, 80 + yoff, 7)
	print_centered("Brake assist: " .. (brake_assist and "On" or "Off"), 240, 88 + yoff, 7)

	if enable_debug then
		print_centered("Debug: " .. (debug and "On" or "Off"), 240, 96 + yoff, 7)
		print_centered('Start', 240, 112 + yoff, 7)
	else
		print_centered('Start', 240, 104 + yoff, 7)
	end

	if row_zidx == last_row_zidx then
		print('\142', xoff, 65 + yoff + 8 * (1 + row_zidx))
	else
		print('\139', xoff, 65 + yoff + 8 * row_zidx)
		print('\145', 128 + xoff, 65 + yoff + 8 * row_zidx)
	end

	local x = 90
	local y = 135
	for dx = -16, 54 do
		line(
			x + dx,      y + 32 + 8,
			x + dx + 12, y - 4,
			5)
	end

	pal(palettes[team_zidx + 1])
	palt(0, false)
	palt(11, true)
	-- spr(sprites.car[#sprites.car].bmp, x, y)
	spr(sprites.car[2].bmp, x, y)
	palt()
	pal()

	if minimap then
		draw_minimap(128 + 40 + xoff, 150)
	end
end
