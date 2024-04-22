--
-- Consts
-- (including a few values which can be changed while debugging)
--

-- Build options

enable_debug = true
debug_draw_extra = false
enable_minimap = true
enable_sound = true

-- Constants

pi = 3.14159265359
twopi = 6.28318530718

racing_line_sine_interp = true

speed_to_kph = 350
speed_scale = 0.5

coast_decel_rel = 255/256
coast_decel_abs = 1/2048
brake_decel = 1/128

-- TODO = some of these need to scale with speed
track_angle_max = 30/360
track_angle_target_coast = 30/360
track_angle_target_accel_brake = 15/360
track_angle_pit_exit = track_angle_target_coast
track_angle_incr_rate = track_angle_target_coast * 1/64
track_angle_extra_decr_rate = track_angle_target_coast * 1/16
track_angle_sprite_turn_scale = 2 / track_angle_max

tire_wear_scale = 1/512
tire_wear_scale_dspeed = 8
tire_wear_scale_dsteer = 0.5

-- If tire health <= 0, grip = grip_tires_dead (regardless of compound)
grip_tires_dead = 0.25
-- Otherwise, grip = compound.grip * lerp(grip_tires_min, 1.0, sqrt(health))
grip_tires_min = 0.5

turn_radius_compensation_offset = 0.125

grass_max_speed = 0.125
wall_max_speed = 0.25
pit_max_speed = 80/speed_to_kph

wall_scale = 0.5
-- wall_scale = 0.25  -- DEBUG

shoulder_half_width = 0.125

pit_lane_width = 4

lane_line_width = 3/32

car_draw_height = 0.5

car_draw_width = 0.75
car_width = 0.5 * car_draw_width
car_half_width = 0.5 * car_width

car_depth = 0.5
car_depth_hitbox_padding = 0.01
car_depth_padded = car_depth + car_depth_hitbox_padding

car_x_hitbox_padding = 0.01
car_width_padded = car_width + 2*car_x_hitbox_padding

-- TODO = try dynamic draw distance, i.e. stop rendering at certain CPU pct
draw_distance = 90
road_draw_distance = 90
road_detail_draw_distance = 30
sprite_draw_distance = 45
wall_draw_distance = 60

-- Acceleration, by gear
-- TOOD: make it 7 gears, but have gear 1 be twice as long
accel_by_gear = {8/2048, 7/2048, 6/2048, 4/2048, 3/2048, 2/2048, 1/2048, 1/4096}

ai_accel_random = {1/1.5, 1/1.25, 1/1.125, 1, 1, 1, 1.125, 1.25}

tire_compounds = {
	{pal={[10]=7, [9]=6}, grip=0.75, deg=0.75}, -- hard
	{pal={[10]=10, [9]=9}, grip=1, deg=1}, -- med
	{pal={[10]=8, [9]=2}, grip=1.25, deg=1.25}, -- soft
}

-- SFX speed: ticks, around 1/120 second
-- This is also how long first note is held before sliding, so don't go higher than 8
sfx_speed_by_gear = {2, 2, 2, 2, 2, 4, 8, 8}

cam_dy, cam_dz = 2, 2

--[[
cam_x_scale:
	At 0, the camera is always centered on track and the car moves
	At 1, the car is always centered on track and the camera moves
cam_angle_scale:
	At 0, the camera angle follows the track
	At 1, the camera angle follows the car (car always appears pointed forward)
]]
-- cam_x_scale, cam_angle_scale = 0.75, 0.25
cam_x_scale, cam_angle_scale = 0.75, 0
-- cam_x_scale, cam_angle_scale = 1, 1

palettes = {
	-- main, accent, wing top, wing rear, dark, floor
	{ 8, 14, 5, 0, 2, 2, name='Red' },
	{ 1, 8, 5, 0, 0, 0, name='Blue' },
	{ 0, 11, 5, 1, 1, 1, name='Black' },
	{ 9, 12, 5, 0, 4, 4, name='Orange' },
	{ 3, 11, 5, 0, 5, 0, name='Green' },
	{ 10, 0, 5, 0, 5, 0, name='Yellow' },
	{ 14, 7, 5, 0, 2, 2, name='Pink' },
	{ 6, 7, 5, 0, 5, 0, name='Silver' },
}

palette_ghost = {
	7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 6, 7, 6,
}

palette_race_start_light_out = {
	[2]=1,
	[8]=5,
}

--
-- Globals that are effectively const after init
--

minimap = {}
minimap_step = 1

--
-- Runtime options
--

debug = true
print_cpu = true
draw_racing_line = true
brake_assist = true
collisions = false
total_segment_count = nil

--
-- Other runtime globals
--

frozen = false
noclip = false

-- TODO: rename to "track"
road = nil  -- Setting this also acts as "game started" flag
cars = {}
car_positions = {}

race_started = false
race_start_counter = 0
race_start_num_lights = 0
race_start_random_delay = nil
