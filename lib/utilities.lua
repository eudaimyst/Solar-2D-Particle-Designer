	-----------------------------------------------------------------------------------------
	--
	-- utilities.lua
	--
	-----------------------------------------------------------------------------------------\
	
	--common modules - solar2d
	local composer = require("composer")
	local physics = require("physics")
	local easing = require("lib.easing")
	
	--common modules
	local g = require("lib.globals")

	--shared modules --all can call each other

	-- Define module
	local M = {}

	M.frameDeltaTime = 0

	function M.removeObject ( o ) --called by transitions to remove object on complete
		if (o) then --if object still exists
		    o:removeSelf()
		end
	end

	function M.zeroAnchors(rect) --takes a display object and sets anchors to 0
		rect.anchorX = 0
		rect.anchorY = 0
		return rect
	end

	function M.printkv(table)
		if (table) then
			for k, v in pairs(table) do
				print(tostring(table), k, v)
			end
		else
			print("attempting to printkv but no table")
		end
	end

	function M.angleToDirection(a)
		for k,v in pairs( g.move ) do
			--print(k, v)
			--print("is "..a.." between "..v.facing - 22.5 .." and "..v.facing + 22.5)
			if (a >= v.facing - 22.5 and a < v.facing) then
				--print("true")
				return v
			elseif (a >= v.facing and a < v.facing + 22.5) then
				--print("true")
				return v
			elseif (v.facing == 0 and a >= 337.5) then --special case for right which is 0 OR 360
				--print("true")
				return v
			end
		end
	end
	--[[
	function M.worldtoscreen (x, y, cam)
		return x - cam.coords.x1, y - cam.coords.y1
	end
	--]]


	function M.getDistance(pos1x, pos1y, pos2x, pos2y)
		return math.sqrt( math.pow(pos1x - pos2x, 2) + math.pow( pos1y - pos2y, 2 ) )
	end

	--loads images from file, passes character/data table as entity and animation type ie walk, cast etc...
	function M.loadImages(entity, animType)
		--create tables for each direction that will hold images
		animType.images.up = { }
		animType.images.upRight = { }
		animType.images.upLeft = { }
		animType.images.down = { }
		animType.images.downRight = { }
		animType.images.downLeft = { }
		animType.images.right = { }
		animType.images.left = { }

		--loads each image, iterates for frame number
		for i = 0, animType.frameCount - 1, 1 do
			print("image loaded: ".."content/"..entity.imageFolder..animType.prefix..g.imageUp..i..".png")
			animType.images.up[i] =  "content/"..entity.imageFolder..animType.prefix..g.imageUp..i..".png"
			animType.images.upRight[i] =  "content/"..entity.imageFolder..animType.prefix..g.imageUpRight..i..".png"
			animType.images.upLeft[i] =  "content/"..entity.imageFolder..animType.prefix..g.imageUpLeft..i..".png"
			animType.images.down[i] =  "content/"..entity.imageFolder..animType.prefix..g.imageDown..i..".png"
			animType.images.downRight[i] =  "content/"..entity.imageFolder..animType.prefix..g.imageDownRight..i..".png"
			animType.images.downLeft[i] =  "content/"..entity.imageFolder..animType.prefix..g.imageDownLeft..i..".png"
			animType.images.right[i] =  "content/"..entity.imageFolder..animType.prefix..g.imageRight..i..".png"
			animType.images.left[i] =  "content/"..entity.imageFolder..animType.prefix..g.imageLeft..i..".png"
		end
	end

	function M.normalizeXY(x, y) --takes x y and returns x y normalised so highest value on either side is 1 and other value is relative to 1
		local magnitude = math.sqrt(math.pow(x, 2) + math.pow( y, 2 ))
		return x / magnitude, y / magnitude
	end

	function M.moveSetDirection(e, d)
		e.moveDirection = d --set entities direction to passed direction
		e.facingDirection = d.facing --set entity facing direction in degrees to passed direction
	end

	--https://copyprogramming.com/howto/how-to-get-an-actual-copy-of-a-table-in-lua#how-to-get-an-actual-copy-of-a-table-in-lua
	--deepcopy function to copy enemydata to a new variable
	function M.deepcopy(orig)
	    local orig_type = type(orig)
	    local copy
	    if orig_type == 'table' then
	        copy = {}
	        for orig_key, orig_value in next, orig, nil do
	            copy[M.deepcopy(orig_key)] = M.deepcopy(orig_value)
	        end
	        setmetatable(copy, M.deepcopy(getmetatable(orig)))
	    else -- number, string, boolean, etc
	        copy = orig
	    end
	    return copy
	end

	--function to remove objects from an array (numbered table) based on another table of indexes to remove
	function M.arrayRemove(table, remove)
		local j = 0 --iterator for when have removed an object
		local l = #table --for testing
		for i = 0, #table, 1 do --iterate through passed table with i for index
			if (i == remove[j]) then --index are at matches index to remove
				j = j + 1 --removed an object so increase iterator to find next index
			end
			print("setting value in table at position "..i.."to value at i+j"..i+j)
			table[i] = table[i+j] --depending on how many indexes in table match remove array, move items in table to left 
			if (i > #table - j) then --nil last items of array depending on how many were iterated
				table[i] = nil
			end
		end
		print("removed "..j.." tiles from table... before: "..l.." after: "..#table)

	end

	return M