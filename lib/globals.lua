	-----------------------------------------------------------------------------------------
	--
	-- globals.lua
	--
	-----------------------------------------------------------------------------------------

	-- Define module
	local M = {}

	--x and y and facing in degrees values for moving entities 
	M.move = {
		up = {x = 0, y = -1, facing = 270},
		upRight = {x = .666, y = -.666, facing = 315},
		right = {x = 1, y = 0, facing = 0},
		downRight = {x = .666,y = .666, facing = 45},
		down = {x = 0,y = 1, facing = 90},
		downLeft = {x = -.666,y = .666, facing = 135},
		left = {x = -1,y = 0, facing = 180},
		upLeft = {x = -.666,y = -.666, facing = 225}
	}

	--strings used when leading images, part of filenames
	M.imageUp = "back"
	M.imageUpRight = "backright"
	M.imageUpLeft = "backleft"
	M.imageDown = "front"
	M.imageDownRight = "frontright"
	M.imageDownLeft = "frontleft"
	M.imageRight = "right"
	M.imageLeft = "left"

	--xpamounts needed for leveling up
	M.xpAmount = {}
	M.xpAmount[0] = 100
	M.xpAmount[1] = 250
	M.xpAmount[2] = 425
	M.xpAmount[3] = 800
	M.xpAmount[4] = 1050
	M.xpAmount[5] = 1350
	M.xpAmount[6] = 1800
	M.xpAmount[7] = 2300
	M.xpAmount[8] = 2800 

	--always return module
	return M