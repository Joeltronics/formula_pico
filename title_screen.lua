

row_zidx = 0
track_zidx = 0
team_zidx = 0

function init_title_screen()
end

function update_title_screen()

	-- X
	if btnp(5) then
		if (row_zidx > 0) row_zidx -= 1
	end

	-- O
	if btnp(4) then
		if (row_zidx == 4) then
			init_game(1 + track_zidx, 1 + team_zidx)
			return
		else
			row_zidx += 1
		end
	end

	-- Up/Down
	if (btnp(2)) row_zidx = (row_zidx - 1) % 5
	if (btnp(3)) row_zidx = (row_zidx + 1) % 5

	-- Left/Right
	local incr = 0
	if (btnp(0)) incr -= 1
	if (btnp(1)) incr += 1

	if incr ~= 0 then
		if (row_zidx == 0) track_zidx = (track_zidx + incr) % #tracks
		if (row_zidx == 1) team_zidx = (team_zidx + incr) % #palettes
		if (row_zidx == 2) enable_sound = not enable_sound
		-- TODO: add separate debug option to print CPU or not
		if (row_zidx == 3) debug = not debug
	end
end

function draw_title_screen()

	cls()

	fillp(0b0011001111001100)
	rectfill(0, 24, 47, 35, 7)
	rectfill(80, 24, 128, 35, 7)
	fillp()

	print_centered('formula', 64, 25, 8)
	print_centered('pico', 64, 31, 8)

	print_centered("track: " .. tracks[track_zidx+1].name, 64, 64, 7)
	-- TODO: print team in its color
	print_centered("team: " .. palettes[team_zidx+1].name, 64, 70, 7)
	print_centered("sound: " .. (enable_sound and "on" or "off"), 64, 76, 7)
	print_centered("debug: " .. (debug and "on" or "off"), 64, 82, 7)

	print_centered('start', 64, 94, 7)

	if row_zidx == 4 then
		print('🅾️', 32 - 8, 64 + (1 + row_zidx) * 6)
	else
		print('◀', 32 - 8, 64 + row_zidx * 6)
		print('▶', 96 + 8, 64 + row_zidx * 6)
	end
end
