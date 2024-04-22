

row_zidx = 0
track_zidx = 0
team_zidx = 0
mode = 0

--% if enable_debug
--% set num_rows = 6
--% else
--% set num_rows = 5
--% endif

--% set last_row_zidx = num_rows - 1


function init_title_screen()
end

function update_title_screen()

	-- X
	if (btnp(5) and row_zidx > 0) row_zidx -= 1

	-- O
	if btnp(4) then
		if row_zidx == "{{ last_row_zidx }}" then
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
	row_zidx %= "{{ num_rows }}"

	-- Left/Right
	local incr = 0
	if (btnp(0)) incr -= 1
	if (btnp(1)) incr += 1

	if (incr == 0) return

	if (row_zidx == 0) mode += incr
	mode %= 3
	if (row_zidx == 1) track_zidx += incr
	track_zidx %= #tracks
	if (row_zidx == 2) team_zidx += incr
	team_zidx %= #palettes

	if (row_zidx == 3) brake_assist = not brake_assist
--% if enable_debug
	-- TODO: add separate debug option to print CPU or not
	if (row_zidx == 4) debug = not debug
--% endif
end

function draw_title_screen()

	cls()

	fillp(0b0011001111001100)
	rectfill(0, 24, 47, 35, 7)
	rectfill(80, 24, 128, 35, 7)
	fillp()

	print_centered('formula', 64, 25, 8)
	print_centered('pico', 64, 31, 8)

	local mode_str = ''
	if (mode == 0) mode_str = 'practice'
	-- if (mode == 1) mode_str = 'time trial'
	if (mode == 1) mode_str = 'race'
	if (mode == 2) mode_str = 'ai only'

	print_centered("mode: " .. mode_str, 64, 64, 7)
	print_centered("track: " .. tracks[track_zidx+1].name, 64, 70, 7)
	-- TODO: print team in its color
	print_centered("team: " .. palettes[team_zidx+1].name, 64, 76, 7)
	print_centered("brake assist: " .. (brake_assist and "on" or "off"), 64, 82, 7)
--% if enable_debug
	print_centered("debug: " .. (debug and "on" or "off"), 64, 88, 7)
	print_centered('start', 64, 100, 7)
--% else
	print_centered('start', 64, 94, 7)
--% endif

	if row_zidx == "{{ last_row_zidx }}" then
		print('🅾️', 32 - 8, 64 + (1 + row_zidx) * 6)
	else
		print('◀', 32 - 8, 64 + row_zidx * 6)
		print('▶', 96 + 8, 64 + row_zidx * 6)
	end
end
