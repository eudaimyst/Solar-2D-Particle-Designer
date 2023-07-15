	-----------------------------------------------------------------------------------------
	--
	-- mouse_input.lua
	--
	-----------------------------------------------------------------------------------------

	--common modules - solar2d
	local physics = require("physics")

	--common modules
	local debug = require("lib.debug")

	-- Define module
	local M = { x = 0, y = 0, old = { x = 0, y = 0 }, delta = { x = 0, y = 0},
		pressed = false, clickListener = nil,
		scroll = false, scrollValue = 0 }

	M.moveDirection = nil --set by combination of movement keys pressed
	M.mouseOverObject = nil --stores object mouse is over
	M.clickedObject = nil --stores object that has been clicked

	local rayBackward
	local rayForward
	local queryHit

	local function checkCollisionPoint()
		queryHit = physics.queryRegion( M.x, M.y, M.x - 1, M.y - 1 )

		local function getParentTree(object)
			--searches objects for parent tree and stores them
			local searchObject = object --store a reference to the object we will search for parents
			local parents = {}
			local i = 1
			while (searchObject) do --iterate through objects parents to find all parents
				local parent = searchObject.parent --try to get the parent of the object
				if (parent) then --found parent,
					parents[i] = parent --store it for further iteration
					searchObject = parent --set the parent object to be the next to search for a parent
				else
					--print("no parent found")
					searchObject = nil --no parent is found, no need for further iterations
				end
				i = i + 1
			end
			--print("object "..i.." has "..#parents.." parents")

		    local indexes = {} --stores indexes of each child group within parent that contains child group(s) that contains object
			for i = #parents, 1, -1 do --for each parent in the heirarchy
				for j = 1, parents[i].numChildren do --for each child in the parent group
					local searchParent = parents[i] --readability
					--print ("searching parent "..i.." for child group / object")
					local child --init child var for setting below
					if (i > 1) then
						child = parents[i - 1] --set the child to the group higher in the heirarchy
					else --reached final parent
						child = object --set the child to the object we want to find
					end
					if searchParent[j] == child then
						--print("found object/child group at index "..j)
						indexes[i] = j
					end
				end
			end
			return parents, indexes
		end

		local function compareIndexes(objects) --takes a list of objects that have parents and index

			print ("comparing indexes between "..#objects.." objects")

			local highestIndexes = {}
			local highestObject
			local highestIndexPos = 0
			for i = 1, #objects do
				local object = objects[i] --readability
				for j = #object.indexes, 1, -1 do --check each objects indexes, starting from the highest index
					if (highestIndexes[j]) then --if there is already a highest index at this position
						if (j >= highestIndexPos) then --to not set objects with higher indexes in lower groups as the highest
							print("comparing "..object.indexes[j].." with "..highestIndexes[j])
							if (object.indexes[j] > highestIndexes[j]) then
								highestIndexes[j] = object.indexes[j]
								highestObject = object --set the highest object
								highestIndexPos = j --set the pos in heirarchy to the object with the highest index
								print("setting highest to "..object.indexes[j])
							elseif (highestIndexes[j] > object.indexes[j] ) then
								highestIndexPos = j
							end

						end
					else
						print("no value in highestIndexes at "..j.." setting initial to "..object.indexes[j])
						highestIndexes[j] = object.indexes[j] --set initial highest index values to compare
						highestObject = object
						highestIndexPos = j --set the pos in heirarchy to the object with the highest index
					end
				end
			end
			for k, v in pairs(highestObject.indexes) do
				print("highest object indexes:", k, v)
			end
			return highestObject
		end

		if (queryHit) then
			for k, v in ipairs( queryHit ) do
				print("queryhit kv: ", k, v)
			end
			if (#queryHit == 1) then --mouse is over only one object
				print("mouse is over one object")
				return queryHit[1]
			elseif (#queryHit > 1) then --mouse is over more than one object
				local objects = { }
				for i = 1, #queryHit do
					local object = { }
					object.rect = queryHit[i]
					object.parents, object.indexes = getParentTree(object.rect)
					objects[i] = object

					print("object "..i.." has "..#object.parents.." parents")
					for j = #object.parents, 1, -1 do
						print("parent "..j.." has child at index "..object.indexes[j])
					end
				end
				return compareIndexes(objects).rect --returns highest object in heirarchy
			end
		end
		print("mouse is not over an object")
		return nil
	end

	local function checkCollisionRay() --for this to work, collision object needs a variable of clickListener defined that points to a function to call

		rayBackward = physics.rayCast( M.x, M.y, M.old.x, M.old.y, "any" ) --go from new pos to old pos to know when left collision
		if (rayBackward) then
			--print("mouse left something")
			if (M.mouseOverObject) then
				M.mouseOverObject = nil
			end --clear click listener
		end

		rayForward = physics.rayCast( M.old.x, M.old.y, M.x, M.y, "any" ) --go from old pos to new pos to know when entered collision
		if (rayForward) then
			--print("mouse entered something")
			if (rayForward[1].object.clickListener) then --a clickListener has been passed through collision object
				M.mouseOverObject = rayForward[1].object --store object to be called on click
			end
		end
	end


	local function mouseScrollComplete(  ) --called by timer after mouse scroll to reset value to 0
		M.scroll = false
		M.scrollValue = 0
	end

	-- Called when a mouse event has been received.
	local function onMouseEvent( event )

		----movement
		M.x, M.y = event.x, event.y --set position based on event data
		checkCollisionRay()

		----scrolling
	    if event.type == "scroll" then

	        if (event.scrollY ~= 0) then
				M.scroll = true
				M.scrollValue = event.scrollY
	            print( "Mouse is scrolling with a value of "..event.scrollY)

				timer.performWithDelay( 0, mouseScrollComplete )
	        end
	    end

	    ----clicks
	    if event.type == "down" then
			----left click
			if (event.isPrimaryButtonDown) then --mouse clicked
				--print("mouse pressed")
				if (M.pressed == false) then --only if mouse not held down
					M.pressed = true --set to true so don't register mouse being held down
					print("mouse clicked at pos: "..event.x..", "..event.y)
					local loseFocusObject = nil
					if (M.clickedObject) then --an object has been clicked previously
						if (M.clickedObject.lostFocusListener) then --prev clicked object has a lost focus listener
							loseFocusObject = M.clickedObject --store reference to the object
						end
					end
					local object = checkCollisionPoint()
					if (object) then
						M.clickedObject = object
						if (object.clickListener) then
							local function clickTimer() --create timer so click happens on frame after lost focus listener is called so windows can update
								object.clickListener()
							end
							timer.performWithDelay( 0, clickTimer )
						end
						print("found object under mouse")
					else
						M.clickedObject = nil
					end
					if (loseFocusObject) then
						loseFocusObject.lostFocusListener() --call the listener of the object thats losing focus
					end
					--[[ comment out using ray tracing to determine clicked object
					if (M.mouseOverObject) then
						--print("something clicked")
						M.clickedObject = M.mouseOverObject --store clicked object so we can call lost focus method on next click
						M.mouseOverObject.clickListener() --call the objects click listener
					else --mouse is not over an object
						M.clickedObject = nil
					end
					]]
				end
			end
	    end
		if event.type == "up" then
			--print("mouse released")
			M.pressed = false --so can check for next click
			M.delta.x, M.delta.y = 0, 0
		end
	end

	local function onFrame()


		M.delta.x, M.delta.y = M.x - M.old.x, M.y - M.old.y --set delta
		M.old.x, M.old.y = M.x, M.y --use mouse position on previous frame for raytrace coords

		--debug mouse values
		debug.updateText("mousePos", math.floor(M.x)..", "..math.floor(M.y))
		debug.updateText("mouseDelta", math.round(M.delta.x)..", "..math.round(M.delta.y))


	end

	function M.init()

		Runtime:addEventListener( "enterFrame", onFrame )
		Runtime:addEventListener( "mouse", onMouseEvent )

	end

	return M