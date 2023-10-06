
function decompress_sections()
	for section_compressed in all(split(road.sections_compressed, ';')) do
		local section = {}
		local section_items = split(section_compressed)
		for idx = 1,#section_items do
			local key_value, key, value = split(section_items[idx], '='), nil, nil
			if (#key_value == 2) then
				key = key_value[1]
				value = key_value[2]
			else
				local field_names = {
					'length',
					'entrance_x',
					'pitch',
					'angle',
					'max_speed',
				}
				key = field_names[idx]
				value = key_value[1]
			end
			-- nil gets parsed as string
			if (value ~= 'nil') section[key] = value
		end
		add(road, section)
	end
end

function init_track()

	road.start_heading = road.start_heading or start_heading
	road.track_width = road.track_width or track_width
	road.half_width = 0.5 * road.track_width

	road.curb_x = road.half_width - shoulder_half_width - car_half_width
	road.grass_x = road.half_width + car_half_width

	if (road.sections_compressed) decompress_sections()

	total_segment_count = 0
	for section in all(road) do
		assert(section.length and section.length > 0)

		-- Defaults

		section.pitch = section.pitch or 0
		section.angle = section.angle or 0
		section.entrance_x = section.entrance_x or 0
		section.max_speed = section.max_speed or 1

		-- Calculated values

		if (racing_line_sine_interp) then
			section.entrance_x = asin(section.entrance_x)
			if (section.entrance_x >= 0.5) section.entrance_x -= 1
		end

		section.angle_per_seg = section.angle / section.length
		section.tu = 16 * section.angle_per_seg

		section.sumct = total_segment_count
		total_segment_count += section.length

		section.tnl = section.tnl or false

		if section.wall then
			section.wall_is_invisible = false
		else
			section.wall = 2 * road.half_width
			section.wall_is_invisible = true
		end

		if (section.tnl) section.wall = road.half_width + shoulder_half_width

		section.wall_clip = section.wall - car_half_width

		if (section.bgl) section.bgl = bg_objects[section.bgl]
		if (section.bgc) section.bgc = bg_objects[section.bgc]
		if (section.bgr) section.bgr = bg_objects[section.bgr]
	end

	-- Now calculate parameters that depend on multiple sections
	-- Iterate in reverse for the sake of braking speeds

	-- This won't be accurate at the last sections, but this should be a straight where you wouldn't normally be braking
	local next_braking_speed, next_braking_distance = 1, 0
	for section_idx = #road, 1, -1 do
		local section0 = road[section_idx]
		local section1 = road[section_idx % #road + 1]

		section0.dpitch = (section1.pitch - section0.pitch) / section0.length

		section0.racing_line_dx = (section1.entrance_x - section0.entrance_x) / section0.length

		if (section1.max_speed < section0.max_speed) then
			next_braking_distance = 0
			next_braking_speed = section1.max_speed
		end
		section0.braking_speed = min(section0.max_speed, next_braking_speed)
		section0.next_braking_distance = next_braking_distance
		next_braking_distance += section0.length
	end
end
