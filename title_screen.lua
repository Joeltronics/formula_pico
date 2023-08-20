

row_zidx = 0
track_zidx = 0
team_zidx = 0

function init_title_screen()
end

function update_title_screen()

	if (btnp(2)) row_zidx = (row_zidx - 1) % 5
	if (btnp(3)) row_zidx = (row_zidx + 1) % 5

	if (row_zidx == 0 and btnp(4)) then
		init_game(1 + track_zidx, 1 + team_zidx)
		return
	end

	local incr = 0
	if (btnp(0) or btnp(5)) incr -= 1
	if (btnp(1) or btnp(4)) incr += 1

	if incr ~= 0 then
		if (row_zidx == 1) track_zidx = (track_zidx + incr) % #tracks
		if (row_zidx == 2) team_zidx = (team_zidx + incr) % #palettes
		if (row_zidx == 3) enable_sound = not enable_sound
		-- TODO: add separate debug option to print CPU or not
		if (row_zidx == 4) debug = not debug
	end
end

function draw_title_screen()

	cls()

	print_centered('formula', 64, 32, 8)
	print_centered('pico', 64, 32+6, 8)

	print_centered('start', 64, 64, 7)
	print_centered("track: " .. tracks[track_zidx+1].name, 64, 70, 7)
	-- TODO: print team in its color
	print_centered("team: " .. palettes[team_zidx+1].name, 64, 76, 7)
	print_centered("sound: " .. (enable_sound and "on" or "off"), 64, 82, 7)
	print_centered("debug: " .. (debug and "on" or "off"), 64, 88, 7)

	if row_zidx == 0 then
		print('🅾️', 32 - 8, 64 + row_zidx * 6)
	else
		print('◀', 32 - 8, 64 + row_zidx * 6)
		print('▶', 96 + 8, 64 + row_zidx * 6)
	end
end
