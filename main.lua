-- Formula Pico
-- by Joel Geddert
-- License: CC BY-NC-SA 4.0

include("build/generated_data.p64.lua")
include("src_p64/globals.p64.lua")
include("src_p64/graphics_data.p64.lua")
include("src_p64/init_track.p64.lua")
include("src_p64/utils.p64.lua")
include("src_p64/drawing.p64.lua")
include("src_p64/title_screen.p64.lua")
include("src_p64/game_logic.p64.lua")
include("src_p64/minimap.p64.lua")
include("src_p64/sound.p64.lua")
include("src_p64/debug.p64.lua")


function _init()
	load_graphics()
	init_title_screen()
end

function _update()
	if started then
		game_tick()
		update_sound()
	else
		update_title_screen()
	end
	cpu_update = stat(1)
end

function _draw()
	if started then
		draw_bg()
		draw_road()
		draw_minimap()
		draw_hud()
		if debug then
			draw_debug_overlay()
		elseif print_cpu then
			draw_cpu_only_overlay()
		end
	else
		draw_title_screen()
	end
end
