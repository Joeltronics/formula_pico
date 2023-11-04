
function decompress_sections()
	local comp = road.sections_compressed
	assert(#comp % 7 == 0)
	for idx = 1, #comp, 7 do
		local wall = ord(comp[idx + 5])
		local section = {
			length = ord(comp[idx]) + 1,
			entrance_x = (ord(comp[idx + 1]) - 128) / 64,
			pitch = (ord(comp[idx + 2]) - 127) / 64,
			angle = (ord(comp[idx + 3]) - 128) / 128,
			max_speed = ord(comp[idx + 4]) / 255,
			wall_l = wall \ 16,
			wall_r = wall % 16
		}
		local section_type = ord(comp[idx + 6])
		if section_type ~= 0 then
			assert(section_type <= #section_types)
			for k, v in pairs(section_types[section_type]) do
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

	road.minimap_scale = 1 / road.minimap_scale

	road.curb_x = road.half_width - "{{ shoulder_half_width }}" - "{{ car_half_width }}"
	road.grass_x = road.half_width + "{{ car_half_width }}"

	-- FIXME: There must be a drawing bug somewhere - full curb width should be correct, but 1/4 width is what draws it correctly
	-- road.track_boundary = road.half_width + 2*"{{ shoulder_half_width }}"
	road.track_boundary = road.half_width + 0.5*"{{ shoulder_half_width }}"
	-- road.track_boundary = road.half_width + "{{ shoulder_half_width }}"

	road.tire_deg = road.tire_deg or 1

	road.lanes = road.lanes or 1

	if (road.sections_compressed) decompress_sections()

	local total_segment_count, heading = 0, road.start_heading
	for section_idx = 1,#road do
		local section = road[section_idx]
		local next = road[section_idx % #road + 1]

		assert(section.length and section.length > 0)

		-- Defaults

		section.pitch = section.pitch or 0
		section.angle = section.angle or 0
		section.entrance_x = section.entrance_x or 0
		section.max_speed = section.max_speed or 1
		section.pit = section.pit or 0

		-- Calculated values

		section.angle_per_seg = section.angle / section.length
		section.tu = 16 * section.angle_per_seg

		section.heading = heading
		heading = (heading + section.angle) % 1

		section.sumct = total_segment_count
		total_segment_count += section.length

		section.tnl = section.tnl or false

		if section.tnl then
			section.wall_l, section.wall_r = 0, 0
		else
			section.wall_r = section.wall_r or road.wall or 15
			section.wall_l = section.wall_l or road.wall or 15
		end

		-- Convert wall_l/wall_r from 0-15 to actual units
		-- TODO: if 15, make wall invisible
		section.wall_r = road.track_boundary + section.wall_r * "{{ wall_scale }}"
		section.wall_l = -road.track_boundary - section.wall_l * "{{ wall_scale }}"	 

		section.wall_clip_l = section.wall_l + "{{ car_half_width }}"
		section.wall_clip_r = section.wall_r - "{{ car_half_width }}"

		-- Pit wall clip logic (but not at pit entrance/exit!)
		if section.pit == 1 and next.pit == 1 then
			section.pit_wall, section.wall_clip_r = road.track_boundary, road.track_boundary - "{{ car_half_width }}"
		elseif section.pit == -1 and next.pit == -1 then
			section.pit_wall, section.wall_clip_l = -road.track_boundary, "{{ car_half_width }}" - road.track_boundary
		end

		section.entrance_x = clip_num(section.entrance_x, section.wall_clip_l + 0.01, section.wall_clip_r - 0.01)
		section.entrance_x = clip_num(section.entrance_x, -road.grass_x + 0.01, road.grass_x - 0.01)

--% if racing_line_sine_interp
		section.entrance_x = asin(section.entrance_x)
		if (section.entrance_x >= 0.5) section.entrance_x -= 1
--% endif

		if (section.bgl) section.bgl = bg_objects[section.bgl]
		if (section.bgc) section.bgc = bg_objects[section.bgc]
		if (section.bgr) section.bgr = bg_objects[section.bgr]
	end

	if (total_segment_count ~= road.total_segment_count) printh('WARNING: track data had segment count: ' .. road.total_segment_count .. ', actual count: ' .. total_segment_count)
	road.total_segment_count = total_segment_count

	if (heading ~= road.start_heading) printh('WARNING: Start heading: ' .. road.start_heading .. ', end heading: ' .. heading)

	-- Now calculate parameters that depend on multiple sections
	-- Iterate in reverse for the sake of braking speeds

	-- This won't be accurate at the last sections, but this should be a straight where you wouldn't normally be braking
	local next_braking_speed, next_braking_distance = 1, 0
	for section_idx = #road, 1, -1 do
		local section0 = road[section_idx]
		local section1 = road[section_idx % #road + 1]

		section0.dpitch = (section1.pitch - section0.pitch) / section0.length

		section0.dpit = (section1.pit - section0.pit) / section0.length

		-- TODO: only need this to narrow gradually - can widen instantly
		-- (already the case for tunnels, can make this everywhere)
		section0.dwall_l = (section1.wall_l - section0.wall_l) / section0.length
		section0.dwall_r = (section1.wall_r - section0.wall_r) / section0.length
		if (section0.tnl) section0.dwall_l, section0.dwall_r = 0, 0

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
