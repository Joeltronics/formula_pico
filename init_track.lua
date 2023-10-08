
function decompress_sections()
	for section_compressed in all(split(road.sections_compressed, ';')) do
		local section = {}
		local section_items = split(section_compressed)
		for idx = 1,#section_items do
			local field_names = {
				'length',
				'entrance_x',
				'pitch',
				'angle',
				'max_speed',
				'wall',
				'section_type',
			}
			key = field_names[idx]
			value = section_items[idx]
			-- nil gets parsed as string
			if (value ~= 'nil') section[key] = value
		end
		if section.section_type then
			for k, v in pairs(section_types[section.section_type + 1]) do
				section[k] = v
			end
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

		section.angle_per_seg = section.angle / section.length
		section.tu = 16 * section.angle_per_seg

		section.sumct = total_segment_count
		total_segment_count += section.length

		section.tnl = section.tnl or false

		section.wall_is_invisible = false
		if section.tnl then
			-- TODO: should this be shoulder_width?
			section.wall = road.half_width + shoulder_half_width
		elseif section.wall then
			--
		elseif section.iwall then
			section.wall = section.iwall
			section.wall_is_invisible = true
		elseif road.wall then
			section.wall = road.wall
		else
			section.wall = road.iwall or 2*road.half_width
			section.wall_is_invisible = true
		end

		section.wall_clip = section.wall - car_half_width

		section.entrance_x = clip_num(section.entrance_x, -section.wall_clip + 0.01, section.wall_clip - 0.01)
		section.entrance_x = clip_num(section.entrance_x, -road.grass_x + 0.01, road.grass_x - 0.01)

		if (racing_line_sine_interp) then
			section.entrance_x = asin(section.entrance_x)
			if (section.entrance_x >= 0.5) section.entrance_x -= 1
		end

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

		-- TODO: only need this to narrow gradually - can widen instantly
		-- (like for tunnels)
		section0.dwall = (section1.wall - section0.wall) / section0.length
		if (section0.tnl) section0.dwall = 0

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
