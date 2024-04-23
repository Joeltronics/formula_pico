
spritesheet = nil
sprites = {}

-- TODO: more variables for named sprites, instead of hard-coding indexes everywhere

function load_graphics()
	spritesheet = fetch("gfx/0.gfx")

	sprites = {

		race_start_light = spritesheet[16].bmp,

		tire_tiny = spritesheet[17].bmp,
		tire_small = spritesheet[18].bmp,
		tire_large = spritesheet[19].bmp,

		tree_bg_1 = spritesheet[32].bmp,
		tree_bg_2 = spritesheet[33].bmp,
		city_bg_1 = spritesheet[34].bmp,
		city_bg_2 = spritesheet[35].bmp,
	}
end

bg_objects = {
	tree3={
		img={24, 8, 16},  -- sprite image
		pos={1.5, 0},  -- position rel to side of road
		siz={1.5, 3},  -- size
		spacing=3  -- spacing
	},
	tree4={
		img={24, 8, 16},  -- sprite image
		pos={1.5, 0},  -- position rel to side of road
		siz={1.5, 3},  -- size
		spacing=4  -- spacing
	},
	tree5={
		img={24, 8, 16},  -- sprite image
		pos={1.5, 0},  -- position rel to side of road
		siz={1.5, 3},  -- size
		spacing=5  -- spacing
	},
	tree7={
		img={24, 8, 16},  -- sprite image
		pos={1.5, 0},  -- position rel to side of road
		siz={1.5, 3},  -- size
		spacing=7  -- spacing
	},
	
	sign={
		img={25, 8, 16},
		pos={1, 0},
		siz={1, 2},
		spacing=1,
		flip_r=true  -- flip when on right hand side
	},

	finishline_lr = {
		img={27, 32, 8},
		pos={3.75, -5},
		siz={6.75, 1.25},
		spacing=1,
		palt=11,
	},
	finishline_c = {
		img={27, 32, 8},
		pos={0, -5},
		siz={6.75, 1.25},
		spacing=1,
		palt=11,
	},
	finishline_post = {
		img={28, 8, 24},
		pos={6.25, 0},
		siz={1.6875, 5},
		spacing=1,
		palt=11,
	},
}
