
function init_game(track_idx, team_idx, is_race, ghost, num_other_cars, ai_only)
	road = tracks[track_idx]
--% if enable_debug
	if (debug) poke(0x5F2D, 1)  -- enable keyboard
--% endif
	poke(0x5f36, 0x40)  -- prevent printing at bottom of screen from triggering scroll
	init_track()
	init_cars(team_idx, ghost, num_other_cars, ai_only)
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
		local start_delay_counter, tire_compound_idx = 0, 2
		if ai and not is_ghost then
			start_delay_counter = 9 + flr(rnd(21))
			tire_compound_idx = 1 + flr(rnd(#tire_compounds))
		end
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
			tire_compound_idx=tire_compound_idx,
			tire_health=1,
			grip=tire_compounds[tire_compound_idx].grip,
			palette=palette,
			ai=ai,
			ghost=is_ghost,
			engine_accel_brake=0,
			track_angle=0,
			heading=road.start_heading,
--% if false
			finished=false,
			in_pit=false,
			touched_wall=false,
			touched_wall_sound=false,
			off_track=false,
			on_curb=false,
--% endif
			start_delay_counter=start_delay_counter,
			other_car_data={
--% if false
				left=nil,
				right=nil,
				next=nil,
				front=nil,
--% endif
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
		return true
	end
	return false
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
		local any_swapped = false
		for idx = 1,#cars-1 do
			if (sort2(car_scores, idx, idx+1)) any_swapped = true
		end
		if (not any_swapped) break
	end

	car_positions = {}
	for item in all(car_scores) do
		add(car_positions, item[1])
	end
end

function car_check_other_cars(car)

	local car_x, segment_idx, subseg, segment_plus_subseg = car.x, car.segment_idx, car.subseg, car.segment_plus_subseg
	local l_distance, r_distance, left, right, next, front

	local car_track_distance = car.segment_total + car.subseg

	-- TODO: don't need to iterate all cars - can look at car_positions and only check the closest few

	for other_car in all(cars) do
		if (other_car.idx ~= car.idx and not other_car.in_pit) then

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

function wear_tires(car, dspeed, dsteer)
--% if tire_wear_scale_dspeed != 1
	dspeed *= "{{ tire_wear_scale_dspeed }}"
--% endif
--% if tire_wear_scale_dsteer != 1
	dsteer *= "{{ tire_wear_scale_dsteer }}"
--% endif

	local compound = tire_compounds[car.tire_compound_idx]

	-- if (dspeed ~= 0 or dspeed ~= 0) printh('dspeed: ' .. dspeed .. ', dsteer: ' .. dsteer) -- DEBUG
	car.tire_health -= sqrt(dspeed*dspeed + dsteer*dsteer) * "{{ tire_wear_scale }}" * compound.deg * road.tire_deg

	if car.tire_health <= 0 then
		car.tire_health = 0
		car.grip = "{{ grip_tires_dead }}"
	else
		car.grip = "{{ grip_tires_min }}" + "{{ 1.0 - grip_tires_min }}" * sqrt(car.tire_health) * compound.grip
	end
end

function check_car_pit(car, section)
	if not section.pit_wall then
		if (car.in_pit) car.track_angle = "{{ -track_angle_pit_exit }}" * sgn(car.x)  -- Pit exit
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

--% if enable_debug
	if (car.in_pit or noclip) return
--% else
	if (car.in_pit) return
--% endif

	local ds = car.segment_plus_subseg - 1
	local car_x, wall_clip_l, wall_clip_r = car.x, section.wall_clip_l + ds*section.dwall_l, section.wall_clip_r + ds*section.dwall_r

	-- Handle wall effects (clipping will be applied later)

	if (car_x < wall_clip_l and not section.wall_l) or (car_x > wall_clip_r and not section.wall_r) then
		-- Hit an invisible wall - immediately set to drive parallel to wall
		if (sgn0(car_x) == sgn0(car.track_angle)) car.track_angle = 0

	elseif car_x < wall_clip_l or car_x > wall_clip_r then
		-- Hit a visible wall - bounce back slightly
		if (sgn0(car_x) == sgn0(car.track_angle)) car.track_angle = -0.5*car.track_angle
		car.touched_wall = true
		car.touched_wall_sound = true
	end

	if collisions then
		-- Clip to other cars, and force leaving space on the side of the track

		-- TODO: account for that there could be more than 1 car we need to leave space for
		-- (not as simple as counting the number of cars to the left or right - one could be in front of another)

		-- TODO: if car is way off track, don't need to leave space

		-- TODO: force update accumulator, like with walls
		-- TODO: decay tires

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

function scale_dz_for_corners(car, section, dz)
	local car_x = car.x
	if (section.angle ~= 0) then
		local track_center_radius = section.length / abs(section.angle * "{{ twopi }}")
		local car_radius = max(0, track_center_radius + (sgn(car_x) == sgn(section.angle) and -car_x or car_x))
		dz *= (track_center_radius + "{{ turn_radius_compensation_offset }}") / (car_radius + "{{ turn_radius_compensation_offset }}")
	end
	return dz
end

function clip_dz(car, dz)

	-- Clip to not hit car in front
	local front = car.other_car_data.front
--% if enable_debug
	if collisions and front and not noclip then
--% else
	if collisions and front then
--% endif
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

	local speed, gear, car_x, segment_plus_subseg, grip = car.speed, car.gear, car.x, car.segment_plus_subseg, car.grip
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
			grip *= 0.25
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

	-- TODO: use grip to limit acceleration
	-- TODO: use grip to limit braking deceleration - will also need to update logic in braking_distance()
	local bdr = braking_distance_relative(section, segment_plus_subseg, speed, grip)

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
	if (accel_brake_input < -1) return move_toward(speed, "{{ brake_decel }}"), accel_brake_input, -1

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

function ai_steering(car, section, dz_estimate)

	-- Look ahead by dz estimate
	-- TODO: smarter clipping logic at end of segment (look ahead to next segment)
	local section_z_estimate = min(car.segment_idx + car.subseg + dz_estimate - 1, section.length)

	local target_x
	if car.in_pit then
		-- TODO: why is this 1/4 the pit lane width? Should be half. Must have an off by 1/2 error somewhere
		target_x = sgn(section.pit) * (road.half_width + "{{ 0.25 * pit_lane_width }}")
	else
--% if racing_line_sine_interp
		target_x = road.half_width * sin(section.entrance_x + section_z_estimate*section.racing_line_dx)
--% else
		target_x = road.half_width * (section.entrance_x + section_z_estimate*section.racing_line_dx)
--% endif
	end

	-- TODO: don't need to prioritize steering when on straights; not sure the best way about this though
	-- local brake_dist = distance_to_next_braking_point(section, car.segment_plus_subseg)
	-- local steer_strength = 1
	-- if (brake_dist > 31) steer_strength = 0.5
	-- if (brake_dist > 63) steer_strength = 0.25
	-- if (brake_dist > 127) steer_strength = 0.125
	-- if (abs(target_x - car.x) > 2) steer_strength = 2

	if (target_x < car.x - 0.01) return -1
	-- if (target_x < car.x - 0.01) return -steer_strength

	if (target_x > car.x + 0.01) return 1
	-- if (target_x > car.x + 0.01) return steer_strength

	-- HACK: logic doesn't take track angle into account, so we would overshoot
	-- So Just reset the track angle when we're at target
	car.track_angle = 0
	return 0
end


function tick_car_steering(car, section, steering_input, accel_brake_input)

	if car.speed == 0 then
		-- Not moving
		car.track_angle = 0
		return 0
	end

	-- This will just be an estimate of dz - won't know true dz until after we've steered
	local _, dz_estimate = calc_dx_dz(car, section)

	-- TODO: if lx or rx, force leaving space for other cars
	-- (This happens in clip_car_x too, but that should be last resort - we should handle this here)

	if (car.in_pit or car.ai) steering_input = ai_steering(car, section, dz_estimate)

	local track_angle = car.track_angle

	-- Adjust angle for corner
	local corner_angle_shift = 0
	-- TODO: apply this to AI too!
	-- (right now it can't handle it)
	if not (car.in_pit or car.ai) then
		corner_angle_shift = -section.angle_per_seg * dz_estimate
		track_angle += corner_angle_shift
	end

	--[[
	Automatically straighten the car out:

	If the camera fully follows the car angle, then when you stop steering, you want the car to keep moving in the same
	direction it was pointed.

	But this is an arcade-style game, so the camera mostly follows the track. If you stop holding a direction but the
	car keeps moving that direction, this feels wrong/unnatural from the camera's POV.

	Essentially, the behavior we want from left/right buttons is not directly what direction we want the steering wheel
	to point, but rather a "move the car left/right on-track" control, which we derive steering wheel direction from.

	So if we were moving to the right along a straight and then let go of right, the car should straighten back out.
	And this should probably happen pretty quickly, otherwise it will feel very "slidey"

	But corners complicate this, and I still haven't figured out a good way to make this feel natural around corners.
	And then to take this a step further, it's not always obvious which sections count as corners or not, because only
	counting sections where the angle is non-zero means we miss the last section before a tight corner (where you've
	probably already started turning), or S-bends where you might want to go at an angle relative to the track.

	To get around this, there's probably something we can do with comparing your current position to the ideal racing
	line, and use that. But need to figure that out.

	Also, about limiting cornering with grip:

	In a proper sim, you would want to limit centripetal acceleration. But that doesn't really work here. The problem
	is, how do you move to the right slightly? In a sim, you would turn the wheel right a little bit, then turn it back
	to center. We don't have that option - steering is just on/off. So you might want to just hold right briefly, but in
	realistic steering wheel terms this is equivalent to turning the steering wheel all the way right and then all the
	way back to center. Or you might want to tap it a few times quickly, which is equivalent to wiggling the wheel back
	& forth several times - this would be really bad if we were using a realistic centripetal acceleration based model.

	So we need a different way of limiting cornering with grip (TODO)
	]]

	if section.angle == 0 then
		-- On a straight

		-- If we're not steering, or steering away from the direction we're pointed, then add an extra push
		if (sgn0(steering_input) ~= sgn0(track_angle)) track_angle = move_toward(track_angle, "{{ track_angle_extra_decr_rate }}")

		local target_angle = "{{ track_angle_target_accel_brake }}"
		if (accel_brake_input == 0) target_angle = "{{ track_angle_target_coast }}"

		track_angle = move_toward(track_angle, "{{ track_angle_incr_rate }}", target_angle*sgn0(steering_input))
	else
		-- On a corner
		-- TODO: currently this uses same logic as straights, but probably want different logic! (see long comment above)

		-- if sgn0(steering_input) == sgn0(track_angle) then
		-- 	-- Steering into corner
		-- 	-- TODO

		-- elseif steering_input == 0 then
		-- 	-- Not steering
		-- 	-- TODO

		-- else
		-- 	-- Steering opposite corner
		-- 	-- TODO
		-- end

		-- If we're not steering, or steering away from the direction we're pointed, then add an extra push
		if (sgn0(steering_input) ~= sgn0(track_angle)) track_angle = move_toward(track_angle, "{{ track_angle_extra_decr_rate }}")

		local target_angle = "{{ track_angle_target_accel_brake }}" + corner_angle_shift
		if (accel_brake_input == 0) target_angle = "{{ track_angle_target_coast }}"

		track_angle = move_toward(track_angle, "{{ track_angle_incr_rate }}", target_angle*sgn0(steering_input))
	end

	-- TODO: clip track angle

	local dsteer = track_angle - car.track_angle
	car.track_angle = track_angle

	return dsteer
end

function replace_tires(car)
	-- TODO: select compound
	car.tire_health = 1
end

function calc_dx_dz(car, section)

	local speed = car.speed * "{{ speed_scale }}"

	local dz, dx = speed * cos(car.track_angle), -speed * sin(car.track_angle)

	dz = scale_dz_for_corners(car, section, dz)

	return dx, dz
end

function tick_car_forward(car, section)

	local dx, dz = calc_dx_dz(car, section)

	dz = clip_dz(car, dz)

	car.subseg += dz

	car.x += dx

	car.heading -= road[car.section_idx].angle_per_seg * dz
	car.heading %= 1.0

	heal_car_section(car)

	return dz
end

function heal_car_section(car)

	local section_idx, segment_idx, subseg = car.section_idx, car.segment_idx, car.subseg

	while subseg >= 1 do
		subseg -= 1
		section_idx, segment_idx = advance(section_idx, segment_idx)

		-- Finish line is at end of 1st segment
		if (section_idx == 2 and segment_idx == 1) then
			car.laps += 1
			-- HACK: Angle has slight error due to fixed-point precision, so reset when we complete the lap
			car.heading = road.start_heading

			if (car.in_pit) replace_tires(car)
		end
	end
	assert (subseg < 1)

--% if enable_debug
	-- Should only be possible with debug stuff
	while subseg < 0 do
		subseg += 1
		section_idx, segment_idx = reverse(section_idx, segment_idx)

		if (section_idx == 2 and segment_idx == 1) then
			car.laps -= 1
		end
	end
--% endif

	assert(subseg >= 0 and subseg < 1)

	car.section_idx, car.segment_idx, car.subseg, car.segment_plus_subseg, car.segment_total = section_idx, segment_idx, subseg, segment_idx + subseg, road[section_idx].sumct + segment_idx
end

function tick_car(car, accel_brake_input, steering_input)

	local section, car_x_prev = road[car.section_idx], car.x

	if (collisions or car.ai) car_check_other_cars(car)
	-- TODO: also use other_car_data for AI logic

--% if enable_debug
	if frozen then
		clip_car_x(car, section)
		heal_car_section(car)
		return
	end
--% endif

	local speed, accel_brake_input_actual, engine_accel_brake = tick_car_speed(car, section, accel_brake_input)
	local dspeed = car.speed - speed  -- TODO: this does not account for loss of speed from hitting another car!
	update_speed(car, speed, engine_accel_brake)

	local dsteer = tick_car_steering(car, section, steering_input, accel_brake_input_actual)

	wear_tires(car, dspeed, dsteer)

	local dz = tick_car_forward(car, section)
	-- Section may have changed
	section = road[car.section_idx]

	-- TODO: should tick corner be before or after entering pit? Could matter if pit entrance is on a curve

	check_car_pit(car, section)

	clip_car_x(car, section)
end

function tick_race_start(accel_brake_input)

	assert(not race_started)

--% if enable_debug
	if (not frozen) race_start_counter += 1
--% else
	race_start_counter += 1
--% endif

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

			-- If trying to accelerate at the moment lights go out, delay start by 1/2 second (30 frames)
			if (accel_brake_input > 0 and not cars[1].ai) cars[1].start_delay_counter = 30
		end
	end
end

function game_tick()

--% if enable_debug
	if (debug) tick_debug()
--% endif

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
