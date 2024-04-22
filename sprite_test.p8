pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

#include utils.p8.lua

sprite_turn = 0
max_sprite_turn = 3
x = 64
y = 112
scale = 1

row_zidx = 0
num_rows = 16

rotate = false
rotate_counter = 0
sprite_turn_dir = 1

palette = {[0]=0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15}

palette_main_idx = 8
palette_accent_idx = 14
palette_wing_top_idx = 12
palette_wing_back_idx = 1
palette_dark_idx = 2
palette_floor_idx = 13

function do_load()
	reload(0, 0, 0x4300, "formula_pico.p8")
end

function do_save()
	cstore()
	cstore(0, 0, 0x4300, "formula_pico.p8")
end

function _init()
end

function _update60()

	-- Up/Down
	if btnp(2) then
		row_zidx -= 1
		if (row_zidx == 5 or row_zidx == 13) row_zidx -= 1
	end
	if (btnp(3)) then
		row_zidx += 1
		if (row_zidx == 5 or row_zidx == 13) row_zidx += 1
	end
	row_zidx %= num_rows

	-- Left/Right
	local incr = 0
	if (btnp(0)) incr -= 1
	if (btnp(1)) incr += 1

	if (incr ~= 0) or btnp(4) then
		if (row_zidx == 0) sprite_turn = clip_num(sprite_turn + incr, -max_sprite_turn, max_sprite_turn)
		if (row_zidx == 1) rotate = not rotate
		if (row_zidx == 2) scale = clip_num(scale + 0.125 * incr, 0.125, 4)
		if (row_zidx == 3) x += 0.25 * incr
		if (row_zidx == 4) y += 0.25 * incr
	
		if (row_zidx == 6) palette[palette_main_idx] = (palette[palette_main_idx] + 16 + incr) % 32 - 16
		if (row_zidx == 7) palette[palette_accent_idx] = (palette[palette_accent_idx] + 16 + incr) % 32 - 16
		if (row_zidx == 8) palette[palette_wing_top_idx] = (palette[palette_wing_top_idx] + 16 + incr) % 32 - 16
		if (row_zidx == 9) palette[palette_wing_back_idx] = (palette[palette_wing_back_idx] + 16 + incr) % 32 - 16
		if (row_zidx == 10) palette[palette_dark_idx] = (palette[palette_dark_idx] + 16 + incr) % 32 - 16
		if (row_zidx == 11) palette[palette_floor_idx] = (palette[palette_floor_idx] + 16 + incr) % 32 - 16
		if (row_zidx == 12 and btnp(4)) palette = {[0]=0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15}

		if (row_zidx == 14 and btnp(4)) do_load()
		if (row_zidx == 15 and btnp(4)) do_save()
	end

	if rotate then
		rotate_counter = (rotate_counter + 1) % 10

		if (rotate_counter == 0) then
			if (abs(sprite_turn) == max_sprite_turn) sprite_turn_dir = -sprite_turn_dir
			sprite_turn += sprite_turn_dir
		end
	end
end

function _draw()
	cls(5)

	print(' sprite_turn: ' .. sprite_turn, 0)
	print(' rotate: ' .. (rotate and 'true' or 'false'))
	print(' scale: ' .. scale)
	print(' x: ' .. x)
	print(' y: ' .. y)
	print('')
	print(' palette main:      \#' ..  digit_to_hex_char(palette_main_idx) .. palette[palette_main_idx])
	print(' palette accent:    \#' ..  digit_to_hex_char(palette_accent_idx) .. palette[palette_accent_idx])
	print(' palette wing top:  \#' ..  digit_to_hex_char(palette_wing_top_idx) .. palette[palette_wing_top_idx])
	print(' palette wing back: \#' ..  digit_to_hex_char(palette_wing_back_idx) .. palette[palette_wing_back_idx])
	print(' palette dark:      \#' ..  digit_to_hex_char(palette_dark_idx) .. palette[palette_dark_idx])
	print(' palette floor:     \#' ..  digit_to_hex_char(palette_floor_idx) .. palette[palette_floor_idx])
	print(' reset palette')	
	print('')
	print(' load')
	print(' save')

	print('>', 0, 6 * row_zidx)

	palt(0, false)
	palt(11, true)

	pal(palette, 1)

	for col = 0,15 do
		rectfill(col*8, 120, (1+col)*8, 128, 128 + col)
	end

	local flip_x = sprite_turn < 0
	local sx = 24 * min(max_sprite_turn, ceil(abs(sprite_turn)))

	local w, h = 24 * scale, 16 * scale
	local sprx = x - (12 * scale)
	local spry = y - h

	sspr(
		sx, 0, 24, 16,
		sprx, spry, w, h,
		flip_x
	)

	-- palt()
	-- pal()
end

__gfx__
bbbbbbbbbb8888bbbbbbbbbbbbbbbbbbbbbb8888bbbbbbbbbbbbb000bbbbb888bbbbbbbbbbbbbbb000bbbb888bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbb000bbb88ee88bbb000bbbbbbb000bbbb88e888bb000bbbbbb06550bbb88e88bb000bbbbbbbb06550bb88e88bb000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bb065588888ee888885560bbbbb065588888ee888885560bbbbb000088888e888885560bbbbbbee0008888e888805560bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bb000e88888ee88888e000bbbbb00e088888e88888e0000bbbbb0e0088888e888880006bbbbbbeccc0888e8888800006bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bb000ecccccccccccce000bbbbb00eccccccccccccee000bbbbb0ecccccce8888e80006bbbbbbe111cccc8888e800006bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bb000e111111111111e000bbbbb00e111111111111ee000bbbbbbe111111cccccee0000bbbbbbe1111111ccccee00000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbb00e188111111881e00bbbbbbb0e188111111881e000bbbbbbbe18111111111ee000bbbb000b18811111111eee000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbb188881188881bbbbbbbbbbbb188881188881bbbbbbbb000018881188881ebbbbbbb6555018881188881eebbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
b0000088888558888800000bb0000088888558888800000b0655508888558888800000bb600008888558888800000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
00655588882662888855560006555588882662888055560060000888826628880555600b0000088826628880555600bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
06000088826006288800006060000088826006288000000000000888260062880000005000000222600628800000050bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
00000088226006228800000000000088226006228000000600000222260062280000056500000dd2600622800000565bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
00000022222662222200000000000022222662222000000600000ddddd662222000005650000000dd66222200000565bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
000000dddddddddddd000000000000ddddddddddd00000000000000bbbbddddd00000050b00000bbbbbdddd00000050bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
0000000bbbbbbbbbb00000000000000bbbbbbbbbb0000000b00000bbbbbbbbbb0000000bbbbbbbbbbbbbbbb0000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
b00000bbbbbbbbbbbb00000bb00000bbbbbbbbbbbb00000bbbbbbbbbbbbbbbbbb00000bbbbbbbbbbbbbbbbbb00000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
0003000000000000444444440000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00007777000077770000777700007777
0003000000000000455599940000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00007777000077770000777700007777
0033000000000000495559940000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00007777000077770000777700007777
0033300000000000499555940000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00007777000077770000777700007777
0033300000000000499955540000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb77770000777700007777000077770000
033b300000000000499555940000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb77770000777700007777000077770000
03bb300000000000495559940000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb77770000777700007777000077770000
03bb330000000000455599940000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb66660000666600006666000066660000
03bbbb3000000000444444440000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82bbbb28bbbbbbbbbbbbbbbbbbbbbbbb
33bbb33300000000000660000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb882bb288bbbbbbbbbbbbbbbbbbbbbbbb
33bbb33500000000000660000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82822828bbbbbbbbbbbbbbbbbbbbbbbb
533b335500000000000660000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb8b2882b8bbbbbbbbbbbbbbbbbbbbbbbb
0533335000000000000660000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb8b2882b8bbbbbbbbbbbbbbbbbbbbbbbb
0055550000000000000660000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82822828bbbbbbbbbbbbbbbbbbbbbbbb
0004400000000000000660000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb882bb288bbbbbbbbbbbbbbbbbbbbbbbb
0004400000000000000660000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82bbbb28bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82bbbb28bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb882bb288bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82822828bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb8b2882b8bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb8b2882b8bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82822828bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb882bb288bbbbbbbbbbbbbbbbbbbbbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82bbbb28bbbbbbbbbbbbbbbbbbbbbbbb
0030b030b030003000dddd00ddd6605500000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82bbbb28bbbbbbbbbbbbbbbbbbbbbbbb
033bb33bb33b0330666dfff0dd66665500000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb882bb288bbbbbbbbbbbbbbbbbbbbbbbb
333b3333b33b33336c6dff66dd6cc65500000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82822828bbbbbbbbbbbbbbbbbbbbbbbb
333333b3333333b3666dff66dd66665500000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb8b2882b8bbbbbbbbbbbbbbbbbbbbbbbb
33bb33bb33bb3bbb6c6dff66dd6cc65500000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb8b2882b8bbbbbbbbbbbbbbbbbbbbbbbb
3bb553bb3bb533b5666dff66dd66665500000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82822828bbbbbbbbbbbbbbbbbbbbbbbb
b5553555b55555536c6dff66dd6cc65500000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb882bb288bbbbbbbbbbbbbbbbbbbbbbbb
0343034330430340666dff66dd66660000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb82bbbb28bbbbbbbbbbbbbbbbbbbbbbbb
__sfx__
490800040045200452004520045200402004020040200402004020040200402004020040200402004020040200402004020040200402004020040200400004000040000400004000040000400004000040000400
4b06000b0067034671006712467100671306710c671186711c6713067134671000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
490802030025001251012520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
910802031c1501d1511d1520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
