
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

	collisions = num_other_cars > 0 and not ghost
	cars = {}

	local teams = {1, 2, 3, 4, 5, 6, 7, 8}

	for idx = 1, num_other_cars+1 do
		local palette = palettes[team_idx]
		palette = {
			[8]=palette[1],  -- main
			[14]=palette[2],  -- accent 1
			[12]=palette[3],  -- wing top
			[1]=palette[4],  -- wing back
			[2]=palette[5],  -- dark
			[13]=palette[6],  -- floor
		}

		local ai = (idx > 1) or ai_only

		local segment_idx = idx
		local is_ghost = ghost and idx == 2
		if is_ghost then
			-- Ghost car
			palette = palette_ghost
			segment_idx = 1
		end
		-- Start reaction time: 0.15 - 0.5 seconds (9-30 frames)
		local start_delay_counter = 0
		if (ai and not is_ghost) start_delay_counter = 9 + flr(rnd(21))
		add(cars, {
			idx=idx,
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
			off_track=false,
			on_curb=false,
			start_delay_counter=start_delay_counter,
			other_car_data={
				left=nil,
				right=nil,
				next=nil,
				front=nil,
			}
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
		local score = (1 + road.total_segment_count)*effective_laps + car.segment_total + car.subseg
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

function car_check_other_cars(car)

	local car_x, segment_idx, subseg, segment_plus_subseg = car.x, car.segment_idx, car.subseg, car.segment_plus_subseg
	local l_distance, r_distance, left, right, next, front = nil, nil, nil, nil, nil, nil

	local car_track_distance = car.segment_total + car.subseg

	-- TODO: don't need to iterate all cars - can look at car_positions and only check the closest few

	for other_car in all(cars) do
		if (other_car.idx ~= car.idx) then

			local dz_ahead = (other_car.segment_total + other_car.subseg - car_track_distance) % road.total_segment_count
			local dz_behind = road.total_segment_count - dz_ahead
			assert(dz_behind > 0)

			local dz = dz_ahead
			if (dz_behind < dz_ahead) dz = -dz_behind

			-- TODO: should this factor in track curvature?
			local dx = other_car.x - car_x

			local car_info = {
				car=other_car,
				dz_ahead=dz_ahead,
				dz=dz,
				dx=dx,
			}

			-- Side by side
			if (dz_ahead < "{{ car_depth_padded }}") or (dz_behind < "{{ car_depth_padded }}") then
				if dx < 0 then
					if -dx <= (l_distance or -dx) then
						l_distance = -dx
						left = car_info
					end
				elseif dx <= (r_distance or dx) then
					r_distance = dx
					right = car_info
				end
			end

			-- Next car directly in front
			if (abs(dx) < "{{ car_width_padded }}" and ((not front) or dz_ahead < front.dz_ahead)) front = car_info

			-- Next car (whether directly in front or not)
			if ((not next) or dz_ahead < next.dz_ahead) next = car_info
		end
	end

	-- TODO: also keep track of closest (by total x & z distance), for sound purposes
	car.other_car_data = {
		left=left,
		right=right,
		next=next,
		front=front,
	}
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

function check_car_pit(car, section)
	if not section.pit_wall then
		if (car.in_pit) car.steer_accum = -sgn(car.x) -- Pit exit
		car.in_pit = false
	elseif
		-- Check for pit entrance
			(
				(section.pit > 0 and car.x > road.track_boundary) or
				(section.pit < 0 and car.x < -road.track_boundary)
			) then
		car.in_pit = true
	end
end

function clip_car_x(car, section)

	if (car.in_pit) return

	if (noclip) return

	local ds = car.segment_plus_subseg - 1
	local car_x, wall_clip_l, wall_clip_r = car.x, section.wall_clip_l + ds*section.dwall_l, section.wall_clip_r + ds*section.dwall_r

	-- Handle wall effects (clipping will be applied later)

	if (car_x < wall_clip_l and not section.wall_l) or (car_x > wall_clip_r and not section.wall_r) then
		-- Hit an invisible wall - immediately set to drive parallel to wall
		if (sgn0(car_x) == sgn0(car.steer_accum)) car.steer_accum = 0

	elseif car_x < wall_clip_l or car_x > wall_clip_r then
		-- Hit a visible wall - bounce back slightly (set accumulator to opposite direction)
		-- car.steer_accum = -sgn(car_x)
		if (sgn0(car_x) == sgn0(car.steer_accum)) car.steer_accum = -sgn(car_x)
		car.touched_wall = true
		car.touched_wall_sound = true
	end

	if collisions then
		-- Clip to other cars, and force leaving space on the side of the track

		-- TODO: account for that there could be more than 1 car we need to leave space for
		-- (not as simple as counting the number of cars to the left or right - one could be in front of another)

		-- TODO: if car is way off track, don't need to leave space

		-- TODO: force update accumulator, like with walls

		local left, right = car.other_car_data.left, car.other_car_data.right
		if left then
			-- HACK: if this car is behind, use slightly larger hitbox
			-- This is to prevent pushing another car - or at least, the one behind cannot push the one in front
			-- TODO: this still doesn't seem to work properly,
			-- likely since clipping is applied before all other cars have moved
			local w = "{{ car_width_padded }}"
			if (left.dz > 0) w += "{{ car_x_hitbox_padding }}"
			car_x = max(car_x, max(left.car.x + w, -road.half_width + w))
		end
		if right then
			local w = "{{ car_width_padded }}"
			if (right.dz > 0) w += "{{ car_x_hitbox_padding }}"
			car_x = min(car_x, min(right.car.x - w, road.half_width - w))
		end
	end

	-- In conflict between car clipping & wall clipping, wall takes priority, so apply it last
	-- (Hopefully conflict shouldn't normally happen due to space logic above, but in case it does)

	car.x = clip_num(car_x, wall_clip_l, wall_clip_r)
end

function calculate_dz(car, section, steering_input_scaled, dx)

	local speed, car_x = car.speed * "{{ speed_scale }}", car.x

	-- Adjust dz according to dx, i.e. account for the fact we're moving diagonally (don't just naively add dx)

	local dz = sqrt(max(0, speed*speed - dx*dx)) -- accurate, though not necessarily more realistic feeling
	-- local dz = max(0, speed - 0.25*abs(dx)) -- simplified

	-- Also account for steering & accel input, to account for slight loss of grip (and penalize weaving)

	-- TODO: figure out which logic we actually want here (and if we even want this at all)
	-- if (car.engine_accel_brake ~= 0) dz *= (1 - abs(steering_input_scaled)/64)
	-- dz *= (1 - abs(steering_input_scaled)/64)
	-- if (not car.ai) dz *= (1 - abs(steering_input_scaled)/64)

	-- Scale for corners - i.e. inside of corner has smaller distance to travel

	if (section.angle ~= 0) then
		local track_center_radius = section.length / abs(section.angle * "{{ twopi }}")
		local car_radius = max(0, track_center_radius + (sgn(car_x) == sgn(section.angle) and -car_x or car_x))
		dz *= (track_center_radius + "{{ turn_radius_compensation_offset }}") / (car_radius + "{{ turn_radius_compensation_offset }}")
	end

	-- Clip to not hit car in front
	local front = car.other_car_data.front
	if collisions and front and not noclip then
		local dz_max = front.dz_ahead - "{{ car_depth + car_depth_hitbox_padding }}"

		if dz > dz_max then
			dz = dz_max
			car.speed = front.car.speed
		end
	end

	return dz
end

function tick_car_speed(car, section, accel_brake_input)
	-- Determine acceleration & speed
	-- returns: speed, accel_brake_input, engine_accel_brake

	-- TODO: engine_accel_brake seems to be obsolete now - can use accel_brake_input to cover this

	if car.start_delay_counter > 0 then
		car.start_delay_counter -= 1
		return 0, 0, 0
	end

	-- TODO: less acceleration if turning (need to reconcile this with logic in tick_car_steering)

	-- TODO: also factor in slope

	-- TODO: if collisions, brake before hitting car.other_car_data.front

	car.off_track, car.on_curb = false, false

	local speed, gear, car_x, segment_plus_subseg = car.speed, car.gear, car.x, car.segment_plus_subseg
	local accel = accel_by_gear[flr(gear)]

	if car.in_pit then
		if speed > "{{ pit_max_speed }}" then
			-- Brake to pit speed
			return max(speed - "{{ brake_decel }}", "{{ pit_max_speed }}"), -1, -1

		elseif speed < "{{ pit_max_speed }}" then
			-- Accelerate to pit speed
			return min(speed + accel, "{{ pit_max_speed }}"), 1, 1
		else
			-- Maintain speed
			-- TODO: should engine_accel_brake be 1 for sound reasons?
			return "{{ pit_max_speed }}", 0, 0
		end
	end

	local auto_brake = brake_assist or car.ai
	local bdr = braking_distance_relative(section, segment_plus_subseg, speed)

	local limit_speed = 1

	-- Randomize acceleration slightly for AI cars
	if (car.ai and not car.ghost) accel *= rnd(ai_accel_random)

	local decel = "{{ brake_decel }}"

	local car_abs_x = abs(car_x)

	if car.touched_wall then
		-- Touching wall
		-- Decrease max speed significantly
		-- Slower acceleration
		-- Faster braking
		-- Increase coasting deceleration significantly
		-- Increase tire deg
		car.touched_wall = false
		limit_speed = min(limit_speed, "{{ wall_max_speed }}")
		decel *= 4
		-- TODO: more parameters
	end

	-- HACK: don't do any of this at pit entrance/exit section
	if section.dpit == 0 then
		if car_abs_x >= road.grass_x then
			-- On grass
			-- Decrease max speed significantly
			-- Slower acceleration (unless in 1st gear)
			-- Faster deceleration while above limit, but otherwise slower braking
			-- Increase coasting deceleration significantly
			car.off_track = true
			limit_speed = min(limit_speed, "{{ grass_max_speed }}")
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
			car.on_curb = true
			if (gear > 1) accel *= 0.5
			-- TODO: more parameters
		end
	end

	-- If we're on wall or grass, limit speed
	if (speed > limit_speed and limit_speed < 1) return max(speed - decel, min(limit_speed, section.braking_speed or 1)), -1, -1

	-- Brake, to braking_speed
	if (auto_brake and bdr < 1.001) return max(speed - decel, section.braking_speed), -1, -1

	-- At max speed (or above - e.g. debug turbo button) - brake to limit speed
	if (speed > limit_speed) return max(speed - decel, limit_speed), -1, 1

	-- Right at limit speed (typically mid-corner); maintain speed
	if (auto_brake and speed > section.max_speed - accel) return speed, 0, 0

	-- Accelerate
	if (car.ai or accel_brake_input > 0) return min(speed + accel, limit_speed), 1, 1

	-- Brake, to zero
	if (accel_brake_input < -1) return toward_zero(speed, "{{ brake_decel }}"), accel_brake_input, -1

	-- Pressing both brake and accelerator - brake, but only to section braking speed
	-- Use much larger braking distance than normal (so can't abuse this in order to perfectly hit braking point)
	if accel_brake_input < 0 then
		-- Brake to braking speed
		if (bdr < 8) return max(speed - decel, section.braking_speed), -1, -1

		-- Maintain speed
		return speed, 0, 0
	end

	-- Finally, if no inputs, coast

	-- TODO: this should be affected by slope even more than regular acceleration is
	-- (which isn't currently at all, but should be in the future)

	assert(accel_brake_input == 0)
	return max(speed * "{{ coast_decel_rel }}" - "{{ coast_decel_abs }}", 0), 0, 0
end

function update_speed(car, speed, engine_accel_brake)
	local gear = min(speed, 0.99) * #accel_by_gear + 1
	local rpm = gear % 1
	gear = flr(gear)
	if (gear > 1) rpm = 0.0625 + (rpm * 0.9375)
	car.speed, car.gear, car.rpm, car.engine_accel_brake = speed, gear, rpm, engine_accel_brake
end

function tick_car_steering(car, steering_input, accel_brake_input)

	-- TODO: if lx or rx, force leaving space for other cars
	-- (This happens in clip_car_x too, but that should be last resort - we should handle this here)

	if car.in_pit or car.ai then
		local section, target_x = road[car.section_idx]

		-- Look ahead by dz estimate (Won't know true dz until after steering)
		-- TODO: smarter clipping logic at end of segment (look ahead to next segment)
		local dz_estimate = min(car.segment_idx + car.subseg + car.speed * "{{ speed_scale }}" - 1, section.length)

		if car.in_pit then
			-- TODO: why is this 1/4 the pit lane width? Should be half. Must have an off by 1/2 error somewhere
			target_x = road.half_width + "{{ 0.25 * pit_lane_width }}"
			target_x *= sgn(section.pit)
		else
--% if racing_line_sine_interp
			target_x = road.half_width * sin(section.entrance_x + dz_estimate*section.racing_line_dx)
--% else
			target_x = section.entrance_x + dz_estimate*section.racing_line_dx
			target_x *= road.half_width
--% endif
		end

		local steer_strength = 1
		-- TODO: don't need to prioritize steering when on straights; not sure the best way about this though
		-- local brake_dist = distance_to_next_braking_point(section, car.segment_plus_subseg)
		-- if (brake_dist > 31) steer_strength = 0.5
		-- if (brake_dist > 63) steer_strength = 0.25
		-- if (brake_dist > 127) steer_strength = 0.125
		-- if (abs(target_x - car.x) > 2) steer_strength = 2

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
			steer_accum = toward_zero(steer_accum, "{{ steer_accum_decr_rate }}")
		end

		local steer_accum_incr_rate = "{{ steer_accum_incr_rate_coast }}"
		if (accel_brake_input ~= 0) steer_accum_incr_rate = "{{ steer_accum_incr_rate_accel_brake }}"

		steer_accum = clip_num(steer_accum + steering_input_scaled * steer_accum_incr_rate, -1, 1)
	end
	car.x += "{{ steer_dx_max }}" * steer_accum * steering_scale
	car.steer_accum = steer_accum

	return steering_input_scaled
end

function tick_car_corner(car, section, dz)
	if (car.ai or car.in_pit) return  -- TODO: apply this to AI cars
	-- TODO: scaling by tu is accurate compared to what is displayed on screen, but not necessarily geometric interpretation
	-- should instead be based on section.angle_per_seg
	-- Probably not a big deal right now, because tu is based on angle_per_seg in the first place

--% if turn_dx_scale != 1
	car.x -= "{{ turn_dx_scale }}" * dz * section.tu
--% else
	car.x -= dz * section.tu
--% endif
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

			-- TODO: if in pit lane, replace tires
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

	if (collisions or car.ai) car_check_other_cars(car)
	-- TODO: also use other_car_data for AI logic

	if frozen then
		clip_car_x(car, section)
		tick_car_forward(car, 0)
		update_sprite_turn(car, section, 0)
		return
	end

	local speed, accel_brake_input_actual, engine_accel_brake = tick_car_speed(car, section, accel_brake_input)
	update_speed(car, speed, engine_accel_brake)

	-- TODO: clip_car_x() twice here isn't great, should only need to clip once

	local steering_input_scaled = tick_car_steering(car, steering_input, accel_brake_input_actual)
	clip_car_x(car, section)

	local dx = car.x - car_x_prev

	update_sprite_turn(car, section, dx)

	local dz = calculate_dz(car, section, steering_input_scaled, dx)

	tick_car_forward(car, dz)
	-- Section may have changed - update it
	section = road[car.section_idx]

	-- TODO: should tick corner be before or after entering pit? Could matter if pit entrance is on a curve

	tick_car_corner(car, section, dz)

	check_car_pit(car, section)

	clip_car_x(car, section)
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
		-- TODO: tick all cars' AI, then tick all forward, then clip all
		-- Right now, if 2 cars go for the same gap in the same frame, the first one gets priority
		-- Iterate in order of who's ahead, for consistency
		for idx in all(car_positions) do
			tick_car(cars[idx], accel_brake_input, steering_input)
		end

		-- TODO: don't do this on every update; only if there was an overtake
		update_car_positions(false)
	else
		tick_race_start(accel_brake_input)
	end
end
