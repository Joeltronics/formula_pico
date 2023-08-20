

row_zero_idx = 0
track_zero_idx = 0

function init_title_screen()
end

function update_title_screen()

	if (btnp(2)) row_zero_idx = (row_zero_idx - 1) % 4
	if (btnp(3)) row_zero_idx = (row_zero_idx + 1) % 4

	if (row_zero_idx == 0 and btnp(4)) then
		init_game(1 + track_zero_idx)
		return
	end

	local incr = 0
	if (btnp(0) or btnp(5)) incr -= 1
	if (btnp(1) or btnp(4)) incr += 1

	if incr ~= 0 then
		if (row_zero_idx == 1) track_zero_idx = (track_zero_idx + incr) % #tracks

		if (row_zero_idx == 2) enable_sound = not enable_sound

		-- TODO: add separate debug option to print CPU or not
		if (row_zero_idx == 3) debug = not debug
	end
end

function draw_title_screen()

	cls()

	print_centered('formula', 64, 32, 8)
	print_centered('pico', 64, 32+6, 8)

	print_centered('start', 64, 64, 7)
	print_centered("track: " .. tracks[track_zero_idx+1].name, 64, 70, 7)
	print_centered("sound: " .. (enable_sound and "on" or "off"), 64, 76, 7)
	print_centered("debug: " .. (debug and "on" or "off"), 64, 82, 7)

	if row_zero_idx == 0 then
		print('🅾️', 32 - 8, 64 + row_zero_idx * 6)
	else
		print('◀', 32 - 8, 64 + row_zero_idx * 6)
		print('▶', 96 + 8, 64 + row_zero_idx * 6)	
	end
end
