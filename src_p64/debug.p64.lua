function tick_debug()

	if (not debug_enabled) return

	local player_car = cars[1]
	local shift = key("shift")
	local ctrl = key("ctrl")

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

	if shift and not ctrl then
		if (keyp('1')) enable_draw.horizon_ground = not enable_draw.horizon_ground
		if (keyp('2')) enable_draw.horizon_objects = not enable_draw.horizon_objects
		if (keyp('3')) enable_draw.tunnel = not enable_draw.tunnel
		if (keyp('4')) enable_draw.ground = not enable_draw.ground
		if (keyp('5')) enable_draw.road = not enable_draw.road
		if (keyp('6')) enable_draw.curbs = not enable_draw.curbs
		if (keyp('7')) enable_draw.walls = not enable_draw.walls
		if (keyp('8')) enable_draw.bg_sprites = not enable_draw.bg_sprites
		if (keyp('9')) enable_draw.cars = not enable_draw.cars
		if (keyp('0')) enable_draw.debug_extra = not enable_draw.debug_extra
	end

	if not (ctrl or shift) then
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
	end
	if shift and not ctrl then
		if (keyp('f') and frozen) frozen_step = true
	end

	player_car.segment_plus_subseg = player_car.segment_idx + player_car.subseg
end

_prev_tire = 1

function draw_debug_overlay()

	if (not debug_enabled) return

	local player = cars[1]
	local section = road[player.section_idx]

	color(8)
	cursor(225, 0)
	if (frozen) print('Frozen')
	if (noclip) print('Noclip')
	if (player.in_pit) print('Pit')
	if (not enable_draw.horizon_ground) print('Horizon ground hidden')
	if (not enable_draw.horizon_objects) print('Horizon objects hidden')
	if (not enable_draw.tunnel) print('Tunnel hidden')
	if (not enable_draw.ground) print('Ground hidden')
	if (not enable_draw.road) print('Road hidden')
	if (not enable_draw.curbs) print('Curbs hidden')
	if (not enable_draw.walls) print('Walls hidden')
	if (not enable_draw.bg_sprites) print('BG objects hidden')
	if (not enable_draw.cars) print('Cars hidden')

	cursor(430, 0)
	print("cpu:" .. round(stat(1) * 100))
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

	if (player.err_x) print('e_x: ' .. player.err_x)
	if (player.err_dx) print('e_dx:' .. player.err_dx)
	if (player.ai_steer) print('aist:' .. player.ai_steer)
end
