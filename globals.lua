--
-- Consts
-- (including a few values which can be changed while debugging)
--

speed_scale = 1
-- speed_scale = 0.25
-- speed_scale = 0.125
-- speed_scale = 0.0625

-- length_scale = 1
length_scale = 2

-- Acceleration, by gear
-- TOOD: make it 7 gears, but have gear 1 be twice as long
accel = {8/2048, 7/2048, 6/2048, 4/2048, 3/2048, 2/2048, 1/2048, 1/4096}

-- SFX speed: ticks, around 1/120 second
sfx_speed_by_gear = {2, 2, 2, 2, 2, 8, 64, 255}

coast_decel_rel = 255/256
coast_decel_abs = 1/2048
brake_decel = 1/128

grass_max_speed = 0.125

speed_to_kph = 350

cam_dy, cam_dz = 2, 2

road_width = 3
shoulder_width = 1/8

start_angle = 0.25

-- TODO: try dynamic draw distance, i.e. stop rendering at certain CPU pct
draw_distance = 90
road_draw_distance = 90
road_detail_draw_distance = 30
sprite_draw_distance = 45

--
-- Globals that are effectively const after init
--

sumct = 0
minimap = {}
minimap_step = 1

--
-- Runtime options
--

debug = true
print_cpu = true
enable_sound = true
draw_racing_line = true

--
-- Other runtime globals
--

road = nil  -- Setting this also acts as "game started" flag

camcnr, camseg, camtotseg = 1, 1, 1
car_x, cam_x, cam_z = 0, 0, 0
angle = start_angle
sun_x = 64
curr_speed = 0
gear = 1
rpm = 0
car_sprite_turn = 0
accelerating = false
