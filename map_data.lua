

bg_tree3={
	img={0, 32, 8, 16},  -- sprite image
	pos={1.5, 0},  -- position rel to side of road
	siz={1.5, 3},  -- size
	spacing=3  -- spacing
}
bg_tree4={
	img={0, 32, 8, 16},  -- sprite image
	pos={1.5, 0},  -- position rel to side of road
	siz={1.5, 3},  -- size
	spacing=4  -- spacing
}
bg_tree5={
	img={0, 32, 8, 16},  -- sprite image
	pos={1.5, 0},  -- position rel to side of road
	siz={1.5, 3},  -- size
	spacing=5  -- spacing
}
bg_tree7={
	img={0, 32, 8, 16},  -- sprite image
	pos={1.5, 0},  -- position rel to side of road
	siz={1.5, 3},  -- size
	spacing=7  -- spacing
}

bg_sign={
	img={16, 32, 8, 16},
	pos={1, 0},
	siz={1, 2},
	spacing=1,
	flip_r=true  -- flip when on right hand side
}

-- TODO: use bgc
bg_finishline = {
	img={96, 32, 32, 32},
	-- pos={1.5, 0},
	pos={0, 0},
	-- siz={10, 5},
	siz={6.8, 5},
	-- spacing=0,
	spacing=1,
	palt=11,
	flip_r=true
}
-- bg_finishline_c = {
-- 	img={96, 32, 32, 8},
-- 	pos={0, -48},
-- 	siz={10, 1},
-- 	spacing=0,
-- 	palt=11,
-- }


-- TODO: max speed per segment (including info how to ramp up & down)
-- TODO: define height and calculate pitch, like how "tu" is calculated from angle
-- TOOD: define racing line
tracks = {
{
	name="belgium",
	minimap_scale = 0.25,
	minimap_x = 12,
	minimap_y = 16,
	{length=8}, -- start/finish; heading 0.25
	{length=20},
	{length=8, angle=0.375}, -- 1: la source; heading 0.625
	{length=16, pitch=-0.5},
	{length=16, angle=0.075}, -- 2; heading 0.7
	{length=16, pitch=-0.25},
	{length=4, angle=-0.15}, -- , gndcol=12}, -- 3: eau rouge; heading 0.55
	{length=16, angle=0.3, pitch=2}, -- 4: raidillon; heading 0.85
	{length=16, angle=-0.15}, -- 5; heading 0.7
	{length=16, pitch=1, bgl=bg_tree7},
	{length=16, angle=0.05, pitch=0.5, bgl=bg_tree4, bgr=bg_tree7}, -- 6; heading 0.75
	{length=48, bgl=bg_tree3, pitch=0.5, bgr=bg_tree4}, -- kemmel straight
	{length=8, angle=0.25}, -- 7; high point
	{length=4},
	{length=8, angle=-0.25}, -- 8
	{length=8, pitch=-0.25},
	{length=8, angle=0.25, pitch=-0.25}, -- 9
	{length=32, pitch=-0.75},
	{length=24, angle=0.5, pitch=-0.25}, -- 10
	{length=8, pitch=-0.5},
	{length=8, angle=-0.25, pitch=-0.5}, -- 11
	{length=40, pitch=-0.75},
	{length=12, angle=-0.2, pitch=-0.5}, -- 12: pouhon
	{length=18, angle=-0.175, pitch=-0.5},
	{length=24, pitch=-0.75},
	{length=16, angle=0.25, pitch=-0.25}, -- 13
	{length=4},
	{length=16, angle=-0.25}, -- 14
	{length=8},
	{length=12, angle=0.25}, -- 15
	{length=8, pitch=-0.25},
	{length=6, angle=0.125}, -- 16; low point
	{length=18, angle=0.125, pitch=0.5},
	{length=12, pitch=0.25},
	{length=20, angle=0.125, pitch=0.25},
	{length=28, pitch=0.25},
	{length=6, angle=-0.125, pitch=0.25}, -- 17
	{length=24, pitch=0.25},
	{length=6, angle=-0.125, pitch=0.25}, -- 18
	{length=24, pitch=1},

	{length=6, angle=0.25}, -- 19: chicane
	{length=6, angle=-0.25}, -- 20
	{length=14},
},
{
	name="italy",
	minimap_scale = 0.25,
	minimap_x = 24,
	minimap_y = 0,
	{length=8}, -- start/finish
	{length=32},
	{length=6, angle=0.25}, -- 1: chicane
	{length=8, angle=-0.375}, -- 2
	{length=8, angle=0.125},
	{length=8},
	{length=64, angle=0.2}, -- 3: curva grande
	{length=12},
	{length=6, angle=-0.25}, -- 4: chicane
	{length=6, angle=0.25}, -- 5
	{length=12},
	{length=12, angle=0.25}, -- 6: lesmo
	{length=12},
	{length=12, angle=0.2}, -- 7
	{length=12},
	{length=12, angle=-0.05}, -- serraglio
	{length=40},
	{length=8, angle=-0.15}, -- 8 :ascari
	{length=8, angle=0.2}, -- 9
	{length=8, angle=-0.15}, -- 10
	{length=72},
	{length=10, angle=0.25}, -- 11: parabolica
	{length=10, angle=0.125},
	{length=30, angle=0.125},
	{length=12},
},
{
	name="test",
	minimap_scale = 0.5,
	minimap_x = 24, -- distance from right side of screen
	minimap_y = 0, -- distance from vertical center
	{length=8}, -- start/finish
	{length=12},
	{length=12, angle=-0.25, bgr=bg_sign},
	{length=12, pitch=-.75, bgl=bg_tree3},
	{length=8, angle=0.125, bgl=bg_sign},
	{length=20, angle=0.125, pitch=.75, tnl=true},
	{length=8, pitch=-.5, tnl=true},
	{length=10, angle=0.25, tnl=true},
	{length=8},
	{length=62, angle=0.25, bgl=bg_tree3, bgr=bg_tree5},

	{length=6, angle=0.25, bgl=bg_sign},
	{length=8, angle=-0.25, bgr=bg_sign},

	{length=40, bgl=bg_tree4, bgr=bg_tree5},

	{length=6, angle=0.5, bgl=bg_sign},

	{length=8},

	{length=8, angle=-0.125},
	{length=8, angle=0.125},
},
{
	name="hill test",
	minimap_scale = 0.5,
	minimap_x = 12,
	minimap_y = -20,
	{length=8}, -- start/finish
	{length=12},
	{length=20, gndcol=8},
	{length=20, pitch=1, gndcol=8},
	{length=20, pitch=1, gndcol=8},
	-- {length=20, pitch=1, gndcol=8},
	{length=20},
	{length=12, angle=0.5},
	{length=20},
	{length=20, gndcol=1},
	{length=20, pitch=-1, gndcol=1},
	{length=20, pitch=-1, gndcol=1},
	-- {length=20, pitch=-1, gndcol=1},
	{length=20},
	{length=12, angle=0.5},
}
}
