
function corner_exit_entrance(section)
	-- TODO: Improve this logic - smoothly interpolate
	local direction = sgn(section.angle)
	if section.max_speed_pre_apex < 0.5 then
		-- Low speed
		return -0.75 * direction
	elseif section.max_speed_pre_apex < 0.75 then
		-- Med speed
		return -0.25 * direction
	else
		-- High speed
		return 0.5 * direction
	end
end

function init_track()

	road.start_heading = road.start_heading or start_heading
	road.track_width = road.track_width or track_width
	road.half_width = 0.5 * road.track_width

	if road.sections_compressed then
		for section_compressed in all(split(road.sections_compressed, ';')) do
			local section = {}
			local section_items = split(section_compressed)
			for idx = 1,#section_items do
				local key_value = split(section_items[idx], '=')

				-- length,[pitch,][angle,][k=v,]

				if (#key_value == 2) then
					section[key_value[1]] = key_value[2]
				elseif idx == 1 then
					section.length = key_value[1]
				elseif idx == 2 then
					section.pitch = key_value[1]
				elseif idx == 3 then
					section.angle = key_value[1]
				else
					assert(false)
				end
			end
			add(road, section)
		end
	end

	total_segment_count = 0
	for section in all(road) do
		assert(section.length and section.length > 0)

		section.pitch = section.pitch or 0
		section.angle = section.angle or 0

		section.angle_per_seg = section.angle / section.length
		section.tu = 16 * section.angle_per_seg

		section.sumct = total_segment_count
		total_segment_count += section.length

		-- TODO: adjust max speed for pitch (adjust acceleration too?)
		local max_speed = min(1.25 - abs(32 * section.angle_per_seg), 1)
		max_speed = max(max_speed, 0.25)
		max_speed *= max_speed
		section.max_speed_pre_apex = max_speed

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

	-- Corner apexes, entrances, exits

	for section_idx = 1, #road do
		local section0 = road[section_idx]
		local section1 = road[section_idx % #road + 1]

		section0.max_speed_post_apex = section1.max_speed_pre_apex

		-- Apexes

		if section0.angle == 0 then
			-- Straight, apex indicates braking point
			-- apex will be updated later once we know next section entrance & apex

		elseif section1.angle ~= 0 and (section0.angle > 0) == (section1.angle > 0) then
			-- 2 corners of same direction in a row
			-- Apex is at end of first
			-- TODO: apex isn't necessarily in the middle of the two - could be double-apex, or just early or late
			-- TODO: special logic for more than 2 section segments in a row
			section0.apex_seg = section0.length
			section0.apex_x = 0.9 * sgn(section0.angle)
			section0.exit_x = section0.apex_x
			section1.apex_seg = 1
			section1.apex_x = section0.apex_x
			section1.entrance_x = section0.apex_x

			section0.entrance_x = corner_exit_entrance(section0)
			section1.exit_x = corner_exit_entrance(section1)

		elseif not section0.apex_seg then
			-- Standalone section, or 2 corners changing direction (e.g. chicane)
			-- Apex is in middle
			section0.apex_seg = section0.length / 2
			section0.apex_x = 0.9 * sgn(section0.angle)
			section0.entrance_x = corner_exit_entrance(section0)
			section0.exit_x = section0.entrance_x
		end
	end

	-- Consolidate entrances & exits

	for section_idx = 1, #road do
		local section0 = road[section_idx]
		local section1 = road[section_idx % #road + 1]

		if section0.exit_x and section1.entrance_x then
			section0.exit_x = 0.5 * (section0.exit_x + section1.entrance_x)
			section1.entrance_x = section0.exit_x
		elseif section0.exit_x then
			section1.entrance_x = section0.exit_x
		elseif section1.entrance_x then
			section0.exit_x = section1.entrance_x
		else
			section0.exit_x, section1.entrance_x = 0, 0
		end

		if not section0.apex_x then

			section0.apex_seg = section0.length
			section0.apex_x = section0.exit_x

			if section1.max_speed_pre_apex < 0.99 then
				-- Use apex to indicate braking point
				local decel_needed = 1.0 - section1.max_speed_pre_apex
				-- FIXME: this isn't right! brake_decel is per frame, not per segment;
				-- frames per segment depends on speed!
				local decel_segments = ceil(decel_needed / (8 * brake_decel))
				decel_segments -= 0.5*section1.apex_seg
				decel_segments = max(0, decel_segments)
				section0.apex_seg = max(2, section0.length - decel_segments)
				section0.apex_x = section0.exit_x
			end
		end
	end

	for section_idx = 1, #road do
		local section0 = road[section_idx]
		local section1 = road[section_idx % #road + 1]

		section0.dpitch = (section1.pitch - section0.pitch) / section0.length

		section0.racing_line_dx_pre_apex = (section0.apex_x - section0.entrance_x) / (section0.apex_seg - 1)
		section0.racing_line_dx_post_apex = 0
		if section0.apex_seg <= section0.length then
			section0.racing_line_dx_post_apex = (section0.exit_x - section0.apex_x) / (section0.length - section0.apex_seg + 1)
		end
	end
end
