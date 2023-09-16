
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
					'max_speed_pre_apex',
					'apex_seg',
					'apex_x',
					'max_speed_post_apex'
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

	if (road.sections_compressed) decompress_sections()

	total_segment_count = 0
	for section in all(road) do
		assert(section.length and section.length > 0)

		-- Defaults

		section.pitch = section.pitch or 0
		section.angle = section.angle or 0
		section.entrance_x = section.entrance_x or 0
		section.max_speed_pre_apex = section.max_speed_pre_apex or 1
		section.apex_seg = section.apex_seg or section.length + 1
		section.apex_x = section.apex_x or 0
		section.max_speed_post_apex = section.max_speed_post_apex or 1

		-- Calculated values

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

		-- TODO: why is this 2x needed?
		if (section.tnl) section.wall = road.half_width + 2*shoulder_half_width

		section.wall_clip = section.wall - 0.5*car_width

		if (section.bgl) section.bgl = bg_objects[section.bgl]
		if (section.bgc) section.bgc = bg_objects[section.bgc]
		if (section.bgr) section.bgr = bg_objects[section.bgr]
	end

	for section_idx = 1, #road do
		local section0 = road[section_idx]
		local section1 = road[section_idx % #road + 1]

		section0.dpitch = (section1.pitch - section0.pitch) / section0.length

		section0.racing_line_dx_pre_apex = (section0.apex_x - section0.entrance_x) / (section0.apex_seg - 1)
		section0.racing_line_dx_post_apex = 0
		if section0.apex_seg <= section0.length then
			section0.racing_line_dx_post_apex = (section1.entrance_x - section0.apex_x) / (section0.length - section0.apex_seg + 1)
		end
	end
end
