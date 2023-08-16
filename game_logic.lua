
function init_corners()

	for corner in all(road) do
		corner.length *= length_scale
		corner.pitch = corner.pitch or 0
		corner.angle = corner.angle or 0

		corner.angle_per_seg = corner.angle / corner.length
		corner.tu = 16 * corner.angle_per_seg

		corner.sumct = sumct
		sumct += corner.length

		-- TODO: adjust max speed for pitch (also acceleration?)
		local max_speed = min(1.25 - (corner.tu * length_scale), 1)
		max_speed *= max_speed
		corner.max_speed = max_speed

		-- TODO: calculate racing line - entrance X, apex X & segment index, exit X, braking point for corner ahead
	end

	for corner_idx = 1, #road do
		local corner = road[corner_idx]
		local next_corner = road[corner_idx % #road + 1]
		corner.dpitch = (next_corner.pitch - corner.pitch) / corner.length
		-- corner.next_max_speed = next_corner.max_speed
	end
end

function game_tick()

	local steering, accel_brake = 0, 0
	if (btn(0)) steering -= 1
	if (btn(1)) steering += 1
	if (btn(2)) accel_brake += 1
	if (btn(3)) accel_brake -= 1

	if debug then
		while stat(30) do
			local key = stat(31)
			printh('"' .. key .. '"')
			if (key == 'k') cam_z += 0.25
			if (key == 'j') cam_z -= 0.25
			if (key == 'h') car_x -= 0.125
			if (key == 'l') car_x += 0.125
			if (key == '9') cam_dy = max(cam_dy - 0.25, 0.25)
			if (key == '0') cam_dy += 0.25
			if (key == '-') cam_dz = max(cam_dz - 0.25, 0.25)
			if (key == '=') cam_dz += 0.25
		end
	end

	-- Determine acceleration & speed
	-- TODO: look ahead for braking point, slow down; can also speed up after apex
	-- TODO: slow down on curb & grass
	-- TODO: also factor in slope

	local tu = road[camcnr].tu
	local corner_max_speed = road[camcnr].max_speed

	accelerating = false

	if abs(car_x) >= 1 then
		-- On grass
		-- Decrease max speed significantly
		-- Slower acceleration
		-- Slower braking
		-- Increase coasting deceleration
		corner_max_speed = min(corner_max_speed, grass_max_speed)
		-- TODO
	elseif abs(car_x) >= 0.75 then
		-- On curb
		-- Max speed unaffected
		-- Decrease acceleration
		-- Decrease braking
		-- Increase coasting deceleration
		-- TODO
	end

	if curr_speed > corner_max_speed then
		-- Brake (to corner speed)
		curr_speed = max(curr_speed - brake_decel, corner_max_speed)

	elseif accel_brake > 0 then
		-- Accelerate
		-- gear = min(curr_speed, 0.99) * #accel + 1
		local a = accel[flr(gear)]
		curr_speed = min(curr_speed + a, corner_max_speed)
		accelerating = true

	elseif accel_brake < 0 then
		-- Brake (to zero)
		curr_speed = max(curr_speed - brake_decel, 0)
	else
		-- Coast
		-- TODO: this should be affected by slope even more than regular acceleration is
		curr_speed = max(curr_speed*coast_decel_rel - coast_decel_abs, 0)
	end

	gear = min(curr_speed, 0.99) * #accel + 1

	-- Steering & corners

	-- Steering: only when moving (or going up)
	-- TODO: compensate for corners, i.e. push toward outside of corners
	local car_x_prev = car_x
	if steering ~= 0 then
		if curr_speed > 0 then
			car_x += steering * min(8*curr_speed, 1) / 64
		end
		car_x = max(-1.5, min(1.5, car_x))
	end

	cam_x = 0.75 * car_x

	-- Car direction to draw
	-- Based on:
	--    - Did we move left/right
	--    - Is road turning
	--    - Are we near edge of screen

	car_sprite_turn = car_x - car_x_prev
	if (car_sprite_turn ~= 0) car_sprite_turn = sgn(car_sprite_turn)
	if (abs(tu) > 0.1) car_sprite_turn += sgn(car_sprite_turn)
	-- TODO: look at car_x relative to cam_x
	if (abs(car_x) > 0.5) car_sprite_turn -= sgn(car_x)

	-- Move forward

	-- TODO:
	--   - Adjust relative to tu and x position, i.e. inside of corner is faster, outside is slower
	--   - Increment slightly less while steering, but compensated for tu
	--   - Faster while turning into corner
	local dz = 0.5 * speed_scale * curr_speed

	cam_z += dz
	if cam_z > 1 then
		cam_z -= 1
		camcnr, camseg, camtotseg = advance(camcnr, camseg)
	elseif cam_z < 0 then
		cam_z += 1
		camcnr, camseg, camtotseg = reverse(camcnr, camseg)
	end

	-- Update angle & sun coordinate

	angle -= road[camcnr].angle_per_seg * dz
	angle %= 1.0
	-- HACK: Angle has slight error due to fixed-point precision, so reset when we complete the lap
	if (camcnr == 1 and camseg == 1) angle = start_angle

	sun_x = (angle * 512 + 192) % 512 - 256
end
