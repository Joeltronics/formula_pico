-- Sound code based on a mix of:
-- https://www.lexaloffle.com/bbs/?tid=2341
-- https://pico-8.fandom.com/wiki/Memory#Sound_effects
-- https://www.lexaloffle.com/bbs/?tid=29382

-- engine_harmonic_interval = 7  -- V6
-- engine_harmonic_interval = 12  -- V8
engine_harmonic_interval = 16  -- V10
-- engine_harmonic_interval = 19  -- V12

fundamental_prev = 0
harmonic_prev = 0

function make_note(pitch, instr, vol, effect)
	-- | C E E E | V V V W | W W P P | P P P P |
	return shl(band(effect, 7), 12) + shl(band(vol, 7), 9) + shl(band(instr, 7), 6) + band(pitch, 63) 
end

-- function get_note(sfx, time)
-- 	local addr = 0x3200 + 68*sfx + 2*time
-- 	return peek2(addr)
-- end

function set_note(sfx, time, note)
	local addr = 0x3200 + 68*sfx + 2*time
	poke2(addr, note)
end

function get_speed(sfx)
	return peek(0x3200 + 68*sfx + 65)
end

function set_speed(sfx, speed)
	poke(0x3200 + 68*sfx + 65, speed)
end

-- function get_loop_start(sfx)
-- 	return peek(0x3200 + 68*sfx + 66)
-- end

-- function get_loop_end(sfx)
-- 	return peek(0x3200 + 68*sfx + 67)
-- end

-- function set_loop(sfx, loop_start, loop_end)
-- 	local addr = 0x3200 + 68*sfx
-- 	poke(addr + 66, loop_start)
-- 	poke(addr + 67, loop_end)
-- end

function update_sound()

	if (not enable_sound) return

	if curr_speed == 0 then
		-- Idling
		sfx(-1, 1)
		harmonic_prev = -1
		if (fundamental_prev ~= -2) sfx(0, 0)
		fundamental_prev = -2
		return
	end

	-- TODO: scale linearly by frequency, not pitch (need to take log - or use lookup table)
	local fundamental = flr(rpm * 36)

	-- TODO: there's probably a rare glitch here, if acceleration/off-track state changes but not fundamental
	if (fundamental == fundamental_prev) return

	-- Slow down SFX at high speeds for less audible stepping
	-- There's still some audible stepping since effect is 2 notes and it has to hold 1st before sliding to 2nd
	-- Also, this doesn't seem to work properly anyway - it sounds different from in the editor
	local sfx_speed = sfx_speed_by_gear[1]
	if (accelerating) sfx_speed = sfx_speed_by_gear[gear]
	set_speed(2, sfx_speed)
	set_speed(3, sfx_speed)

	local note1 = make_note(fundamental_prev, 2, 5, 0)
	local note2 = make_note(fundamental, 2, 5, 1)
	set_note(2, 0, note1)
	set_note(2, 1, note2)
	sfx(2, 0)
	fundamental_prev = fundamental

	-- TODO: add echo when in tunnel

	if abs(car_x) >= road[camcnr].wall then
		-- Touching wall
		-- TODO: different sound effect from grass
		if (harmonic_prev ~= -3) sfx(1, 1)
		harmonic_prev = -3
	elseif abs(car_x) >= 1 then
		-- Off the track
		if (harmonic_prev ~= -3) sfx(1, 1)
		harmonic_prev = -3
	else
		local harmonic = fundamental + engine_harmonic_interval
		local harm_instr, harm_vol = 4, 2 -- engine braking
		if (accelerating) harm_instr, harm_vol = 1, 2 -- driving
		note1 = make_note(harmonic_prev, harm_instr, harm_vol, 0)
		note2 = make_note(harmonic, harm_instr, harm_vol, 1)
		set_note(3, 0, note1)
		set_note(3, 1, note2)
		sfx(3, 1)
		harmonic_prev = harmonic
	end
end
