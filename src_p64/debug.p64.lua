function tick_debug()

	if (not debug) return

	local player_car = cars[1]
	local shift = key("shift")

	if race_started then
		if (keyp('t')) replace_tires(player_car)
		if (keyp('k') and not shift) player_car.subseg += 0.25
		if (keyp('j') and not shift) player_car.subseg -= 0.25
		if (keyp('k') and shift) player_car.subseg += 1
		if (keyp('j') and shift) player_car.subseg -= 1
		if (keyp(':')) player_car.subseg = 0
		if (keyp('h') and not shift) player_car.x -= 0.25
		if (keyp('l') and not shift) player_car.x += 0.25
		if (keyp('h') and shift) player_car.x -= 1
		if (keyp('l') and shift) player_car.x += 1
		if (keyp('`') and not shift) player_car.speed = min(player_car.speed + 0.25, 2) -- turbo
		if (keyp('`') and shift) then
			-- turbo for all cars
			for car in all(cars) do
				car.speed = min(car.speed + 0.25, 2)
			end
		end
	else
		if (keyp('`') or keyp('~')) race_start_counter += 15
		if keyp('s') then
			race_started = true
			race_start_num_lights = 0
			race_start_counter = 0
			sfx(5, 3)
		end
	end

	if (keyp('7')) cam_x_scale = max(cam_x_scale - 0.25, 0)
	if (keyp('8')) cam_x_scale = min(cam_x_scale + 0.25, 1)
	if (keyp('9')) cam_dy = max(cam_dy - 0.25, 0.25)
	if (keyp('0')) cam_dy += 0.25
	if (keyp('-')) cam_dz = max(cam_dz - 0.25, 0.25)
	if (keyp('=')) cam_dz += 0.25
	if (keyp('<')) player_car.heading -= 1/256
	if (keyp('>')) player_car.heading += 1/256
	if (keyp('f')) frozen = not frozen
	if (keyp('n')) noclip = not noclip

	player_car.segment_plus_subseg = player_car.segment_idx + player_car.subseg
end

_prev_tire = 1

function draw_debug_overlay()

	if (not debug) return

	local player = cars[1]
	local section = road[player.section_idx]

	cursor(225, 0, 8)
	if (frozen) print('frozen')
	if (noclip) print('noclip')
	if (player.in_pit) print('pit')

	cursor(430, 0, 5)
	print("cpu:" .. round(stat(1) * 100))
	print("mem:" .. round(stat(0) * 100 / 2048))
	print(player.section_idx .. "," .. player.segment_idx .. ',' .. player.subseg)
	print('carx:' .. player.x)
	-- print('hw:' .. road.half_width)
	-- print('wall:' .. -section.wall_l .. ',' .. section.wall_r)

	if cam_dy ~= 2 or cam_dz ~= 2 then
		print('cam:' .. cam_x .. ',' .. cam_dy .. ',' .. cam_dz)
	else
		print('cam:' .. cam_x)
	end

	print('ang:' .. 360*player.track_angle)

	print('tire:' .. player.tire_health)
	print('grip:' .. player.grip)
	print('deg:' .. 6000*(_prev_tire - player.tire_health)) -- percent per second
	_prev_tire = player.tire_health

	-- local pitch = (section.pitch + section.dpitch*(segment_idx - 1))
	-- print('pi:' .. pitch)

	-- print('bd: ' .. braking_distance(player.speed, section.braking_speed))
	-- print('bp: ' .. distance_to_next_braking_point(section, player.segment_plus_subseg))
	-- print('bs: ' .. round(speed_to_kph * section.braking_speed))
	-- print('bdr: ' .. braking_distance_relative(section, player.segment_plus_subseg, player.speed, player.grip))

	-- if (player.other_car_data.lx) print('l:' .. (player.x - player.other_car_data.lx))
	-- if (player.other_car_data.rx) print('r:' .. (player.other_car_data.rx - player.x))
	-- if (player.other_car_data.front) print('f:' .. player.other_car_data.front.dz)
	-- if (player.other_car_data.next) print('n:' .. player.other_car_data.next.dz)
end
