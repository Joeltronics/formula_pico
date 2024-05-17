
function init_game(track_idx, team_idx, is_race, ghost, num_other_cars, ai_only)

	load_track(track_idx)
	init_minimap()

	poke(0x5f36, 0x40)  -- prevent printing at bottom of screen from triggering scroll
	init_cars(team_idx, ghost, num_other_cars, ai_only)

	race_started = not is_race
	race_start_counter = 0
	race_start_num_lights = 0
	started = true
end

function init_cars(team_idx, ghost, num_other_cars, ai_only)

	collisions = num_other_cars > 0 and not ghost
	cars = {}

	local unused_teams = {1, 2, 3, 4, 5, 6, 7, 8}

	for idx = 1, num_other_cars+1 do
		local palette = palettes[team_idx]

		local ai = (idx > 1) or ai_only

		local x = 0
		if num_other_cars > 0 and not ghost then
			x = -0.5
			if (idx % 2 ~= 0) x = 0.5
		end

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
			x=x,
			laps=-1,
			section_idx=1,
			segment_idx=segment_idx,
			segment_total=segment_idx,
			subseg=0,
			segment_plus_subseg=segment_idx,
			speed=0,
			gear=1,
			rpm=0,
			dx=0,
			dz=0,
			braking_distance_relative=32767,
			tire_compound_idx=tire_compound_idx,
			tire_health=1,
			grip=tire_compounds[tire_compound_idx].grip,
			palette=palette,
			ai=ai,
			ghost=is_ghost,
			engine_accel_brake=0,
			track_angle=0,
			heading=road.start_heading,
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

		del(unused_teams, team_idx)
		team_idx = rnd(unused_teams)
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
		for idx = 1,#cars-loop_idx do
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

	-- TODO optimization: don't need to iterate all cars - can look at car_positions and only check the closest few

	for other_car in all(cars) do
		if (other_car.idx ~= car.idx and not other_car.in_pit) then

			local dz_ahead = (other_car.segment_total + other_car.subseg - car_track_distance) % road.total_segment_count
			local dz_behind = road.total_segment_count - dz_ahead
			assert(dz_ahead >= 0 and dz_behind >= 0)

			-- Ignore cars that are quite far away
			if min(dz_ahead, dz_behind) < 50 then

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
				if (dz_ahead < car_depth_padded) or (dz_behind < car_depth_padded) then
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

				if (dx > -car_width_padded + min(2*car.dx, 0)) and (dx < car_width_padded + max(2*car.dx, 0)) then
					-- This car is directly in front
					if (not front) or (dz_ahead < front.dz_ahead) then
						front = car_info
					end
				end

				-- Next car (whether directly in front or not)
				if (not next) or (dz_ahead < next.dz_ahead) then
					next = car_info
				end
			end
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
	if (tire_wear_scale_dspeed != 1) dspeed *= tire_wear_scale_dspeed
	if (tire_wear_scale_dsteer != 1) dsteer *= tire_wear_scale_dsteer

	local compound = tire_compounds[car.tire_compound_idx]

	-- if (dspeed ~= 0 or dspeed ~= 0) printh('dspeed: ' .. dspeed .. ', dsteer: ' .. dsteer) -- DEBUG
	car.tire_health -= sqrt(dspeed*dspeed + dsteer*dsteer) * tire_wear_scale * compound.deg * road.tire_deg

	if car.tire_health <= 0 then
		car.tire_health = 0
		car.grip = grip_tires_dead
	else
		car.grip = grip_tires_min + ( 1.0 - grip_tires_min ) * sqrt(car.tire_health) * compound.grip
	end
end

function check_car_pit(car, section)
	if not section.pit_wall then
		if (car.in_pit) car.track_angle = -track_angle_pit_exit * sgn(car.x)  -- Pit exit
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

	if (car.in_pit or noclip) return

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

		-- TODO: force update track angle, like with walls
		-- TODO: decay tires extra when hitting other car

		local left, right = car.other_car_data.left, car.other_car_data.right
		if left then
			-- HACK: if this car is behind, use slightly larger hitbox
			-- This is to prevent pushing another car - or at least, the one behind cannot push the one in front
			-- TODO: this still doesn't seem to work properly,
			-- likely since clipping is applied before all other cars have moved
			local w = car_width_padded
			if (left.dz > 0) w += car_x_hitbox_padding
			-- car_x = max(car_x, max(left.car.x + w, -road.half_width + w))
			car_x = max(car_x, max(left.car.x + w, wall_clip_l))
			-- car_x = max(car_x, left.car.x + w)
		end
		if right then
			local w = car_width_padded
			if (right.dz > 0) w += car_x_hitbox_padding
			-- car_x = min(car_x, min(right.car.x - w, road.half_width - w))
			car_x = min(car_x, min(right.car.x - w, wall_clip_r))
			-- car_x = min(car_x, right.car.x - w)
		end
	end

	-- In conflict between car clipping & wall clipping, wall takes priority, so apply it last
	-- (Hopefully conflict shouldn't normally happen due to space logic above, but in case it does)

	car.x = clip_num(car_x, wall_clip_l, wall_clip_r)
end

function scale_dz_for_corners(car, section, dz)
	local car_x = car.x
	if (section.angle ~= 0) then
		local track_center_radius = section.length / abs(section.angle * twopi)
		local car_radius = max(0, track_center_radius + (sgn(car_x) == sgn(section.angle) and -car_x or car_x))
		dz *= (track_center_radius + turn_radius_compensation_offset) / (car_radius + turn_radius_compensation_offset)
	end
	return dz
end

function clip_dz(car, dz)

	-- Clip to not hit car in front
	local front = car.other_car_data.front
	if collisions and front and not noclip then
		local dz_max = front.dz_ahead - ( car_depth + car_depth_hitbox_padding )

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

	-- TODO: also factor in slope?

	-- Brake if about to hit car in front
	local front = car.other_car_data.front
	if collisions and front then
		assert(front.dz_ahead >= 0)
		local dz = front.dz_ahead - car_depth
		local d_speed = front.car.speed - car.speed

		local dz_next = dz + d_speed * speed_scale

		if dz_next < 0.25 then
			accel_brake_input = -2
		end
	end

	car.off_track, car.on_curb = false, false

	local speed, gear, car_x, segment_plus_subseg, grip = car.speed, car.gear, car.x, car.segment_plus_subseg, car.grip
	local accel = accel_by_gear[flr(gear)]

	if car.in_pit then
		if speed > pit_max_speed then
			-- Brake to pit speed
			return max(speed - brake_decel, pit_max_speed), -1, -1

		elseif speed < pit_max_speed then
			-- Accelerate to pit speed
			return min(speed + accel, pit_max_speed), 1, 1
		else
			-- Maintain speed
			-- TODO: should engine_accel_brake be 1 for sound reasons?
			return pit_max_speed, 0, 0
		end
	end

	local auto_brake = brake_assist or car.ai

	local limit_speed = 1

	-- Randomize acceleration slightly for AI cars
	if (car.ai and not car.ghost) accel *= rnd(ai_accel_random)

	local decel = brake_decel

	local car_abs_x = abs(car_x)

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

	-- HACK: don't do any of this at pit entrance/exit section
	if section.dpit == 0 then
		if car_abs_x >= road.grass_x then
			-- On grass
			-- Decrease max speed significantly
			-- Slower acceleration (unless in 1st gear)
			-- Faster deceleration while above limit, but otherwise slower braking
			-- Increase coasting deceleration significantly
			car.off_track = true
			limit_speed = min(limit_speed, grass_max_speed)
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

	local bdr = car.braking_distance_relative

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
	if (accel_brake_input < -1) return move_toward(speed, brake_decel), accel_brake_input, -1

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
	return max(speed * coast_decel_rel - coast_decel_abs, 0), 0, 0
end

function update_speed(car, speed, engine_accel_brake)
	local gear = min(speed, 0.99) * #accel_by_gear + 1
	local rpm = gear % 1
	gear = flr(gear)
	if (gear > 1) rpm = 0.0625 + (rpm * 0.9375)
	car.speed, car.gear, car.rpm, car.engine_accel_brake = speed, gear, rpm, engine_accel_brake
end

function ai_steering(car, section)

	-- TODO: overtaking & defending logic

	-- Do not steer if not moving
	if (car.dz <= 0) return 0

	-- Prevent steering into other cars
	-- There's very similar logic outside this function, but it's a hard-clip; AI soft-clips
	local steer_min, steer_max = -1, 1
	local left, right = car.other_car_data.left, car.other_car_data.right
	if collisions and left then
		assert(left.dx <= 0.001)
		local dl = -left.dx - 1.125 * car_width
		steer_min = -clip_num(2 * dl, 0, 1)
	end
	if collisions and right then
		assert(right.dx >= -0.001)
		local dr = right.dx - 1.125 * car_width
		steer_max = clip_num(2 * dr, 0, 1)
	end

	-- Look ahead by dz estimate
	-- TODO: smarter clipping logic at end of segment (look ahead to next segment)
	local section_z_estimate = min(car.segment_idx + car.subseg + car.dz - 1, section.length)

	local target_x, target_dxdz
	if car.in_pit then
		-- TODO: why is this 1/4 the pit lane width? Should be half. Must have an off by 1/2 error somewhere
		target_x = sgn(section.pit) * (road.half_width + 0.25 * pit_lane_width)
		target_dxdz = section.angle_per_seg
	else
		if (racing_line_sine_interp) then
			target_x = road.half_width * sin(section.entrance_x + section_z_estimate*section.racing_line_dx)
			target_dxdz = road.half_width * 256 * (
				sin(clip_num(section.entrance_x + (section_z_estimate + 1/256)*section.racing_line_dx, -1, 1)) - 
				sin(clip_num(section.entrance_x + section_z_estimate*section.racing_line_dx, -1, 1))
			)
		else
			target_x = road.half_width * (section.entrance_x + section_z_estimate*section.racing_line_dx)
			target_dxdz = section.racing_line_dx
		end
	end

	-- How far are we from racing line
	-- TODO: compensate for the "push to the outside of the corner" effect
	local err_x = car.x - target_x

	-- How far is our angle from racing line angle
	-- TODO: this should use angle, not dx
	-- TODO: compensate for angle_per_seg (corner_angle_shift)
	assert(car.dz > 0)
	local dxdz = car.dx / car.dz
	local err_dx = dxdz - target_dxdz

	local x_gain, dx_gain = 2.0, 8.0

	if car.in_pit then
		-- In pit
		x_gain, dx_gain = 8.0, 0.0

	elseif car.off_track then
		-- Off track: Always steer towards track
		x_gain = 1024.0

	elseif (car.speed > section.max_speed * 1.05) then
		-- Braking: Do not steer
		-- x_gain, dx_gain = 0.0, 0.0

	elseif (section.angle ~= 0) or (section.max_speed < 1.0) then
		-- Cornering
		-- Leave at defaults

	else
		-- Straight
		-- x error is less important the further away we are from the next braking point

		local steer_strength = 1

		local bp_dist = distance_to_next_braking_point(section, car.segment_plus_subseg)
		if (bp_dist > 31) steer_strength = 1/2
		if (bp_dist > 63) steer_strength = 1/4
		if (bp_dist > 91) steer_strength = 1/8
		if (bp_dist > 127) steer_strength = 1/16

		x_gain *= steer_strength
		-- dx_gain *= steer_strength -- Not sure if we should reduce dx gain too?

		-- dx error is less important further from the racing line
		dx_gain /= max(1, 2 * abs(err_x))
	end

	local steer_val = x_gain * -err_x + dx_gain * -err_dx

	steer_val = clip_num(steer_val, steer_min, steer_max)

	car.err_x = err_x
	car.err_dx = err_dx
	car.ai_steer = steer_val

	return steer_val
end


function tick_car_steering(car, section, steering_input, accel_brake_input)

	if car.speed == 0 then
		-- Not moving
		car.track_angle = 0
		return 0
	end

	-- TODO: if lx or rx, force leaving space for other cars
	-- (This happens in clip_car_x too, but that should be last resort - we should handle this here)
	-- (Also happens in ai_steering, but this only applies to AI)

	if (car.in_pit or car.ai) steering_input = ai_steering(car, section)

	-- Prevent steering into other cars
	local left, right = car.other_car_data.left, car.other_car_data.right
	if collisions and left then
		assert(left.dx <= 0.001)
		local dl = -left.dx - car_width
		if (dl < 0.1) steering_input = max(0, steering_input)
	end
	if collisions and right then
		assert(right.dx >= -0.001)
		local dr = right.dx - car_width
		if (dr < 0.1) steering_input = min(0, steering_input)
	end

	if not analog_steering then
		if (abs(steering_input) < 0.01) steering_input = 0
		steering_input = sgn0(steering_input)
	end

	local track_angle = car.track_angle

	-- Adjust angle for corner
	local corner_angle_shift = 0
	if not car.in_pit then
		corner_angle_shift = -section.angle_per_seg * car.dz
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
		if (sgn0(steering_input) ~= sgn0(track_angle)) track_angle = move_toward(track_angle, track_angle_extra_decr_rate)

		local target_angle = track_angle_target_accel_brake
		local incr_rate = track_angle_incr_rate_accel_brake
		if accel_brake_input == 0 then
			target_angle = track_angle_target_coast
			incr_rate = track_angle_incr_rate_coast
		end

		target_angle *= sgn0(steering_input)

		-- TODO: vary incr_rate with tire grip
		incr_rate *= abs(steering_input)

		track_angle = move_toward(track_angle, incr_rate, target_angle)
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
		if (sgn0(steering_input) ~= sgn0(track_angle)) track_angle = move_toward(track_angle, track_angle_extra_decr_rate)

		local target_angle = track_angle_target_accel_brake
		local incr_rate = track_angle_incr_rate_accel_brake
		if accel_brake_input == 0 then
			target_angle = track_angle_target_coast
			incr_rate = track_angle_incr_rate_coast
		end

		target_angle *= sgn0(steering_input)
		target_angle += corner_angle_shift

		-- TODO: vary incr_rate with tire grip
		-- incr_rate *= abs(steering_input)

		track_angle = move_toward(track_angle, incr_rate, target_angle)
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

	local speed = car.speed * speed_scale

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

	car.dx, car.dz = dx, dz

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

	if allow_debug then
		-- Should only be possible with debug stuff
		while subseg < 0 do
			subseg += 1
			section_idx, segment_idx = reverse(section_idx, segment_idx)

			if (section_idx == 2 and segment_idx == 1) then
				car.laps -= 1
			end
		end
	end

	assert(subseg >= 0 and subseg < 1)

	car.section_idx, car.segment_idx, car.subseg, car.segment_plus_subseg, car.segment_total = section_idx, segment_idx, subseg, segment_idx + subseg, road[section_idx].sumct + segment_idx
end

function tick_car_frozen(car)
	if (collisions or car.ai) car_check_other_cars(car)
	clip_car_x(car, road[car.section_idx])
	heal_car_section(car)
end

function tick_car(car, accel_brake_input, steering_input)

	local section, car_x_prev = road[car.section_idx], car.x

	-- Populate with initial estimate of dz (won't know true dz until after we've steered)
	car.dx, car.dz = calc_dx_dz(car, section)

	if (collisions or car.ai) car_check_other_cars(car)
	-- TODO: also use other_car_data for AI logic

	car.braking_distance_relative = braking_distance_relative(section, car.segment_plus_subseg, car.speed, car.grip)

	local speed, accel_brake_input_actual, engine_accel_brake = tick_car_speed(car, section, accel_brake_input)
	local dspeed = car.speed - speed  -- TODO: this does not account for loss of speed from hitting another car!
	update_speed(car, speed, engine_accel_brake)

	car.braking_distance_relative = braking_distance_relative(section, car.segment_plus_subseg, car.speed, car.grip)

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

	if (frozen_step or not frozen) race_start_counter += 1

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

	if (debug_enabled) tick_debug()

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
			if frozen and not frozen_step then
				tick_car_frozen(cars[idx])
			else
				tick_car(cars[idx], accel_brake_input, steering_input)
			end
		end

		-- TODO: don't do this on every update; only if there was an overtake
		update_car_positions(false)
	else
		tick_race_start(accel_brake_input)
	end

	frozen_step = false
end
