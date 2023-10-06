--
-- Consts
-- (including a few values which can be changed while debugging)
--

pi    = 3.14159265359
twopi = 6.28318530718

racing_line_sine_interp = true

speed_scale = 0.5

-- Acceleration, by gear
-- TOOD: make it 7 gears, but have gear 1 be twice as long
accel_by_gear = {8/2048, 7/2048, 6/2048, 4/2048, 3/2048, 2/2048, 1/2048, 1/4096}

ai_accel_random = {1/1.5, 1/1.25, 1/1.125, 1, 1, 1, 1.125, 1.25}

-- SFX speed: ticks, around 1/120 second
-- This is also how long first note is held before sliding, so don't go higher than 8
sfx_speed_by_gear = {2, 2, 2, 2, 2, 4, 8, 8}

coast_decel_rel = 255/256
coast_decel_abs = 1/2048
brake_decel = 1/128

steer_dx_max = 1/32
steer_accum_incr_rate_accel_brake = 1/32
steer_accum_incr_rate_coast = 3/64
steer_accum_decr_rate = 1/8

turn_radius_compensation_offset = 0.125

turn_dx_scale = 1

grass_max_speed = 0.125
wall_max_speed = 0.25

speed_to_kph = 350

center_line_width = 3/32

car_draw_width, car_draw_height = 0.75, 0.5
car_width = 0.5 * car_draw_width
car_half_width = 0.5 * car_width

cam_dy, cam_dz = 2, 2

-- At 0, the camera is always centered on track and the car moves
-- At 1, the car is always centered on track and the camera moves
cam_x_scale = 0.75

-- TODO: try dynamic draw distance, i.e. stop rendering at certain CPU pct
draw_distance = 90
road_draw_distance = 90
road_detail_draw_distance = 30
sprite_draw_distance = 45
wall_draw_distance = 60

palettes = {
	-- main, accent, wing top, wing rear, dark, floor
	{ 8, 14, 5, 0, 2, 2, name='red' },
	{ 1, 8, 5, 0, 0, 0, name='blue' },
	{ 0, 11, 5, 1, 1, 1, name='black' },
	{ 9, 12, 5, 0, 4, 4, name='orange' },
	{ 3, 11, 5, 0, 5, 0, name='green' },
	{ 10, 0, 5, 0, 5, 0, name='yellow' },
	{ 14, 7, 5, 0, 2, 2, name='pink' },
	{ 6, 7, 5, 0, 5, 0, name='silver' },
}

palette_ghost = {
	7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 6, 7, 6,
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
enable_sound = true
draw_racing_line = true
brake_assist = true
collisions = false
total_segment_count = nil

--
-- Other runtime globals
--

frozen = false

-- TODO: rename "track"
road = nil  -- Setting this also acts as "game started" flag
cars = {}
car_positions = {}
