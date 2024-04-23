
spritesheet = nil
sprites = {}
bg_objects = {}

-- TODO: more variables for named sprites, instead of hard-coding indexes everywhere

function load_graphics()
	spritesheet = fetch("gfx/0.gfx")


	-- I would think you could get the sprite width & height from the sprite object, but it seems not?
	-- TODO: add palt() info in here
	sprites = {
		car = {
			{bmp=spritesheet[8].bmp, width=24, height=16},
			{bmp=spritesheet[9].bmp, width=24, height=16},
			{bmp=spritesheet[10].bmp, width=24, height=16},
			{bmp=spritesheet[11].bmp, width=24, height=16},
		},

		race_start_light = {bmp=spritesheet[16].bmp, width=16, height=16},

		tire_tiny = {bmp=spritesheet[17].bmp, width=8, height=8},
		tire_small = {bmp=spritesheet[18].bmp, width=8, height=8},
		-- tire_large = {bmp=spritesheet[19].bmp, width=16, height=16},
		tire_large = {bmp=spritesheet[20].bmp, width=32, height=32},

		tree_bg_1 = {bmp=spritesheet[32].bmp, width=8, height=8},
		tree_bg_2 = {bmp=spritesheet[33].bmp, width=8, height=8},
		city_bg_1 = {bmp=spritesheet[34].bmp, width=8, height=8},
		city_bg_2 = {bmp=spritesheet[35].bmp, width=8, height=8},

		tree = {bmp=spritesheet[24].bmp, width=8, height=16},
		sign = {bmp=spritesheet[25].bmp, width=8, height=16},

		finishline_top = {bmp=spritesheet[27].bmp, width=32, height=8},
		finishline_post = {bmp=spritesheet[28].bmp, width=8, height=24},
	}

	bg_objects = {
		tree3={
			sprite=sprites.tree,  -- sprite image
			pos={1.5, 0},  -- position rel to side of road
			siz={1.5, 3},  -- size
			spacing=3  -- spacing
		},
		tree4={
			sprite=sprites.tree,
			pos={1.5, 0},
			siz={1.5, 3},
			spacing=4
		},
		tree5={
			sprite=sprites.tree,
			pos={1.5, 0},
			siz={1.5, 3},
			spacing=5
		},
		tree7={
			sprite=sprites.tree,
			pos={1.5, 0},
			siz={1.5, 3},
			spacing=7
		},
		
		sign={
			sprite=sprites.sign,
			pos={1, 0},
			siz={1, 2},
			spacing=1,
			flip_r=true  -- flip when on right hand side
		},

		finishline_lr = {
			sprite=sprites.finishline_top,
			pos={3.75, -5},
			siz={6.75, 1.25},
			spacing=1,
			palt=11,
		},
		finishline_c = {
			sprite=sprites.finishline_top,
			pos={0, -5},
			siz={6.75, 1.25},
			spacing=1,
			palt=11,
		},
		finishline_post = {
			sprite=sprites.finishline_post,
			pos={6.25, 0},
			siz={1.6875, 5},
			spacing=1,
			palt=11,
		},
	}

end
