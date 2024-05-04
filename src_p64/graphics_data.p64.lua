
spritesheet = nil
sprites = {}
bg_objects = {}

-- TODO: more variables for named sprites, instead of hard-coding indexes everywhere

function load_graphics()
	spritesheet = fetch("gfx/0.gfx")

	-- I would think you could get the sprite width & height from the sprite object, but it seems not?
	sprites = {
		car_small = {
			{bmp=spritesheet[8].bmp, width=24, height=16},
			{bmp=spritesheet[9].bmp, width=24, height=16},
			{bmp=spritesheet[10].bmp, width=24, height=16},
			{bmp=spritesheet[11].bmp, width=24, height=16},
		},
		car = {
			{bmp=spritesheet[12].bmp, width=48, height=32},
			{bmp=spritesheet[13].bmp, width=48, height=32},
			{bmp=spritesheet[14].bmp, width=48, height=32},
			{bmp=spritesheet[15].bmp, width=48, height=32},
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

		forest = {bmp=spritesheet[39].bmp, width=32, height=16},

		finishline_top = {bmp=spritesheet[27].bmp, width=32, height=8, palt=11},
		finishline_post = {bmp=spritesheet[28].bmp, width=8, height=24, palt=11},

		stands_small = {bmp=spritesheet[29].bmp, width=48, height=16, palt=15},
		stands = {bmp=spritesheet[30].bmp, width=48, height=32, palt=15},
		garage = {bmp=spritesheet[31].bmp, width=32, height=32, palt=15},

		ferris = {bmp=spritesheet[36].bmp, width=48, height=48, palt=11},
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

		forest={
			-- TODO: make a way to cycle different sprites
			sprite=sprites.forest,
			pos={1, 0},
			siz={12, 6},
			spacing=3,
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
		},
		finishline_c = {
			sprite=sprites.finishline_top,
			pos={0, -5},
			siz={6.75, 1.25},
			spacing=1,
		},
		finishline_post = {
			sprite=sprites.finishline_post,
			pos={6.25, 0},
			siz={1.6875, 5},
			spacing=1,
		},

		stands = {
			sprite=sprites.stands,	
			pos={0, 0},
			siz={12, 8},
			spacing=4,
			flip_r=true,
		},

		stands_single = {
			sprite=sprites.stands,	
			pos={0, 0},
			siz={12, 8},
			spacing=0,
			flip_r=true,
		},

		stands_small = {
			sprite=sprites.stands_small,
			pos={0, 0},
			siz={12, 4},
			spacing=4,
			flip_r=true,
		},

		stands_small_single = {
			sprite=sprites.stands_small,
			pos={0, 0},
			siz={12, 6},
			spacing=0,
			flip_r=true,
		},

		garages = {
			sprite=sprites.garage,	
			pos={0, 0},
			siz={8, 8},
			spacing=3,
			flip_r=true,
		},

		ferris = {
			sprite=sprites.ferris,
			pos={32, 0},
			siz={32, 32},
			spacing=0,
			flip_r=true,
		},
		
		building = {
			building=true,
			pos={8, 16},
			spacing=1,
		},

	}

end
