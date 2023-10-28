--
-- Consts
-- (including a few values which can be changed while debugging)
--

-- Acceleration, by gear
-- TOOD: make it 7 gears, but have gear 1 be twice as long
accel_by_gear = {8/2048, 7/2048, 6/2048, 4/2048, 3/2048, 2/2048, 1/2048, 1/4096}

ai_accel_random = {1/1.5, 1/1.25, 1/1.125, 1, 1, 1, 1.125, 1.25}

-- SFX speed: ticks, around 1/120 second
-- This is also how long first note is held before sliding, so don't go higher than 8
sfx_speed_by_gear = {2, 2, 2, 2, 2, 4, 8, 8}

cam_dy, cam_dz = 2, 2

-- At 0, the camera is always centered on track and the car moves
-- At 1, the car is always centered on track and the camera moves
cam_x_scale = 0.75

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
