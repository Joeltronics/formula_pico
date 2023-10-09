pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

filename = 'p8scii.py'

-- Partially based on: https://www.lexaloffle.com/bbs/?tid=38692

function escape_binary_str(s)
	local out=""
	for i=1,#s do
		local c  = sub(s,i,i)
		local nc = ord(s,i+1)
		local pr = (nc and nc>=48 and nc<=57) and "00" or ""
		local v=c
		if(c=="\"") v="\\\""
		if(c=="\\") v="\\\\"
		if(ord(c)==0) v="\\"..pr.."0"
		if(ord(c)==10) v="\\n"
		if(ord(c)==13) v="\\r"
		out ..= v
	end
	return out
end

printh('# This file is generated - run p8scii.p8 to generate', filename, true, true)
printh('from typing import Final', filename, false, true)
printh('P8SCII: Final = [', filename, false, true)
for i = 0, 255 do
	printh('\tr"' .. escape_binary_str(chr(i)) .. '",  # ' .. i, filename, false, true)
end
printh(']', filename, false, true)
printh('assert len(P8SCII) == 256', filename, false, true)
printh('if __name__ == "__main__":', filename, false, true)
printh('\tfor idx, char in enumerate(P8SCII):', filename, false, true)
printh('\t\tprint(f"{idx:>3}: \\"{char}\\"")', filename, false, true)

print('saved ' .. filename .. '.p8l to desktop')
