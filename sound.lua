-- Sound code based on a mix of:
-- https://www.lexaloffle.com/bbs/?tid=2341
-- https://pico-8.fandom.com/wiki/Memory#Sound_effects
-- https://www.lexaloffle.com/bbs/?tid=29382

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

function update_sound()

	if (not enable_sound) return

	if curr_speed == 0 then
		-- TODO: special idling sound effect
	end

	if abs(car_x) >= 1 then
		-- TODO: special sound effect on grass
	end

	-- TODO: scale linearly by frequency, not pitch (need to take log - or use lookup table)
	local fundamental = flr((gear % 1) * 36) + flr(gear) - 1

	-- local harmonic = fundamental + 7 -- V6
	-- local harmonic = fundamental + 12 -- V8
	local harmonic = fundamental + 16 -- V10
	-- local harmonic = fundamental + 19 -- V12

	play_sound(0, 2, fundamental, 5)

	if curr_speed == 0 then
		sfx(-1, 1)
	elseif accelerating then
		play_sound(1, 4, harmonic, 1)
	else
		play_sound(1, 1, harmonic, 1)
	end
end

function play_sound(ch, waveform, pitch, vol, n)

	n = n or 63 - ch
	vol = vol or 5

	-- TODO: get pitch slide (effect #1) working
	local effect = 0

	note = make_note(pitch, waveform, vol or 5, effect)
	set_note(n, 0, note)
	set_speed(n, 1)
	set_loop(n, 0, 1)
	sfx(n, ch)
end
