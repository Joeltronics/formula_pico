-- Sound code based on a mix of:
-- https://www.lexaloffle.com/bbs/?tid=2341
-- https://pico-8.fandom.com/wiki/Memory#Sound_effects
-- https://www.lexaloffle.com/bbs/?tid=29382

-- engine_harmonic_interval = 7  -- V6
-- engine_harmonic_interval = 12  -- V8
engine_harmonic_interval = 16  -- V10
-- engine_harmonic_interval = 19  -- V12

fundamental_prev = 0

function make_note(pitch, instr, vol, effect)
	-- | C E E E | V V V W | W W P P | P P P P |
	return shl(band(effect, 7), 12) + shl(band(vol, 7), 9) + shl(band(instr, 7), 6) + band(pitch, 63) 
end

function get_note(sfx, time)
	local addr = 0x3200 + 68*sfx + 2*time
	return peek2(addr)
end

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

function get_loop_start(sfx)
	return peek(0x3200 + 68*sfx + 66)
end

function get_loop_end(sfx)
	return peek(0x3200 + 68*sfx + 67)
end

function set_loop(sfx, loop_start, loop_end)
	local addr = 0x3200 + 68*sfx
	poke(addr + 66, loop_start)
	poke(addr + 67, loop_end)
end

function init_sound()
	-- TODO: can set these in sfx data, don't need to init this way
	-- TODO: also may want to set buzz/filter?
	for n = 60,61 do
		set_speed(n, 2)
		set_loop(n, 1, 2)
	end
end

function update_sound()

	if (not enable_sound) return

	if curr_speed == 0 then
		-- Idling
		sfx(0, 0)
		sfx(-1, 1)
		fundamental_prev = 0
		return
	end

	if abs(car_x) >= 1 then
		-- TODO: special sound effect on grass
	end

	-- TODO: scale linearly by frequency, not pitch (need to take log - or use lookup table)
	local fundamental = flr((gear % 1) * 36) + flr(gear) - 1
	local harmonic = fundamental + engine_harmonic_interval
	local harmonic_prev = fundamental_prev + engine_harmonic_interval

	-- TODO: there's still some audible stepping at high RPMs, due to limited pitch resolution. Could come up with a
	-- hack of changing the sfx speed for this (and then not retriggering every update)
	local note1 = make_note(fundamental_prev, 2, 5, 0)
	local note2 = make_note(fundamental, 2, 5, 1)
	set_note(60, 0, note1)
	set_note(60, 1, note2)
	sfx(60, 0)

	local harm_instr = 1
	if (accelerating) harm_instr = 4
	note1 = make_note(harmonic_prev, harm_instr, 1, 0)
	note2 = make_note(harmonic, harm_instr, 1, 1)
	set_note(61, 0, note1)
	set_note(61, 1, note2)
	sfx(61, 1)

	fundamental_prev = fundamental
end
