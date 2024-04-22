-- Formula Pico
-- by Joel Geddert
-- License: CC BY-NC-SA 4.0

include("build/generated_data.p64.lua")
include("consts.p64.lua")
include("globals.p64.lua")
-- include("init_track.p64.lua")
-- include("bg_objects.p64.lua")
-- include("utils.p64.lua")
-- include("drawing.p64.lua")
include("title_screen.p64.lua")
-- include("game_logic.p64.lua")
-- include("minimap.p64.lua")
-- include("sound.p64.lua")
-- include("debug.p64.lua")


function _init()
	init_title_screen()
end

function _update60()
	if road then
		-- game_tick()
		-- update_sound()
	else
		update_title_screen()
	end
end

function _draw()
	if road then
		-- draw_bg()
		-- draw_road()
		-- draw_minimap()
		-- draw_hud()
		-- if debug then
		-- 	draw_debug_overlay()
		-- elseif print_cpu then
		-- 	draw_cpu_only_overlay()
		-- end
	else
		draw_title_screen()
	end
end
