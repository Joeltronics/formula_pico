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
tnl_prev = false

function make_note(pitch, instr, vol, effect)
	-- | C E E E | V V V W | W W P P | P P P P |
	return shl(band(effect, 7), 12) + shl(band(vol, 7), 9) + shl(band(instr, 7), 6) + band(pitch, 63) 
end

-- function get_note(sfx, time)
-- 	return peek2(0x3200 + 68*sfx + 2*time)
-- end

function set_note(sfx, time, note)
	poke2(0x3200 + 68*sfx + 2*time, note)
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

function set_flags(sfx, noiz, buzz, detune, reverb, dampen)
	local byte = 1 -- tracker mode
	byte += noiz * 2
	byte += buzz * 4
	byte += detune * 8
	byte += reverb * 24
	byte += dampen * 72
	poke(0x3200 + 68*sfx + 64, byte)
end

function update_sound()

	if (not enable_sound) return

	local player_car = cars[1]

	local touched_wall, off_track = player_car.touched_wall, abs(player_car.x) >= road.half_width

	if player_car.speed == 0 then
		-- Idling
		sfx(-1, 1)
		harmonic_prev = -1
		if (fundamental_prev ~= -2) sfx(0, 0)
		fundamental_prev = -2
		return
	end

	-- TODO: scale linearly by frequency, not pitch (need to take log - or use lookup table)
	local fundamental = flr(player_car.rpm * 36)

	-- TODO: there's probably a rare glitch here, if acceleration/off-track state changes but not fundamental
	if (fundamental == fundamental_prev and not (off_track or touched_wall)) return

	-- Slow down SFX at high speeds for less audible stepping
	local sfx_speed = sfx_speed_by_gear[1]
	if (player_car.engine_accel_brake > 0) sfx_speed = sfx_speed_by_gear[player_car.gear]
	set_speed(2, sfx_speed)
	set_speed(3, sfx_speed)

	set_note(2, 0, make_note(fundamental_prev, 2, 5, 2))
	set_note(2, 1, make_note(fundamental, 2, 5, 1))
	set_note(2, 2, make_note(fundamental, 2, 5, 2))
	sfx(2, 0)
	fundamental_prev = fundamental

	local section = road[player_car.section_idx]

	-- Add echo in tunnel
	if section.tnl ~= tnl_prev then
		local noiz, buzz, detune, reverb = 0, 0, 0, 0
		if (section.tnl) reverb = 1
		set_flags(2, noiz, buzz, detune, reverb, 1)
		set_flags(3, noiz, buzz, detune, reverb, 2)
		tnl_prev = section.tnl
	end

	if touched_wall then
		-- Touching wall
		-- TODO: different sound effect from grass
		-- TODO: make this effect last for a few ticks?
		if (harmonic_prev ~= -3) sfx(1, 1)
		harmonic_prev = -3

	elseif off_track then
		-- Off the track
		if (harmonic_prev ~= -3) sfx(1, 1)
		harmonic_prev = -3

	else
		local harmonic = fundamental + engine_harmonic_interval
		local harm_instr, harm_vol = 4, 2 -- engine braking
		if (cars[1].engine_accel_brake > 0) harm_instr, harm_vol = 1, 2 -- driving
		set_note(3, 0, make_note(harmonic_prev, harm_instr, harm_vol, 2))
		set_note(3, 1, make_note(harmonic, harm_instr, harm_vol, 1))
		set_note(3, 2, make_note(harmonic, harm_instr, harm_vol, 2))
		sfx(3, 1)
		harmonic_prev = harmonic
	end
end
