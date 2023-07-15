	-----------------------------------------------------------------------------------------
	--
	-- editor.lua
	--
	-----------------------------------------------------------------------------------------\

	--common modules - solar2d
	local physics = require("physics")
	local easing = require("lib.easing")

	--common modules
	local g = require("lib.globals")
	--local debug = require("lib.debug")
	local util = require("lib.utilities")
	local mouse = require("lib.mouse_input")
	local key = require("lib.key_input")

	-- Define module
	local M = {}

	M.elementTypes = { --elemnts are objects that get put in window sections, ie buttons, input boxes, seperators
		button = {}, --performs a function on press
		toggleButtons = {}, --a group of buttons, when one is selected, others are deselcted
		propertyText = {}, --displays a variable
		inputField = {}, --user directly types value
		dropdown = {}, --options drop down to be selected
		colourPicker = {}, --selects a color
		objectList = {}, -- displays a list of objects to be selected
		multiLineText = {} --displays a multiline native text object for copy and pasting
	}

	M.windowStore = {} --windows are added here when created to be iterated on frame

	local function createCollision( rect, colGroup ) --creates collision object added to collision group for physics
		--print("dropdown rect bg collision: "..tostring(rect))
		util.zeroAnchors(rect)
		local bounds = rect.contentBounds
		local collisionRect = display.newRect( colGroup, bounds.xMin, bounds.yMin, rect.width, rect.height ) --minus the xy by half size as anchors not zeroed when functon called
		collisionRect:setFillColor( 1, 0, 0, .2 )
		util.zeroAnchors(collisionRect) --zero anchors before adding physics body
		physics.addBody( collisionRect, "static" )
		return collisionRect
	end

	local function createElement( elementData, section, window, row, rowPos ) --called by section to create elements

		local element = {}
		element.id = #section.elementStore + 1 --store where the element is in the store
		element.group = display.newGroup()
		section.group:insert(element.group)
		element.data = elementData

		local titleHeight = 20
		local xSpacing = 5 --spacing between elements

		function element:setGroupPos()
			local xOffset = 0
			if (rowPos > 1) then
				local prevElement = section.elementStore[self.id - 1]
				xOffset = prevElement.group.x + prevElement.group.contentWidth
			end
			self.group.x, self.group.y = section.group.x + xOffset + xSpacing, section.title.height + titleHeight * row
		end

		element:setGroupPos()
		local labelOffsetX, labelOffsetY = 0, 2
		if (element.data.label) then
			element.label = display.newText( element.group, element.data.label, labelOffsetX, labelOffsetY, system.defaultFont, titleHeight / 1.4 )
		end

		function element:drawInputField()
			local textFieldWidth = element.data.width or 30
			local textBGInset = 2
			local textInputInset = 1
			local inputField = {}
			inputField.element = self
			element.inputField = inputField

			inputField.preInputString = ""--stores input field string before input to cancel

			function inputField:valueChangeUpdate()
				self:updateText()
			end

			function inputField:inputSent(keyString)
				self.inputText.text = self.inputText.text..keyString
				self:updateIndicator()
			end

			function inputField:inputComplete()
				if element.data.inputType == "text" then
					element.data.inputListener(element.data.param, self.inputText.text)
				else
					element.data.inputListener(element.data.param, tonumber(self.inputText.text))
				end
				self.inputIndicator.isVisible = false --cant use lostFocusListener as it calls this function when clicking away from field
				transition.cancel( self.inputIndicator )
				key.deregisterInputField()
			end

			function inputField:inputCancel()
				self.inputText.text = inputField.preInputString
				self:updateIndicator()
				self.cRect.lostFocusListener()
			end

			function inputField:inputDelete()
				self.inputText.text = string.sub( self.inputText.text, 1, string.len(self.inputText.text) - 1 )
				self:updateIndicator()
			end

			function inputField:collision()

				local function activateInputField()
					--print("input field pressed")
					inputField.preInputString = self.inputText.text
					self.inputIndicator.isVisible = true
					transition.to( self.inputIndicator, { alpha = 0, time = 2000, transition = easing.myFlash, iterations = -1 } )
					key.registerInputField(self)
				end

				local function deactivateInputField()
					--print("input field pressed")
					inputField:inputComplete()
					self.inputIndicator.isVisible = false
					transition.cancel( self.inputIndicator )
					key.deregisterInputField()
				end

				self.cRect = createCollision( self.rect, section.colGroup ) --creates collision for title object
				self.cRect.ref = element --set a reference to window that scene can access on col
				self.cRect.clickListener = activateInputField -- function to call from scene mouse event
				self.cRect.lostFocusListener = deactivateInputField
			end

			function inputField:updateText() --called from valueChangeUpdate and inputField:draw
				local string = tostring(window.object.params[element.data.param])
				self.inputText.text = string
			end

			function inputField:updateIndicator()
				self.inputIndicator.x = self.inputText.x + self.inputText.width
			end

			function inputField:draw()

				self.rect = display.newRect( element.group, element.label.contentWidth + xSpacing, textBGInset , textFieldWidth, titleHeight - textBGInset * 2 )
				self.rect:setFillColor( .075 )
				self.rect.stroke = { .5, .5, .5 }
				self.rect.strokeWidth = 1
				local textOptions = { parent = element.group, text = "", x = self.rect.x + textInputInset, y = self.rect.y + textInputInset,
					 height = self.rect.height - textInputInset*2, font = system.defaultFont, fontSize = titleHeight / 1.7 }
				self.inputText = display.newText( textOptions )
				self:updateText()
				self.inputIndicator = display.newRect( element.group, self.inputText.x + self.inputText.width, textBGInset * 2, 1 , titleHeight - textBGInset * 4 )
				self.inputIndicator.isVisible = false
				self:updateIndicator()
			end

			inputField:draw()
			inputField:collision()
		end

		function element:drawButton(pos) --if button is part of a group for toggling, takes a pos param
			local buttonWidth = 60

			local button = {}
			if (pos) then button.id = pos end

			function button:collision()

				local function buttonPressed()
					--print("buttonPressed")
					if (element.buttonGroup) then --if button is in a group
						for j = 1, #element.buttonGroup do --for each element in the group
							if (j == self.id) then
								self.value = true --update pressed values
							else
								element.buttonGroup[j].value = false
							end
							element.buttonGroup[j]:update() --update graphics
						end
						element.data.clickListener[self.id]() --call listener at this buttons pos in the group
					else
						element.data.clickListener() --call listener if not in group
					end
				end

				self.cRect = createCollision( self.rect, section.colGroup ) --creates collision for title object
				self.cRect.ref = element --set a reference to window that scene can access on col
				self.cRect.clickListener = buttonPressed -- function to call from scene mouse event
			end

			function button:update() --called on press in a group to indicate button status
				if (self.value == true) then
					self.rect:setFillColor( .2 )
				else
					self.rect:setFillColor( .1 )
				end
			end

			function button:draw()
				local buttonXoffset = 0
				if (element.buttonGroup) then --if button is in a group
					if (self.id > 1) then --not the first button in the group
						for i = 1, self.id - 1 do --for each other button below this one in the group
							buttonXoffset = buttonXoffset + element.buttonGroup[i].rect.width + xSpacing
						end
					end
				end
				local labelWidth, labelY
				if (element.label) then
					labelWidth = element.label.contentWidth
					labelY = element.label.y
				else
					labelWidth, labelY = 0, 0
				end

				local buttonXPos = labelWidth + xSpacing + buttonXoffset --readability
				self.rect = display.newRect( element.group, buttonXPos, 0 , buttonWidth, titleHeight - 2 )
				local string
				if (element.buttonGroup) then
					string = element.data.texts[self.id]
				else
					for k, v in pairs(element.data) do
						--print("element.data: ", k, v)
					end
					string = element.data.text
				end
				self.text = display.newText( element.group, string, buttonXPos + xSpacing, labelY, system.defaultFont, titleHeight / 1.7)
				self.rect.width = self.text.width + xSpacing*2
				self.rect:setFillColor( .1 )
			end

			button:draw()
			button:collision()

			return button
		end

		function element:drawButtonGroup()

			local buttonGroup = {}
			self.buttonGroup = buttonGroup
			for i = 1, element.data.amount do
				self.buttonGroup[i] = self:drawButton(i)
			end

			function buttonGroup:valueChangeUpdate(param, value)
				--print("!!!!! updating values for button group with param "..param.." = "..tostring(value))
				local buttonParam = element.data.param
				for i = 1, element.data.amount do
					local button = buttonGroup[i]
					if (element.data.values[i] == value) then
						button.rect:setFillColor( .2 )
					else
						button.rect:setFillColor( .1 )
					end
				end
			end

		end

		function element:drawDropdown()

			local dropdown = {}
			element.dropdown = dropdown

			dropdown.group = display.newGroup()
			dropdown.colGroup = display.newGroup()
			self.group:insert(dropdown.group)
			window.sceneGroup:insert(dropdown.colGroup)

			self.table = element.data.table

			dropdown.items = {}

			local createDropdownItem
			local clickedItem = 0
			local dropdownOpen = false

			local function expandDropdown()
				window.group:remove(section.group) --puts group to the top
				section.group:remove(element.group) --puts group to the top
				element.group:remove(dropdown.group)
				window.sceneGroup:remove(dropdown.colGroup)

				window.group:insert(section.group)
				section.group:insert(element.group)
				element.group:insert(dropdown.group)
				window.sceneGroup:insert(dropdown.colGroup)

				if (not dropdownOpen) then
					--print("expand dropdown")
					dropdown.items[1]:remove()
					dropdown.items[1] = nil

					for i = 1, #self.table do
						if (self.table[i].name) then --there is a name var in the drop downs data table 
							dropdown.items[i] = createDropdownItem(i, self.table[i].name, true)
						else
							dropdown.items[i] = createDropdownItem(i, self.table[i], true)
						end
					end
				end
				dropdownOpen = true
			end

			local function contractDropdown()
				dropdownOpen = false
				--print("contract dropdown")
				--print(#dropdown.items)
				for i = 1, #dropdown.items do
					dropdown.items[i]:remove()
					dropdown.items[i] = nil
				end
				for i = 1, dropdown.colGroup.numChildren do
					dropdown.colGroup[i]:removeSelf()
					dropdown.colGroup[i] = nil
				end

				if (clickedItem == 0) then
						if (self.table[1].name) then --there is a name var in the drop downs data table 
							dropdown.items[1] = createDropdownItem(1, self.table[1].name, false)
						else
							dropdown.items[1] = createDropdownItem(1, self.table[1], false)
						end
				else
						if (self.table[clickedItem].name) then --there is a name var in the drop downs data table 
							dropdown.items[1] = createDropdownItem(1, self.table[clickedItem].name, false)
						else
							dropdown.items[1] = createDropdownItem(1, self.table[clickedItem], false)
						end
				end

			end

			function createDropdownItem(pos, string, isListItem)

				local dropdownItem = {}

				function dropdownItem:remove ()
					--print("removing display objects")
					self.bg:removeSelf( )
					self.text:removeSelf( )
					self.cRect:removeSelf( )
				end

				function dropdownItem:collision()

					local function listItemClicked()
						if (element.table[self.pos].value) then
							--print("setting param: "..dropdown.element.param..", to value: "..table[self.pos].value)
							element.data.selectListener(element.data.param, element.table[self.pos].value)
						else
							element.data.selectListener(element.table[self.pos])
						end
						clickedItem = self.pos
						contractDropdown()
					end
					local function nonListDropDownClicked()
						expandDropdown()
					end

					self.cRect = createCollision(self.bg, dropdown.colGroup)
					self.cRect.ref = self
					self.cRect.lostFocusListener = contractDropdown
					if (isListItem) then
						self.cRect.clickListener = listItemClicked
					else
						self.cRect.clickListener = nonListDropDownClicked
					end
				end

				function dropdownItem:draw()

					self.pos = pos
					self.isListItem = isListItem

					self.bg = display.newRect( dropdown.group, element.label.width + xSpacing, titleHeight * (pos - 1), window.width - element.label.width - xSpacing * 2, titleHeight )
					self.bg:setFillColor( 0, 0, 0, .75 )
					util.zeroAnchors(self.bg)
					self.text = display.newText( dropdown.group, string, self.bg.x + xSpacing, self.bg.height * (pos - 1) + 2, system.defaultFont, titleHeight / 1.7 )
					util.zeroAnchors(self.text)

					self:collision()
					return self
				end
				return dropdownItem:draw()
			end
			
			local defaultString = nil
			if (element.data.param) then --there is a param paramater in the settings
				local defaultValue = window.object.params[element.data.param] --gets the default value from the object
				for i = 1, #element.table do
					if element.table[i].value == defaultValue then
						defaultString = element.table[i].name --sets the default string to the name in table of value
					end
				end
				if (defaultString) then
					dropdown.items[1] = createDropdownItem(1, defaultString, false)
				else
					dropdown.items[1] = createDropdownItem(1, "no default", false)
				end
			else --there is no object to update param for, we get/set list items directly
				dropdown.items[1] = createDropdownItem(1, "no default", false)
			end
			
			function dropdown:valueChangeUpdate(param, value)
				--print("!!!!! updating values for button group with param "..param.." = "..tostring(value))
				self.items[1].text.text = tostring(value)

				if (element.table) then
					for i = 1, #element.table do
						if element.table[i].value == value then
							self.items[1].text.text = element.table[i].name
						end
					end
				end
			end

		end

		function element:drawObjectList() --displays a list of objects in the passed object store
			local objectList = {}
			objectList.objectStore = element.data.objectStore
			self.objectList = objectList
			M.toolbarObjectList = objectList --accessible globally to update list

			local listItemSize = 20

			function objectList:update() --called by scene when something happens that triggers an update //ie creating emitter
				--print "!!!!!!!!!!!!! updating object list !!!!!!!!!!!!1"
				for i = 1, #element.objectList do
					element.objectList[i]:remove()
					element.objectList[i] = nil
				end
				for i = 1, #element.data.objectStore do
					local object = element.data.objectStore[i]
					element.objectList:drawListItem(object, i)
				end
			end
			function objectList:drawListItem(object, i)
				local listItem = {}
				element.objectList[#element.objectList+1] = listItem

				local function listItemClicked()
					if (objectList.objectStore[i].settingsWindow) then--only create new settings window if doesn't already exist 
					else
						objectList.objectStore[i]:createSettingsWindow()
					end
				end

				function listItem:draw()
					self.bg = display.newRect( element.group, 0, listItemSize*(i-1), window.width-8, listItemSize-2 )
					self.bg:setFillColor( 0, 0, .2 )
					self.text = display.newText( element.group, object.params["name"], 0, listItemSize*(i-1),
						system.defaultFont, listItemSize / 1.4 )
					self.cRect = createCollision(self.bg, section.colGroup)
					self.cRect.ref = self
					self.cRect.clickListener = listItemClicked
				end
				listItem:draw()

				function listItem:remove()
					self.bg:removeSelf()
					self.text:removeSelf()
					self.cRect:removeSelf()
				end

				for i = 1, element.group.numChildren do --zero anchors on all display obj in group
					util.zeroAnchors(element.group[i])
				end
			end
		end

		function element:drawMultiLineText()
			local groupInset = 20
			local x, y = section.group.x + groupInset, section.group.y + groupInset
			local width, height = section.group.contentWidth - groupInset * 3, section.group.contentHeight - groupInset * 4
			element.textBox = native.newTextBox( x, y, width, height )
			if (element.data.content) then
				element.textBox.text = element.data.content
			end
			if (element.data.editable) then
				element.textBox.isEditable = true
			end
			element.group:insert( element.textBox )
		end

		if (element.data.eType == M.elementTypes.inputField) then --requires updating on value change
			element:drawInputField()
		elseif (element.data.eType == M.elementTypes.toggleButtons) then --requires updating on value change
			element:drawButtonGroup()
		elseif (element.data.eType == M.elementTypes.dropdown) then --requires updating on value change
			element:drawDropdown()
		elseif (element.data.eType == M.elementTypes.button) then
			element:drawButton()
		elseif (element.data.eType == M.elementTypes.objectList) then
			element:drawObjectList()
		elseif (element.data.eType == M.elementTypes.multiLineText) then
			element:drawMultiLineText()
		end

		for i = 1, element.group.numChildren do --zero anchors on all display obj in group
			util.zeroAnchors(element.group[i])
		end

		return element
	end

	local function createWindowSection(sectionData, window, sceneGroup) --called by scene to add sections to window
		--print("adding window section #"..(#window.sectionStore+1)..", "..sectionData.label)

		local section = {} --create a new section object
		section.label = sectionData.label
		section.id = #window.sectionStore + 1 --store where the section is in the store
		window.sectionStore[section.id] = section --add section to the store in the window (do here rather than returning as function called by scene)
		section.group = display.newGroup() --new group for each section in window
		window.group:insert(section.group)
		section.colGroup = display.newGroup() --make a new colGroup for each section as they can be hidden
		sceneGroup:insert(section.colGroup)
		section.elementStore = {} --stores each element
		section.isHidden = false
		if (sectionData.fullHeight) then --make a dummy object the full height of the window
			local dummy = display.newRect( section.group, section.group.x, section.group.y, window.group.contentWidth, window.group.contentHeight - section.group.y )
			dummy.isVisible = false
		end

		local titleHeight = 20
		local ySpacing = 3 --height between sections

		function section:collision()

			local function toggleSectionVisibility() --called when section title is clicked
				if (self.isHidden) then
					self:show()
				else
					self:hide(true) --pass true to keep title
				end
			end

			self.titleCollision = createCollision(self.title, section.colGroup)
			self.titleCollision.ref = self
			self.titleCollision.clickListener = toggleSectionVisibility
		end

		function section:updatePos() --get y pos based off height of previous section in the window
			local yOffset = 0 --value we set to offset the section by
			if (self.id > 1) then --a section exists before this (to get height)
				local prevSectionGroup = window.sectionStore[section.id-1].group --readability
				yOffset = prevSectionGroup.y + prevSectionGroup.contentHeight + ySpacing --sets the y pos to be below the previous section y + height in the window
			end
			local yDelta = yOffset - self.group.y --moves group based off position of previous section
			for i = 1, self.colGroup.numChildren do
				--print("adjusting y for colRect #"..i.." in section to yDelta: "..yDelta)
				local cRect = self.colGroup[i]
				cRect.y = cRect.y + yDelta
			end
			for i = 1, #self.elementStore do
				if (self.elementStore[i].dropdown) then
					for j = 1, self.elementStore[i].dropdown.colGroup.numChildren do
						local cRect = self.elementStore[i].dropdown.colGroup[j]
						cRect.y = cRect.y + yDelta
					end
				end
			end
			self.group.y = yOffset --moves group based off position of previous section
		end
		section:updatePos()

		function section:drawTitle() --draw display objects

			self.title = display.newRect( self.group, 0, titleHeight, window.width, titleHeight )
			self.title:setFillColor( 0, 0, 0, .5 )
			self.titleText = display.newText( self.group, sectionData.label, 10, self.title.y + 1, system.defaultFont, titleHeight / 1.2 )

			----zero anchors
			for i = 1, self.group.numChildren do --zero anchors on all display obj in group
				util.zeroAnchors(self.group[i])
			end
			local isCollapsable = true
			for k, v in pairs(sectionData) do --lazy way to check for collapsable so it doesn't need to be set in all elementData sections
				if (k == "collapsable") then
					if (v == false) then
						isCollapsable = false
					end
				end
			end
			if (isCollapsable) then section:collision() end
		end
		section:drawTitle()

		function section:drawElements()

			--print("Creating elements for "..#sectionData.elements.." rows")
			for row = 1, #sectionData.elements do --section data contains multiple elements per index to represent lines
				for rowPos = 1, #sectionData.elements[row] do --each element in the line
					local elementData = sectionData.elements[row][rowPos]
					self.elementStore[#self.elementStore + 1] = createElement(elementData, self, window, row, rowPos)
				end
			end
		end
		section:drawElements()

		function section:hide(keepTitle)
			self.isHidden = true
			--print ("hiding section")
			local objectsToRemove = {} --place objects to remove into an array so we can iterate with k, v to remove them
			--print("group children: "..self.group.numChildren)

			if (keepTitle) then
				for i = 1, self.group.numChildren do --this removes display objects
					if (self.group[i] ~= self.title and self.group[i] ~= self.titleText ) then --do not remove title objects
						objectsToRemove[#objectsToRemove + 1] = self.group[i]
					end
				end
				for i = 1, self.colGroup.numChildren do --removes collision group objects
					if(self.colGroup[i] ~= self.titleCollision) then --do not remove title collision
						objectsToRemove[#objectsToRemove + 1] = self.colGroup[i]
					end
				end
			else --not keeping title
				for i = 1, self.group.numChildren do --this removes display objects
					objectsToRemove[#objectsToRemove + 1] = self.group[i]
				end
				for i = 1, self.colGroup.numChildren do --removes collision group objects
					objectsToRemove[#objectsToRemove + 1] = self.colGroup[i]
				end
				self.title = nil --nil the title reference so we can know whether to redraw title
			end
			for i = 1, #self.elementStore do --remove dropdown collision
				if (self.elementStore[i].dropdown) then
					for j = 1, self.elementStore[i].dropdown.colGroup.numChildren do
						objectsToRemove[#objectsToRemove + 1] = self.elementStore[i].dropdown.colGroup[j]
					end
				end
			end
			--print("removing "..#objectsToRemove.." objects from section")
			for _, object in ipairs( objectsToRemove ) do
				object:removeSelf()
			end
			for i = 1, #section.elementStore do --this removes the element's data
				section.elementStore[i] = nil
			end
			for i = 1, #window.sectionStore do --updates all other sections in the window
				--print("updating position for section# "..i)
				window.sectionStore[i]:updatePos()
			end
		end

		function section:show()
			self.isHidden = false
			self:updatePos()
			if (not self.title) then --title wasn't hidden so no need to redraw
				self:drawTitle()
			end
			self:drawElements()
			for i = 1, #window.sectionStore do --updates all other sections in the window
				window.sectionStore[i]:updatePos()
			end
		end

		return section
	end

	function M.onFrame()
		for i = 1, #M.windowStore do
			M.windowStore[i]:onFrame()
		end
	end

	function M.createWindow( _params, sceneGroup ) --called from scene to create window object
		--print("creating window")

		--set defaults
		local params = _params or {}
		local defaultParams = {
			x = 20, y = 20, width = 100, height = 200, sceneGroup = {},
			label = "window", closable = false, movable = false,
			bgColour = {.4, .4, .4, .8}, titleColour = {1, 1, 1, .8}, titleTextColour = {0, 0, 0},
			sectionData = {}, object = {}
		}
		----assign pased params to window object
		local window = {}
		window.colGroup = display.newGroup() --used for collision with elements as group can't be moved, added to scene after all window constructed

		for k, default in pairs( defaultParams ) do
			if params[k] then
				--print("setting key: "..k..", to passed "..tostring(params[k]))
				window[k] = params[k]
			else
				--print("setting key: "..k..", to default "..tostring(default))
				window[k] = default
			end
		end

		local titleHeight = 20
		local closeButtonOffset = titleHeight * .15

		local function titlePressed()
			--print("TITLE PRESSED!!!!")
			window.isMoving = true
			--print(window.isMoving)
			--bring all groups to the front
			window.sceneGroup:remove(window.group)
			window.sceneGroup:insert(window.group)
			window.sceneGroup:remove(window.colGroup)
			window.sceneGroup:insert(window.colGroup)
			for i = 1, #window.sectionStore do
				window.sceneGroup:remove(window.sectionStore[i].colGroup)
				window.sceneGroup:insert(window.sectionStore[i].colGroup)
				if window.sectionStore[i].elementStore then
					for j = 1, #window.sectionStore[i].elementStore do
						if window.sectionStore[i].elementStore[j].dropdown then
							window.sceneGroup:remove(window.sectionStore[i].elementStore[j].dropdown.colGroup)
							window.sceneGroup:insert(window.sectionStore[i].elementStore[j].dropdown.colGroup)
						end
					end
				end
			end
		end

		local function closePressed()
			--window.group.isVisible = false
			local objectsToRemove = {}
			for i = 1, #window.sectionStore do
				window.sectionStore[i]:hide()
			end
			for i = 1, window.group.numChildren do --removes collision group objects
				objectsToRemove[#objectsToRemove + 1] = window.group[i]
			end
			for i = 1, window.colGroup.numChildren do --removes collision group objects
				objectsToRemove[#objectsToRemove + 1] = window.colGroup[i]
			end
			--print("removing "..#objectsToRemove.." objects from section")
			for _, object in ipairs( objectsToRemove ) do
				object:removeSelf()
			end
			window.object.windowClosed(window)
			--window.object.settingsWindow = nil
		end

		function window:paramValueChanged(param, value)
			--print ("param "..param.." has changed")
			for i = 1, #self.sectionStore do
				local section = self.sectionStore[i]
				for j = 1, #section.elementStore do
					local element = section.elementStore[j]
					if (element.data.param == param) then
						local typeObject = nil
						if (element.data.eType == M.elementTypes.inputField) then --requires updating on value change
							typeObject = element.inputField
						elseif (element.data.eType == M.elementTypes.toggleButtons) then --requires updating on value change
							typeObject = element.buttonGroup
						elseif (element.data.eType == M.elementTypes.dropdown) then --requires updating on value change
							typeObject = element.dropdown
							--print(typeObject)
						end
						if (typeObject) then
							--print("found element for param")
							typeObject:valueChangeUpdate(param, value)
						end
					end
				end
			end
		end

		function window:onFrame() --called by scene onFrame to move window
			if (self.isMoving) then
				local function moveGroupWithMouse(group)
					for i = 1, group.numChildren do
						group[i].x, group[i].y = group[i].x + mouse.delta.x, group[i].y + mouse.delta.y
					end
				end

				if (mouse.pressed) then
					--print("update window pos using delta: "..mouse.delta.x, mouse.delta.y)
					local blockDirection = nil
					local nx, ny = self.group.x + mouse.delta.x, self.group.y + mouse.delta.y --new position for readability

					if ( nx <= 0) then blockDirection = g.move.left end
					if ( nx + self.width >= display.actualContentWidth) then blockDirection = g.move.right end
					if ( ny <= 0) then blockDirection = g.move.up end
					if ( ny + self.height >= display.actualContentHeight) then blockDirection = g.move.down end

					if (blockDirection) then
						if blockDirection == g.move.up or blockDirection == g.move.down then
							mouse.delta.x = 0
						elseif blockDirection == g.move.left or blockDirection == g.move.right then
							mouse.delta.y = 0
						end
					else
						self.group.x, self.group.y = self.group.x + mouse.delta.x, self.group.y + mouse.delta.y	 --move group

						moveGroupWithMouse(self.colGroup) --move each collision rect as they do not move with groups

						for i = 1, #self.sectionStore do --move elements within each sections colgroup
							moveGroupWithMouse(self.sectionStore[i].colGroup)
						end

						for i = 1, #self.sectionStore do
							for j = 1, #self.sectionStore[i].elementStore do
								if (self.sectionStore[i].elementStore[j].dropdown) then --move elemnts within each dropdown colGroup
									moveGroupWithMouse(self.sectionStore[i].elementStore[j].dropdown.colGroup)
								end
							end
						end
					end
				else  --only do movement of window when mouse button is held down
					self.isMoving = false
				end
			end
		end

		function window:createDisplayObjects() --using methods to create/destroy window while keeping params

			----group
			self.group = display.newGroup() --display group for moving whole window
			sceneGroup:insert(self.group)
			self.dropdownGroup = display.newGroup() --dropdowns need to be above everything else
			sceneGroup:insert(self.dropdownGroup)
			self.group.x, self.group.y = self.x, self.y

			----background
			self.bg = display.newRect( self.group, 0, 0, self.width, self.height ) --background for window
			self.bg:setFillColor( unpack(self.bgColour) )

			----title
			self.title = display.newRect( self.group, 0, 0, self.width, titleHeight ) --title for window
			self.title:setFillColor( unpack(self.titleColour) )

			----collision
			if (self.movable) then	--if window movable make collision for title
				--print("adding collision rect at coords:", self.x, self.y, self.width, titleHeight)
				self.titleCRect = createCollision( self.title, window.colGroup ) --creates collision for title object
				self.titleCRect.ref = self --set a reference to window that scene can access on col
				self.titleCRect.clickListener = titlePressed -- function to call from scene mouse event
			end

			----title
			self.titleText = display.newText( self.group, self.label, 5, 0, self.width, titleHeight,
				system.defaultFont, titleHeight / 1.2 ) --text label for window
			self.titleText:setFillColor( unpack(self.titleTextColour) )

			----x button
			if (self.closable) then --if closable make x button and collision

				local width, height = titleHeight - closeButtonOffset*2, titleHeight - closeButtonOffset*2 --for readability
				self.closeButton = display.newImageRect( self.group, "content/ui/x.png", width, height )
				self.closeButton.x, self.closeButton.y = self.width - titleHeight + closeButtonOffset, closeButtonOffset

				self.closeCRect = createCollision( self.closeButton, self.colGroup) --add collision
				self.closeCRect.clickListener = closePressed -- function to call from scene mouse event
			end

			----zero anchors
			for i = 1, self.group.numChildren do --zero anchors on all display anchors in group
				util.zeroAnchors(self.group[i])
			end
		end

		function window:setSectionVisibility(label, show) --called by scene to show/hide a section completely
			for i = 1, #self.sectionStore do
				local section = self.sectionStore[i]
				if (section.label == label) then
					if (show) then
						if (section.isHidden) then --only show if already hidden, else do nothing
							section:show()
						end
					else
						if (not section.isHidden) then --only hide if not already hidden
							section:hide()
						end
					end
				end
			end
		end

		window.sectionStore = {} --used to get y pos of previous section to set y
		window:createDisplayObjects() --call method to create window

		sceneGroup:insert(window.colGroup) --after other display objects have been drawn

		--print("adding window to store at "..#M.windowStore)
		M.windowStore[#M.windowStore + 1] = window --add window to store so can update on frame

		for i = 1, #window.sectionData do
			--print("creating section #"..i)
			window.sectionStore[i] = createWindowSection(window.sectionData[i], window, sceneGroup)
			if (window.sectionData[i].startHidden) then
				window.sectionStore[i]:hide()
			end
		end

		return window --returns to scene to be added to store
	end

	return M