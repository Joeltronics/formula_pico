
function init_game(track_idx, team_idx, is_race, ghost, num_other_cars, ai_only)
	road = tracks[track_idx]
	if (debug) poke(0x5F2D, 1)  -- enable keyboard
	poke(0x5f36, 0x40)  -- prevent printing at bottom of screen from triggering scroll
	init_cars(team_idx, ghost, num_other_cars, ai_only)
	init_track()
	init_minimap()

	race_started = not is_race
	race_start_counter = 0
	race_start_num_lights = 0
end

function init_cars(team_idx, ghost, num_other_cars, ai_only)

	collisions = not ghost
	cars = {}

	local teams = {1, 2, 3, 4, 5, 6, 7, 8}

	for zidx = 0, num_other_cars do
		local palette = palettes[team_idx]
		palette = {
			[8]=palette[1],  -- main
			[14]=palette[2],  -- accent 1
			[12]=palette[3],  -- wing top
			[1]=palette[4],  -- wing back
			[2]=palette[5],  -- dark
			[13]=palette[6],  -- floor
		}

		local ai = (zidx ~= 0) or ai_only

		local segment_idx = 1 + zidx
		local is_ghost = ghost and zidx == 1
		if is_ghost then
			-- Ghost car
			palette = palette_ghost
			segment_idx = 1
		end
		-- Start reaction time: 0.15 - 0.5 seconds (9-30 frames)
		local start_delay_counter = 0
		if (ai and not is_ghost) start_delay_counter = 9 + flr(rnd(21))
		add(cars, {
			x=0,
			laps=-1,
			section_idx=1,
			segment_idx=segment_idx,
			segment_total=segment_idx,
			subseg=0,
			segment_plus_subseg=segment_idx,
			speed=0,
			gear=1,
			rpm=0,
			palette=palette,
			ai=ai,
			ghost=is_ghost,
			engine_accel_brake=0,
			steer_accum=0,
			heading=start_heading,
			sprite_turn=0,
			finished=false,
			in_pit=false,
			touched_wall=false,
			touched_wall_sound=false,
			start_delay_counter=start_delay_counter,
		})

		del(teams, team_idx)
		team_idx = rnd(teams)
	end

	car_positions = {}
	for idx = (1+num_other_cars),1,-1 do
		add(car_positions, idx)
	end
end

function sort2(list, idx1, idx2)
	local item1 = list[idx1]
	local item2 = list[idx2]
	if (item1[2] < item2[2]) then
		list[idx1] = item2
		list[idx2] = item1
	end
end

function update_car_positions(full)

	local car_scores = {}
	for idx in all(car_positions) do
		local car = cars[idx]
		-- Laps count from end of 1st section, so add 1 extra lap to compensate
		local effective_laps = car.laps
		if (car.section_idx == 1) effective_laps += 1
		local score = (1 + total_segment_count)*effective_laps + car.segment_total + car.subseg
		add(car_scores, {idx, score})
	end

	-- Bubblesort
	-- In practice, 1 single loop should be good enough in most cases - cars start sorted, and even in rare case of
	-- double overtake in 1 frame, position will only be updated 1 frame late

	local num_loops = 1
	if (full) num_loops = #cars

	for loop_idx = 1,num_loops do
		for idx = 1,#cars-1 do
			sort2(car_scores, idx, idx+1)
		end
	end

	car_positions = {}
	for item in all(car_scores) do
		add(car_positions, item[1])
	end
end

function tick_debug()
	local player_car = cars[1]
	while stat(30) do
		local key = stat(31)
		-- printh('"' .. key .. '"')
		if race_started then
			if (key == 'k') player_car.subseg += 0.25
			if (key == 'j') player_car.subseg -= 0.25
			if (key == '⌂') player_car.subseg += 1
			if (key == '웃') player_car.subseg -= 1
			if (key == ':') player_car.subseg = 0
			if (key == 'h') player_car.x -= 0.25
			if (key == 'l') player_car.x += 0.25
			if (key == '♥') player_car.x -= 1
			if (key == '⬅️') player_car.x += 1
			if (key == '`') player_car.speed = min(player_car.speed + 0.25, 2) -- turbo
			if (key == '~') then
				-- turbo for all cars
				for car in all(cars) do
					car.speed = min(car.speed + 0.25, 2)
				end
			end
		else
			if (key == '`' or key == '~') race_start_counter += 15
		end

		if (key == '7') cam_x_scale = max(cam_x_scale - 0.25, 0)
		if (key == '8') cam_x_scale = min(cam_x_scale + 0.25, 1)
		if (key == '9') cam_dy = max(cam_dy - 0.25, 0.25)
		if (key == '0') cam_dy += 0.25
		if (key == '-') cam_dz = max(cam_dz - 0.25, 0.25)
		if (key == '=') cam_dz += 0.25
		if (key == '<') player_car.heading -= 1/256
		if (key == '>') player_car.heading += 1/256
		if (key == 'f') frozen = not frozen
	end

	player_car.segment_plus_subseg = player_car.segment_idx + player_car.subseg
end

function update_sprite_turn(car, section, dx)
	-- Base car direction to draw
	-- (Extra may be added at draw time to account for position on screen)

	-- TODO: these don't all have to be integers, can add fractional amount

	-- Did we move left/right?
	local car_sprite_turn = sgn0(dx)
 
	-- Is accumulator saturated?
	if (abs(car.steer_accum) >= 1) car_sprite_turn += sgn(car.steer_accum)

	-- Is road turning?
	if (abs(section.tu) > 0.1) car_sprite_turn += sgn(car_sprite_turn)
	-- TODO: 2nd level, if turning sharply

	car.sprite_turn = car_sprite_turn
end

function clip_wall(car, section)

	local car_x, wall_clip = car.x, section.wall_clip + section.dwall * (car.segment_plus_subseg - 1)

	if section.wall_is_invisible then
		if abs(car_x) > wall_clip then
			-- Hit an invisible wall - immediately set to drive parallel to wall
			car.steer_accum = 0
		end

	elseif abs(car_x) >= wall_clip then
		-- Hit a visible wall - bounce back slightly (set accumulator to opposite direction)
		car.steer_accum = -sgn(car_x)
		car.touched_wall = true
		car.touched_wall_sound = true
	end

	car.x = clip_num(car_x, -wall_clip, wall_clip)
end

function calculate_dz(car, section, steering_input_scaled, dx)

	local speed, car_x = car.speed * speed_scale, car.x

	-- Adjust dz according to dx, i.e. account for the fact we're moving diagonally (don't just naively add dx)

	-- local dz = sqrt(max(0, speed*speed - dx*dx)) -- accurate; not necessarily more realistic feeling
	local dz = max(0, speed - 0.25*abs(dx)) -- simplified

	-- Also account for steering & accel input, to account for slight loss of grip (and penalize weaving)

	if (car.engine_accel_brake ~= 0) dz *= (1 - abs(steering_input_scaled)/64)

	-- Scale for corners - i.e. inside of corner has smaller distance to travel

	if (section.angle ~= 0) then
		local track_center_radius = section.length / abs(section.angle * twopi)
		local car_radius = max(0, track_center_radius + (sgn(car_x) == sgn(section.angle) and -car_x or car_x))
		dz *= (track_center_radius + turn_radius_compensation_offset) / (car_radius + turn_radius_compensation_offset)
	end

	return dz
end

function tick_car_speed(car, section, accel_brake_input)

	-- Determine acceleration & speed

	if car.start_delay_counter > 0 then
		car.start_delay_counter -= 1
		return 0
	end

	-- TODO: also factor in slope

	local speed, gear, car_x = car.speed, car.gear, car.x

	local auto_brake = brake_assist or car.ai

	local limit_speed = 1

	local accel = accel_by_gear[flr(gear)]
	if (car.ai and not car.ghost) accel *= rnd(ai_accel_random)

	local decel = brake_decel

	local car_abs_x = abs(car.x)

	local wall_clip = section.wall_clip + section.dwall * (car.segment_plus_subseg - 1)
	if car.touched_wall then
		-- Touching wall
		-- Decrease max speed significantly
		-- Slower acceleration
		-- Faster braking
		-- Increase coasting deceleration significantly
		-- Increase tire deg
		car.touched_wall = false
		limit_speed = min(limit_speed, wall_max_speed)
		decel *= 4
		-- TODO: more parameters
	end

	if car_abs_x >= road.grass_x then
		-- On grass
		-- Decrease max speed significantly
		-- Slower acceleration (unless in 1st gear)
		-- Faster deceleration while above limit, but otherwise slower braking
		-- Increase coasting deceleration significantly
		limit_speed = min(limit_speed, grass_max_speed)
		if (gear > 1) accel *= 0.5
		decel *= 2
		-- TODO: more parameters

	elseif car_abs_x >= road.curb_x then
		-- On curb
		-- Max speed unaffected
		-- Slower acceleration (unless in 1st gear)
		-- Slower braking
		-- Increase coasting deceleration
		-- Increase tire deg slightly
		if (gear > 1) accel *= 0.5
		-- TODO: more parameters
	end

	-- Apply acceleration/braking

	-- FIXME: there's a bug here, once you hit max speed you can't brake

	if speed > limit_speed then
		-- Wall or grass - brake to limit speed
		speed = max(speed - decel, limit_speed)

		if limit_speed == 1 then
			car.engine_accel_brake = 1
		else
			car.engine_accel_brake = -1
		end

	elseif auto_brake and need_to_brake(section, car.segment_plus_subseg, speed) then
		-- Brake, to braking_speed
		accel_brake_input = -1
		speed = max(speed - decel, section.braking_speed)
		car.engine_accel_brake = -1

	elseif auto_brake and speed > section.max_speed - accel then
		-- Right at limit speed (typically mid-corner); maintain speed
		accel_brake_input = 0
		car.engine_accel_brake = 0

	elseif car.ai or accel_brake_input > 0 then
		-- Accelerate
		accel_brake_input = 1
		speed = min(speed + accel, limit_speed)
		car.engine_accel_brake = 1

	elseif accel_brake_input < -1 then
		-- Brake, to zero
		speed = toward_zero(speed, brake_decel)
		car.engine_accel_brake = -1

	elseif accel_brake_input < 0 then
		-- Pressing both brake and accelerator
		-- Auto brake, but with much larger braking distance than normal
		if need_to_brake(section, car.segment_plus_subseg, speed, 8) then
			-- Brake to braking speed
			accel_brake_input = -1
			speed = max(speed - decel, section.braking_speed)
			car.engine_accel_brake = -1
		else
			-- Maintain speed
			accel_brake_input = 0
			car.engine_accel_brake = 0
		end

	else
		-- Coast
		-- TODO: this should be affected by slope even more than regular acceleration is
		-- (which isn't currently at all, but should be in the future)
		speed = max(speed*coast_decel_rel - coast_decel_abs, 0)
		car.engine_accel_brake = 0
	end

	gear = min(speed, 0.99) * #accel_by_gear + 1
	local rpm = gear % 1
	gear = flr(gear)
	if (gear > 1) rpm = 0.0625 + (rpm * 0.9375)

	car.speed, car.gear, car.rpm = speed, gear, rpm

	return accel_brake_input
end

function tick_car_steering(car, steering_input, accel_brake_input)

	if car.ai then
		local section = road[car.section_idx]

		-- Look ahead by dz estimate (Won't know true dz until after steering)
		-- TODO: smarter clipping logic at end of segment (look ahead to next segment)
		local dz_estimate = min(car.segment_idx + car.subseg + car.speed * speed_scale - 1, section.length)

		local target_x = section.entrance_x + dz_estimate*section.racing_line_dx
		if (racing_line_sine_interp) target_x = sin(target_x)
		target_x *= road.half_width

		local steer_strength = 1
		-- TODO
		-- local brake_dist = distance_to_next_braking_point(section, car.segment_plus_subseg)
		-- if (brake_dist > 31) steer_strength = 0.5
		-- if (brake_dist > 63) steer_strength = 0.25
		-- if (brake_dist > 127) steer_strength = 0.125
		-- if (abs(target_x - car.x) > 1) steer_strength = 1

		if target_x < car.x - 0.01 then
			steering_input = -steer_strength
		elseif target_x > car.x + 0.01 then
			steering_input = steer_strength
		else
			steering_input = 0
			-- HACK: logic doesn't take accumulator into account, so we would overshoot
			-- So Just reset the accumulator when we're at racing line
			car.steer_accum = 0
		end
	end

	-- Only steer when moving (but ramp this effect up from 0)
	local steering_scale = min(16*car.speed, 1)
	local steering_input_scaled = steering_input * steering_scale

	--[[ Steering accumulator:
	Don't just start turning immediately; add some acceleration in the X axis
	This essentially represents that the car isn't pointing in quite the same direction as the track
	It also just feels a bit more realistic
	Also to penalize turning while accelerating/braking
	]]
	local steer_accum = car.steer_accum

	if speed == 0 then
		steer_accum = 0
	else
		if sgn0(steering_input_scaled) ~= sgn0(steer_accum) then
			steer_accum = toward_zero(steer_accum, steer_accum_decr_rate)
		end

		local steer_accum_incr_rate = steer_accum_incr_rate_coast
		if (accel_brake_input ~= 0) steer_accum_incr_rate = steer_accum_incr_rate_accel_brake

		steer_accum = clip_num(steer_accum + steering_input_scaled * steer_accum_incr_rate, -1, 1)
	end
	car.x += steer_dx_max * steer_accum * steering_scale
	car.steer_accum = steer_accum

	return steering_input_scaled
end

function tick_car_corner(car, section, dz)
	if (car.ai) return  -- TODO: apply this to AI cars
	-- TODO: scaling by tu is accurate compared to what is displayed on screen, but not necessarily geometric interpretation
	-- should instead be based on section.angle_per_seg
	-- Probably not a big deal right now, because tu is based on angle_per_seg in the first place
	car.x -= turn_dx_scale * dz * section.tu
end

function tick_car_forward(car, dz)

	local section_idx, segment_idx, subseg = car.section_idx, car.segment_idx, car.subseg + dz

	car.heading -= road[section_idx].angle_per_seg * dz
	car.heading %= 1.0

	while subseg >= 1 do
		subseg -= 1
		section_idx, segment_idx = advance(section_idx, segment_idx)

		-- Finish line is at end of 1st segment
		if (section_idx == 2 and segment_idx == 1) then
			car.laps += 1
			-- HACK: Angle has slight error due to fixed-point precision, so reset when we complete the lap
			car.heading = road.start_heading
		end
	end
	assert (subseg < 1)

	while subseg < 0 do
		subseg += 1
		section_idx, segment_idx = reverse(section_idx, segment_idx)

		if (section_idx == 2 and segment_idx == 1) then
			car.laps -= 1
		end
	end
	assert(subseg >= 0 and subseg < 1)

	car.section_idx, car.segment_idx, car.subseg, car.segment_plus_subseg, car.segment_total = section_idx, segment_idx, subseg, segment_idx + subseg, road[section_idx].sumct + segment_idx
end

function tick_car(car, accel_brake_input, steering_input)

	local section, car_x_prev = road[car.section_idx], car.x

	if frozen then
		clip_wall(car, section)
		update_sprite_turn(car, section, 0)
		return
	end

	local accel_brake_input_actual = tick_car_speed(car, section, accel_brake_input)

	-- TODO: clipping wall twice here isn't great, should only need to clip once

	local steering_input_scaled = tick_car_steering(car, steering_input, accel_brake_input_actual)
	clip_wall(car, section)

	local dx = car.x - car_x_prev

	update_sprite_turn(car, section, dx)

	local dz = calculate_dz(car, section, steering_input_scaled, dx)

	tick_car_forward(car, dz)

	tick_car_corner(car, section, dz)
	clip_wall(car, section)
end

function tick_race_start(accel_brake_input)

	assert(not race_started)

	if (not frozen) race_start_counter += 1

	if race_start_num_lights <= 0 then
		-- No lights yet - 2 second delay
		if race_start_counter > 120 then
			race_start_num_lights = 1
			race_start_counter = 0
			sfx(4, 3)
		end
	elseif race_start_num_lights < 5 then
		-- 1-5 lights - 1 second delay
		if race_start_counter > 60 then
			race_start_num_lights += 1
			race_start_counter = 0
			sfx(4, 3)
		end
	else
		-- 5 lights - 1-3 second delay
		if (not race_start_random_delay) race_start_random_delay = 60 + rnd(120)
		if race_start_counter > race_start_random_delay then
			race_started = true
			race_start_num_lights = 0
			race_start_counter = 0
			sfx(5, 3)

			-- If trying to accelerate at the moment lights go out, delay start by 1/2 ssecond (30 frames)
			if (accel_brake_input > 0 and not cars[1].ai) cars[1].start_delay_counter = 30
		end
	end
end

function game_tick()

	if debug then
		tick_debug()
	end

	local steering_input, accel_brake_input = 0, 0
	if (btn(0)) steering_input -= 1
	if (btn(1)) steering_input += 1
	if (btn(2) or btn(4)) accel_brake_input = 1
	if (btn(3) or btn(5)) accel_brake_input -= 2

	if race_started then
		for car in all(cars) do
			tick_car(car, accel_brake_input, steering_input)
		end

		-- TODO: don't do this on every update; only if there was an overtake
		update_car_positions(false)
	else
		tick_race_start(accel_brake_input)
	end
end
