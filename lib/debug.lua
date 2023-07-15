	-----------------------------------------------------------------------------------------
	--
	-- debug.lua
	--
	-----------------------------------------------------------------------------------------
	
	--common modules - solar2d
	local composer = require("composer")
	local physics = require("physics")
	local easing = require("lib.easing")
	
	--common modules
	local g = require("lib.globals")
	local util = require("lib.utilities")
	local ui, cam, char, enemies, items, map, spells = {}, {}, {}, {}, {}, {}, {}

	-- Define module
	local M = {}

	function M.setModules()
		--print("!!!!!!!!setting modules for map!!!!!")
		ui, cam, char, enemies, items, map, spells = M.ui, M.cam, M.char, M.enemies, M.items, M.map, M.spells 
	end

	local debugGroup = {} --stores display group

	local debugEnabled = false --whether or not to show debugUI

	M.lineStore = {} --stores all debug lines to be drawn per frame
	M.lineStoreCounter = 0
	local lineTimer = 0

	M.debugTextStore = {} --stores all debug texts so they can be updated
	M.debugTextStoreCounter = 0

	M.regTextStore = nil --stores references to variables that are updated to debugText on update
	M.regTextStoreCounter = 0

	M.drawLine = function ( x1, y1, x2, y2, r, g, b, a, w, timerLength )
		
		if (debugEnabled) then --don't add any lines to store if debug is off
			--set defaults, need positions but rest is white or width of 1
			local r = r or 1
			local g = g or 1
			local b = b or 1
			local a = a or 1
			local w = w or 1
			local timerLength = timerLength or 0
			--create an object that holds line properties
			local debugLine = 	{ x1 = x1, y1 = y1, x2 = x2, y2 = y2, r = r, g = g, b = b, a = a, w = w, --position, colour and width
									timerLength = timerLength, timer = 0, displayLine = nil } --timer variables
			
			debugLine.id = M.lineStoreCounter --set an id for debugLine so can remove from store
			M.lineStore[M.lineStoreCounter] = debugLine --store line for future reference
			
			M.lineStoreCounter = M.lineStoreCounter + 1 --increase counter for next line
		end

		return true
	end

	local function updateLines() --called from onFrame if debug enabled

		lineTimer = lineTimer + util.frameDeltaTime --increase local timer

		for k, debugLine in pairs ( M.lineStore ) do --for each line in store
			--print(k, debugLine)

			if ( debugLine.displayLine ) then --check if line has been drawn
				debugLine.timer = debugLine.timer + util.frameDeltaTime --increase lines 
				if (cam ~= {}) then
					debugLine.displayLine.x = debugLine.displayLine.x - cam.moveDelta.x
					debugLine.displayLine.y = debugLine.displayLine.y - cam.moveDelta.y
				end

				if ( debugLine.timer  > debugLine.timerLength ) then --if timer has been passed
					debugLine.displayLine:removeSelf( )
					debugLine.displayLine = nil
					M.lineStore[debugLine.id] = nil
				end

			else
				--drawLines
				debugLine.displayLine = display.newLine( debugGroup, debugLine.x1, debugLine.y1, debugLine.x2, debugLine.y2 )
				debugLine.displayLine:setStrokeColor( debugLine.r, debugLine.g, debugLine.b )
				debugLine.displayLine.alpha = debugLine.a
				debugLine.displayLine.strokeWidth = debugLine.w
			end
		end
	end

	local function createDebugText( label, value, posX, posY, width, height)
		
		--set defaults if not passed
		width = width or 100
		height = height or 50
		posX = posX or display.contentWidth - width - 20
		posY = posY or display.contentHeight - height - 20 - ((height + 20) * M.debugTextStoreCounter)
		label = label or "debug"..tostring(M.debugTextStoreCounter)
		value = value or "value"

		local debugText = { labelRect = nil, valueRect = nil, bg = nil, group = nil}

		function debugText:updateValue(newValue)
			--print("newValue: "..newValue)
			self.value = newValue
			self.valueRect.text = tostring(newValue)
		end

		function debugText:updateLabel(newLabel)
			--print("newLabel: "..newLabel)
			self.label = label
			self.labelRect.text = tostring(newLabel)
		end

		debugText.group = display.newGroup()
		debugText.group.x, debugText.group.y = posX, posY
		debugGroup:insert(debugText.group)
		print(debugGroup.numChildren.." debug group children make")
		
		debugText.bg = display.newRect( debugText.group, 0, 0, width, height )
		debugText.bg.anchorX, debugText.bg.anchorY = 0, 0
		debugText.bg:setFillColor( 0 )
		debugText.bg.alpha = 0.2

							--display.newText( [parent,] text, x, y [, width, height], font [, fontSize] )
		debugText.labelRect = display.newText( debugText.group, label, 0, 0, native.systemFont, 16 )
		debugText.labelRect.anchorX, debugText.labelRect.anchorY = 0, 0
		debugText.labelRect.x = 5
		
		debugText.valueRect = display.newText( debugText.group, value, 0, 0, native.systemFont, 16 )
		debugText.valueRect.anchorX, debugText.valueRect.anchorY = 0, 0
		debugText.valueRect.x = 5
		debugText.valueRect.y = debugText.labelRect.contentHeight

		M.debugTextStore[M.debugTextStoreCounter] = debugText
		debugText.id = M.debugTextStoreCounter --set an ID so can remove from store

		M.debugTextStoreCounter = M.debugTextStoreCounter + 1

		return debugText
	end

	M.fpsDisplay = {}

	function M.createFps()
		M.fpsDisplay = createDebugText( "fps", "init", 0, 600, width, height )
	end
	function M.updateFps(fps)
		if (M.fpsDisplay) then
			M.fpsDisplay:updateValue(fps)
		end
	end

	function M.updateText( newLabel, newValue )

		--print("update debug text: ", newLabel, newValue)
		local i = 0

		local function createRegister()
			--print("making new register")
			local register = { label = newLabel, value = newValue } --make new register
			if (M.regTextStore == nil) then M.regTextStore = {} end
			M.regTextStore[M.regTextStoreCounter] = register --add register in store


			M.regTextStoreCounter = M.regTextStoreCounter + 1 --increase counter for store
		end
		--print(M.regTextStore)

		if (M.regTextStore) then --store has registers in it
			local foundReg = false --whether regText is found in loop
			for k, register in pairs(M.regTextStore) do --check for registers that already exist
				if (register.label == newLabel) then --register exists for this label
					--print("register exists for this label, not making")
					foundReg = true
					register.value = newValue --update registers value to new value
				end
			end
			if (not foundReg) then --if no registers are found
				createRegister()
			end
		else
			--print("no registers at all")
			createRegister() --create first register
		end
	end

	local function updateRegText()

		while (M.regTextStoreCounter > M.debugTextStoreCounter) do --there is debugText object that can display text
			createDebugText() --make new debugText to hold object
		end
		local i = 0
		for k, register in pairs(M.regTextStore) do --for each registered text
			--print("registers: "..register)
			if (register.label ~= M.debugTextStore[i].labelRect.text) then
				M.debugTextStore[i]:updateLabel(register.label)
			end
			if (register.value ~= M.debugTextStore[i].valueRect.text) then
				M.debugTextStore[i]:updateValue(register.value)
			end
			i = i + 1
		end
	end


	function M.onFrame() --called every frame from onFrame event from scene

		if (debugEnabled) then 
			updateRegText()
			updateLines()
		end
	end

	function M.showUI() --called from toggleUI
		for i = 0, 0 do
			createDebugText()
		end
	end

	function M.hideUI() --called from toggleUI
		print(debugGroup.numChildren.." debug group children remove")

		for k, debugLine in pairs(M.lineStore) do
			display.remove(debugLine.displayLine)
			debugLine.displayLine = nil
			M.lineStore[debugLine.id] = nil
		end

		for k, debugText in pairs(M.debugTextStore) do
			display.remove(debugText.group)
			debugText.group = nil
			M.debugTextStore[debugText.id] = nil
		end

		M.lineStore = {} --stores all debug lines to be drawn per frame
		M.lineStoreCounter = 0

		M.debugTextStore = {}
		M.debugTextStoreCounter = 0
	end

	function M.toggleUI() --called from keyinput
		if (debugEnabled) then 
			debugEnabled = false
			M.hideUI()
		else
			debugEnabled = true
			M.showUI()
		end
	end

	function M.createGroup() --called once from scene

		print("debugGroup made")
		debugGroup = display.newGroup( )
		return debugGroup

	end

	return M