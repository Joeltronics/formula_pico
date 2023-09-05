
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
			accelerating=false,
			heading=start_heading,
			sprite_turn=0,
			finished=false,
			in_pit=false,
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

function tick_car(car, accel_brake, steering)

	local car_x = car.x
	local car_x_prev = car_x
	local section_idx, segment_idx, segment_total = car.section_idx, car.segment_idx, car.segment_total
	local speed, gear = car.speed, car.gear
	local half_width = road.half_width

	-- Determine acceleration & speed
	-- TODO: look ahead for braking point, slow down; can also speed up after apex
	-- TODO: slow down on curb & grass
	-- TODO: also factor in slope

	local section = road[section_idx]

	local tu = section.tu
	local section_max_speed = section.max_speed_pre_apex
	if (section.apex_seg and segment_idx >= section.apex_seg) section_max_speed = section.max_speed_post_apex

	-- Special check: hard-limit speed at apex, in case of insufficient braking
	-- TODO: change this to understeer instead
	if (section.apex_seg and segment_idx == section.apex_seg) speed = min(speed, section.max_speed_pre_apex)

	local accel = accel_by_gear[flr(gear)]
	if (car.ai and not car.ghost) accel *= rnd(ai_accel_random)

	if abs(car_x) >= section.wall then
		-- Touching wall
		-- Decrease max speed significantly
		-- Slower acceleration
		-- Faster braking
		-- Increase coasting deceleration significantly
		-- Increase tire deg
		section_max_speed = min(section_max_speed, wall_max_speed)
		-- TODO

	elseif abs(car_x) >= half_width then
		-- On grass
		-- Decrease max speed significantly
		-- Slower acceleration
		-- Slower braking
		-- Increase coasting deceleration significantly
		section_max_speed = min(section_max_speed, grass_max_speed)
		-- TODO

	elseif abs(car_x) >= 0.75 * half_width then
		-- On curb
		-- Max speed unaffected
		-- Decrease acceleration
		-- Decrease braking
		-- Increase coasting deceleration
		-- Increase tire deg slightly

		-- TODO
	end

	if not frozen then
		car.accelerating = false
		if speed > section_max_speed then
			-- Brake (to section speed)
			speed = max(speed - brake_decel, section_max_speed)

		elseif car.ai or accel_brake > 0 then
			-- Accelerate
			speed = min(speed + accel, section_max_speed)
			car.accelerating = true

		elseif accel_brake < 0 then
			-- Brake (to zero)
			speed = max(speed - brake_decel, 0)
		else
			-- Coast
			-- TODO: this should be affected by slope even more than regular acceleration is
			speed = max(speed*coast_decel_rel - coast_decel_abs, 0)
		end

		gear = min(speed, 0.99) * #accel_by_gear + 1
		local rpm = gear % 1
		gear = flr(gear)
		if (gear > 1) rpm = 0.0625 + (rpm * 0.9375)

		car.speed, car.gear, car.rpm = speed, gear, rpm

		-- Steering & corners

		if car.ai then
			car_x = 0.0  -- TODO: steer, following racing line
		else
			-- Steering: only when moving (or going up)
			-- TODO: compensate for corners, i.e. push toward outside of corners
			if steering ~= 0 then
				if speed > 0 then
					car_x += steering * min(8*speed, 1) / 48
				end
			end
		end
	end

	-- TODO: make wall distance changes gradual from 1 section to next
	local wall_clip = section.wall - 0.5*car_width
	car_x = max(-wall_clip, min(wall_clip, car_x))
	-- TODO: add very slight "bounce back from wall" physics

	car.x = car_x

	-- Car direction to draw
	-- Based on:
	--    - Did we move left/right
	--    - Is road turning
	--    - Are we near edge of screen

	local car_sprite_turn = car_x - car_x_prev
	if (car_sprite_turn ~= 0) car_sprite_turn = sgn(car_sprite_turn)

	if (abs(tu) > 0.1) car_sprite_turn += sgn(car_sprite_turn)
	-- TODO: this should happen at drawing time; also it should be relative to cam_x
	if (abs(car_x) > 0.5*half_width) car_sprite_turn -= sgn(car_x)
	car.sprite_turn = car_sprite_turn

	-- Move forward

	-- TODO:
	--   - Adjust relative to tu and x position, i.e. inside of section is faster, outside is slower
	--   - Increment slightly less while steering, but compensated for tu
	--   - Faster while turning into section
	local dz = 0.5 * speed_scale * speed

	if (frozen) dz = 0

	car.heading -= road[section_idx].angle_per_seg * dz
	car.heading %= 1.0

	local subseg = car.subseg + dz
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

function game_tick()

	if debug then
		tick_debug()
	end

	local steering, accel_brake = 0, 0
	if (btn(0)) steering -= 1
	if (btn(1)) steering += 1
	if (btn(2)) accel_brake += 1
	if (btn(3)) accel_brake -= 1

	for car in all(cars) do
		tick_car(car, accel_brake, steering)
	end

	-- TODO: don't do this on every update; only if there was an overtake
	update_car_positions(false)
end
