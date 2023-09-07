
function init_game(track_idx, team_idx, ghost, num_other_cars)
	road = tracks[track_idx]
	if (debug) poke(0x5F2D, 1)  -- enable keyboard
	poke(0x5f36, 0x40)  -- prevent printing at bottom of screen from triggering scroll
	init_cars(team_idx, ghost, num_other_cars)
	init_track()
	init_minimap()
end

function init_cars(team_idx, ghost, num_other_cars)

	collisions = not ghost
	cars = {}

	local teams = {1, 2, 3, 4, 5, 6, 7, 8}

	for zidx = 0, num_other_cars do
		local palette = palettes[team_idx]
		palette = {
			[8]=palette[1],  -- main
			[14]=palette[2],  -- accent 1
			[2]=palette[3],  -- dark
			[13]=palette[4],  -- floor
		}

		local ai = zidx ~= 0

		local segment_idx = 1 + zidx
		local is_ghost = ghost and zidx == 1
		if is_ghost then
			-- Ghost car
			palette = palette_ghost
			segment_idx = 1
		end
		add(cars, {
			x=0,
			laps=-1,
			section_idx=1,
			segment_idx=segment_idx,
			segment_total=segment_idx,
			subseg=0,
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
		if (key == 'k') player_car.subseg += 0.25
		if (key == 'j') player_car.subseg -= 0.25
		if (key == '⌂') player_car.subseg += 1
		if (key == '웃') player_car.subseg -= 1
		if (key == ':') player_car.subseg = 0
		if (key == 'h') player_car.x -= 0.25
		if (key == 'l') player_car.x += 0.25
		if (key == '♥') player_car.x -= 1
		if (key == '⬅️') player_car.x += 1
		if (key == '7') cam_x_scale = max(cam_x_scale - 0.25, 0)
		if (key == '8') cam_x_scale = min(cam_x_scale + 0.25, 1)
		if (key == '9') cam_dy = max(cam_dy - 0.25, 0.25)
		if (key == '0') cam_dy += 0.25
		if (key == '-') cam_dz = max(cam_dz - 0.25, 0.25)
		if (key == '=') cam_dz += 0.25
		if (key == '`') player_car.speed = min(player_car.speed + 0.25, 2)  -- turbo
		if (key == '~') then
			-- turbo for all cars
			for car in all(cars) do
				car.speed = min(car.speed + 0.25, 2)
			end
		end
		if (key == '<') player_car.heading -= 1/256
		if (key == '>') player_car.heading += 1/256
		if (key == 'f') frozen = not frozen
	end
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

	-- TODO: make wall distance changes gradual from 1 section to next

	local car_x, wall_clip = car.x, section.wall_clip

	if section.wall_is_invisible then
		if abs(car_x) > wall_clip then
			-- Hit an invisible wall - immediately set to drive parallel to wall
			car.steer_accum = 0
		end

	elseif abs(car_x) >= wall_clip then
		-- Hit a visible wall - bounce back slightly (set accumulator to opposite direction)
		car.steer_accum = -sgn(car_x)
		car.touched_wall = true
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

	-- TODO: also factor in slope

	local speed, gear, car_x = car.speed, car.gear, car.x

	local limit_speed = 1
	local section_recommended_speed = section.max_speed_pre_apex
	if (section.apex_seg and car.segment_idx >= section.apex_seg) section_recommended_speed = section.max_speed_post_apex

	-- Special check, for now while still not having a proper cornering grip model:
	-- hard-limit speed at apex, in case of insufficient braking
	-- TODO: change this to understeer instead
	if ((brake_assist or car.ai) and section.apex_seg and car.segment_idx == section.apex_seg) speed = min(speed, section.max_speed_pre_apex)

	local accel = accel_by_gear[flr(gear)]
	if (car.ai and not car.ghost) accel *= rnd(ai_accel_random)

	local decel = brake_decel

	if abs(car_x) >= section.wall_clip then
		-- Touching wall
		-- Decrease max speed significantly
		-- Slower acceleration
		-- Faster braking
		-- Increase coasting deceleration significantly
		-- Increase tire deg
		limit_speed = min(limit_speed, wall_max_speed)
		decel *= 4
		-- TODO: more parameters
	end

	if abs(car_x) >= road.half_width then
		-- On grass
		-- Decrease max speed significantly
		-- Slower acceleration (unless in 1st gear)
		-- Faster deceleration while above limit, but otherwise slower braking
		-- Increase coasting deceleration significantly
		limit_speed = min(limit_speed, grass_max_speed)
		if (gear > 1) accel *= 0.5
		decel *= 2
		-- TODO: more parameters

	elseif abs(car_x) >= 0.75 * road.half_width then
		-- On curb
		-- Max speed unaffected
		-- Slower acceleration (unless in 1st gear)
		-- Slower braking
		-- Increase coasting deceleration
		-- Increase tire deg slightly
		if (gear > 1) accel *= 0.5
		-- TODO: more parameters
	end

	-- Apply acceleration

	if speed > limit_speed then
		-- Brake (to section speed)
		speed = max(speed - decel, limit_speed)

		if limit_speed == 1 then
			car.engine_accel_brake = 1
		else
			car.engine_accel_brake = -1
		end

	elseif (brake_assist or car.ai) and speed > section_recommended_speed then
		-- Brake (to recommended speed)
		accel_brake_input = -1
		speed = max(speed - decel, section_recommended_speed)
		car.engine_accel_brake = -1

	elseif car.ai or accel_brake_input > 0 then
		-- Accelerate
		accel_brake_input = 1
		speed = min(speed + accel, limit_speed)
		car.engine_accel_brake = 1

	elseif accel_brake_input < 0 then
		-- Brake (to zero)
		speed = toward_zero(speed, brake_decel)
		car.engine_accel_brake = -1

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

	-- TODO: compensate for corners, i.e. push toward outside of corners

	-- Only steer when moving (but ramp this effect up from 0)
	local steering_scale = min(16*car.speed, 1)
	local steering_input_scaled = steering_input * steering_scale

	-- TODO: steer, following racing line
	if (car.ai) return steering_input_scaled

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
	if (car.ai) return  -- TODO: apply this to AI cars once they steer
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

	car.section_idx, car.segment_idx, car.subseg = section_idx, segment_idx, subseg
	car.segment_total = road[car.section_idx].sumct + car.segment_idx
end

function tick_car(car, accel_brake_input, steering_input)

	local section, car_x_prev = road[car.section_idx], car.x

	car.touched_wall = false

	if frozen then
		clip_wall(car, section)
		update_sprite_turn(car, section, 0)
		return
	end

	local accel_brake_input_actual = tick_car_speed(car, section, accel_brake_input)

	local steering_input_scaled = tick_car_steering(car, steering_input, accel_brake_input_actual)
	clip_wall(car, section)

	local dx = car.x - car_x_prev

	update_sprite_turn(car, section, dx)

	local dz = calculate_dz(car, section, steering_input_scaled, dx)

	tick_car_forward(car, dz)

	tick_car_corner(car, section, dz)
	clip_wall(car, section)
end

function game_tick()

	if debug then
		tick_debug()
	end

	local steering_input, accel_brake_input = 0, 0
	if (btn(0)) steering_input -= 1
	if (btn(1)) steering_input += 1
	-- If pressing both gas & brakes, brakes take priority
	if (btn(2) or btn(4)) accel_brake_input = 1
	if (btn(3) or btn(5)) accel_brake_input = -1

	for car in all(cars) do
		tick_car(car, accel_brake_input, steering_input)
	end

	-- TODO: don't do this on every update; only if there was an overtake
	update_car_positions(false)
end
