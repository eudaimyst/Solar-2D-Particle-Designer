---@diagnostic disable: undefined-field
	-----------------------------------------------------------------------------------------
	--
	-- particle_designer.lua
	--
	-----------------------------------------------------------------------------------------

	--common modules - solar2d
	local composer = require("composer")
	local physics = require("physics")
	local easing = require("lib.easing")
	local lfs = require("lfs")
	local json = require("json")
	--common modules
	local g = require("lib.globals")
	local util = require("lib.utilities")
	local debug = require("lib.debug")
	local key = require("lib.key_input")

	--other modules
	local mouse = require("lib.mouse_input")
	local editor = require("lib.editor")

	--create scene
	local scene = composer.newScene()
	local sceneGroup = display.newGroup()
	local emitterGroup = display.newGroup()
	local spawnPointGroup = display.newGroup( )

	-- Change current working directory
	local folderName = "Solar2D Particle Designer"
	lfs.chdir( system.pathForFile( "", system.DocumentsDirectory ) )
	lfs.mkdir( folderName )
	local jsonParamsPath = lfs.currentdir() .. "/" .. folderName
	print("JSON PATH!!!!!!! = "..jsonParamsPath)

	local emitterParams = { --params used by point and radial
		maxParticles = 100,
		angle = -90, angleVariance = 180,
		emitterType = 0, --0 for point, 1 for radial
		absolutePosition = false,
		duration = -1, --seconds before removed
		textureFileName = "content/particles/skull.png",
		particleLifespan = 2, particleLifespanVariance = 0,
		startParticleSize = 64, startParticleSizeVariance = 0,
		finishParticleSize = 64, finishParticleSizeVariance = 0,
		rotationStart = 0, rotationStartVariance = 0,
		rotationEnd = 0, rotationEndVariance = 0,
		blendFuncSource = 770, blendFuncDestination = 1,
		speed = 100, speedVariance = 0,
		sourcePositionVariancex = 0, sourcePositionVariancey = 0,
		gravityx = 0, gravityy = 0,
		radialAcceleration = 0, radialAccelVariance = 0,
		tangentialAcceleration = 0, tangentialAccelVariance = 0,
		maxRadius = 0, maxRadiusVariance = 0,
		minRadius = 200, minRadiusVariance = 0,
		rotatePerSecond = 0, rotatePerSecondVariance = 0
	}
	local emitterRestartParams = { "name", "textureFileName", "maxParticles", "blendFuncSource", "blendFuncDestination", "duration" } --list of params that require emitter to be restarted to take effect

	local shortColorParams = { --particle color params
		startColor = 0, startColorVariance = 0, finishColor = 0, finishColorVariance = 0
	}
	local appendColorParams = { Red = 0, Green = 0, Blue = 0, Alpha = 0 } --get added to short version
	local particleColorParams = {}--final array holds all the color params

	for shortKey, _ in pairs(shortColorParams) do
		for appendKey, _ in pairs(appendColorParams) do
			particleColorParams[tostring(shortKey)..tostring(appendKey)] = 0 --sets all variance color in short and append tables to 0
		end
	end

	local blendModes = {
		{name = "zero", value = 0}, {name = "one", value = 1}, {name = "dst color", value = 774}, {name = "one - dst color", value = 775},
		{name = "src alpha", value = 770}, {name = "one - src alpha", value = 771}, {name = "dst alpha", value = 772}, {name = "one - dst alpha", value = 773},
		{name = "src alpha sat", value = 776}, {name = "src color", value = 768}, {name = "one - src color", value = 769},
	}

	local particleFiles = {	}
	local fileCounter = 1
	for file in lfs.dir( system.pathForFile(system.ResourceDirectory).."/content/particles/" ) do
		--print("Found file: ".. file)
		local particleFile = {}
		particleFile.name = file
		particleFile.value = "content/particles/"..file
		if (file ~= "." and file ~= "..") then
			particleFiles[fileCounter] = particleFile
			fileCounter = fileCounter + 1
		end
	end

	local toolbarWindow --set when toolbar is created, only ever one

	local emitterStore = {}

	local function createEmitter() --used to pass paramaters if emitter is loaded

		local emitter = {}
		emitter.id = #emitterStore + 1
		emitterStore[emitter.id] = emitter

		function emitter.initParams() --adds the color params to the emitter params
			local params = {}
			params.name = "emitter"..emitter.id --sets a name for the emitter
			for k, v in pairs(emitterParams) do
				params[k] = v
			end
			for k, v in pairs(particleColorParams) do
				if ( ( string.find(k, "startColor") or string.find(k, "finishColor") ) and not string.find(k, "Alpha") and not string.find(k, "Variance") ) then
					params[k] = math.round(math.random() * 100)/100
				elseif (string.find(k, "startColorAlpha")) then
					params[k] = 1
				else
					params[k] = v
				end
			end
			return params
		end

		emitter.params = emitter.initParams()

		function emitter:createSaveTextWindow()

			local objectParamsString = self.params.name.."Params = {\n"
			for k, v in pairs(self.params) do
				if (k ~= "name") then --skip name as it's not an actual emitter param
					objectParamsString = objectParamsString.."	"..tostring(k).." = "..tostring(v)..",\n"
				end
			end
			objectParamsString = objectParamsString.."}"

			local sectionData = { [1] = { label = "paramaters (copy + paste)", fullHeight = true, collapsable = false, elements = {
						[1] = { { eType = editor.elementTypes.multiLineText, content = objectParamsString, editable = true } },
			} } }
			local width, height = display.actualContentWidth / 2, display.actualContentHeight * 3 / 4
			local windowParams = {
				x = width / 2, y = height / 4, width = width, height = height, label = "Save to text",
				closable = true, movable = true, sceneGroup = sceneGroup, sectionData = sectionData, object = self
			}
			self.saveTextWindow = editor.createWindow( windowParams, sceneGroup )

		end

		function emitter:createLoadTextWindow()

			local function loadParamsFromString()
				local loadedParams = {} --stores params from string
				local paramString = self.loadTextWindow.sectionStore[1].elementStore[2].textBox.text --gets the string from the textbox in the window (hardcoded using data below)
				for k, v in string.gmatch( paramString, "([%w%.%/]+) = ([%w%.%/]+)" ) do --wow amazing string lib
					--print("setting from load: "..k..", "..v)
				    if (k == "textureFileName") then --keep filename as a string
						loadedParams[k] = v
				    else
						loadedParams[k] = tonumber(v)
				    end
				end
			    for param, value in pairs(loadedParams) do
			    	--print("setting param: "..param.." to value: "..value.." from string load function")
					self:updateParam(param, value)
			    end
				self:restart() --restarts the emitter after load
			end

			local sectionData = { [1] = { label = "paramaters (copy + paste)", fullHeight = true, collapsable = false, elements = {
				[1] = { { eType = editor.elementTypes.button, text = "Load", clickListener = loadParamsFromString} },
				[2] = { { eType = editor.elementTypes.multiLineText, editable = true } }
			} } }
			local width, height = display.actualContentWidth / 2, display.actualContentHeight * 3 / 4
			local windowParams = {
				x = width / 2, y = height / 4, width = width, height = height, label = "Load from text",
				closable = true, movable = true, sceneGroup = sceneGroup, sectionData = sectionData, object = self
			}
			self.loadTextWindow = editor.createWindow( windowParams, sceneGroup )
		end

		function emitter:createLoadJsonWindow()

			local jsonParamFiles = {}
			local fileCounter = 1
			local fileToLoad

			print("searching for files in: "..jsonParamsPath)
			for file in lfs.dir( jsonParamsPath ) do
				if (file ~= "." and file ~= "..") then
					--print("Found file: ".. file)
					jsonParamFiles[fileCounter] = file
					fileCounter = fileCounter + 1
				end
			end

			local function setFile(fileName) --called when item is selected in dropdown
				fileToLoad = fileName
			end

			local function loadParamsFromFile() --called when load button is pressed
				local file, errorString = io.open( jsonParamsPath.."/"..fileToLoad, "r" ) -- Open the file handle
				if not file then
				    --print( "File error: " .. errorString ) -- Error occurred; output the cause
				else
				    local jsonContents = file:read( "*a" ) -- Read data from file
				    --print( "Contents of file: \n" .. jsonContents ) -- Output the file contents
				    local loadedParams = json.decode( jsonContents )

				    for param, value in pairs(loadedParams) do
						self:updateParam(param, value)
				    end
				    io.close( file ) -- Close the file handle
				end
				file = nil
				self:restart() --restarts the emitter after load
			end

			local sectionData = { [1] = { label = "replace "..self.params.name.." params", collapsable = false, elements = {
				[1] = { { label = "File name", eType = editor.elementTypes.dropdown, selectListener = setFile, table = jsonParamFiles } },
				[2] = { { eType = editor.elementTypes.button, text = "Load", clickListener = loadParamsFromFile} }
			} } }

			local width, height = 200, 100
			local windowParams = {
				x = display.contentCenterX - width / 2, y = display.contentCenterY - height / 2, width = width, height = height, label = "Load from json",
				closable = true, movable = true, sceneGroup = sceneGroup, sectionData = sectionData, object = self
			}
			self.loadJsonWindow = editor.createWindow( windowParams, sceneGroup )
		end

		function emitter.windowClosed(window) --called from editor when *any* window is closed, to nil necessary values for windows that need to be re-opened
			if (window == emitter.settingsWindow) then
				emitter.settingsWindow = nil
			end
		end

		function emitter:updateParam(param, value)
			--print("updating param: "..param.." to: "..value)
			if self.emitterObject then --emitter exists, try to pass the param straight to it
				self.emitterObject[param] = value
			end
			self.params[param] = value
			--print ("updated "..param.." to "..tostring(value))
			for k, v in pairs(self.params) do
				--print(tostring(k).." = "..tostring(v))
			end
			if (param == "name") then editor.toolbarObjectList:update() end

			for i = 1, #emitterRestartParams do
				if param == emitterRestartParams[i] then
					print("param.."..param.."..changed, restarting emitter")
					self:restart()
				end
			end

			self.settingsWindow:paramValueChanged(param, value)
		end


		function emitter:createWindowSettings()

			local function startPressed()
				if (self.emitterObject) then
					self.emitterObject:start()
					--print("emitter exists, starting emitter")
				else
					self:createObject()
					self.emitterObject:start()
				end
			end

			local function pausePressed()
				if (self.emitterObject) then
					self.emitterObject:pause( )
					--print("pausing emitter")
				end
			end

			local function stopPressed()
				if (self.emitterObject) then
					self.emitterObject:stop()
					self.group:removeSelf()
					self.emitterObject = nil
					--print("stopping emitter")
				end
			end

			local function updateParam(param, value) --called by editor when a parameter updates
				self:updateParam(param, value) --moved contents to emitter so can be accessed when loading files
			end

			local function setAbsPosTrue()
				updateParam("absolutePosition", true)
			end

			local function setAbsPosFalse()
				updateParam("absolutePosition", false)
			end

			local function setTypePoint()
				self.settingsWindow:setSectionVisibility("Point", true)
				self.settingsWindow:setSectionVisibility("Radial", false)
				updateParam("emitterType", 0)
				self:restart()
			end

			local function setTypeRadial()
				self.settingsWindow:setSectionVisibility("Radial", true)
				self.settingsWindow:setSectionVisibility("Point", false)
				updateParam("emitterType", 1)
				self:restart()
			end

			local function showSpawnPoint()
				emitter.spawnPoint.isVisible = true
			end

			local function hideSpawnPoint()
				emitter.spawnPoint.isVisible = false
			end

			local function textSave()
				self:createSaveTextWindow()
			end

			local function textLoad()
				self:createLoadTextWindow()
			end

			local function jsonSave()
				local saveData = json.encode( self.params , {indent = true} )
				--print(saveData)
			    local filePath = jsonParamsPath.."/"..self.params.name..".json"
			    local file = nil
				local errorString = nil
			    if ( filePath ) then
			        file, errorString = io.open( filePath, "w" )
			    end
		        if not file then
		            print( "File error: " .. errorString ) -- Error occurred; output the cause
		        else
				    file:write( saveData ) --write data to file
				    io.close( file ) --close file handle
				end
				file = nil --free memeory
				saveData = nil
			end

			local function jsonLoad()
				self:createLoadJsonWindow()
			end

			local t = editor.elementTypes --for readability
			self.settingsWindowSections = { --sections in the settings window that hold elements, uses index for ordering in ui
				[1] = { label = "Controls", elements = {
						[1] = { { label = "Emitter", eType = t.toggleButtons, amount = 3, texts = { "start", "stop", "pause" }, clickListener = { startPressed, stopPressed, pausePressed } } }, --start, stop, pause
						[2] = { { param = "name", label = "Name", width = 100, eType = t.inputField, inputListener = updateParam, inputType = "text" } },
						[3] = { { label = "Save", eType = editor.elementTypes.button, text = "text", clickListener = textSave}, { eType = editor.elementTypes.button, text = "json", clickListener = jsonSave},
								{ label = "Load", eType = editor.elementTypes.button, text = "text", clickListener = textLoad}, { eType = editor.elementTypes.button, text = "json", clickListener = jsonLoad} },
						[4] = { { label = "Spawn Point", eType = t.toggleButtons, amount = 2, texts = { "show", "hide" }, clickListener = { showSpawnPoint, hideSpawnPoint } } },
				} },
				[2] = { label = "General", elements = {
						[1] = { {param = "textureFileName", label = "Texture", eType = t.dropdown, selectListener = updateParam, table = particleFiles } },
						[2] = { {param = "angle", label = "Angle", eType = t.inputField, inputListener = updateParam }, { param = "angleVariance", label = "Var", eType = t.inputField, inputListener = updateParam } },
						[3] = { {param = "emitterType", label = "Emitter type", eType = t.toggleButtons, amount = 2, texts = {"point", "radial"}, values = {0, 1}, clickListener = { setTypePoint, setTypeRadial } } },
						[4] = { {param = "absolutePosition", label = "Absolute Pos", eType = t.toggleButtons, amount = 2, texts = {"true", "false"}, values = {true, false}, clickListener = { setAbsPosTrue, setAbsPosFalse } } },
						[5] = { {param = "duration", label = "Duration", eType = t.inputField, inputListener = updateParam } },
				} },
				[3] = {	label = "Point", elements = {
						[1] = { {param = "speed", label = "Speed", eType = t.inputField, inputListener = updateParam }, {param = "speedVariance", label = "Var", eType = t.inputField, inputListener = updateParam } },
						[2] = { {param = "sourcePositionVariancex", label = "SrcPos VarX", eType = t.inputField, inputListener = updateParam }, {param = "sourcePositionVariancey", label = "SrcPos VarY", eType = t.inputField, inputListener = updateParam } },
						[3] = { {param = "gravityx", label = "Gravity X", eType = t.inputField, inputListener = updateParam }, {param = "gravityy", label = "Gravity Y", eType = t.inputField, inputListener = updateParam } },
						[4] = { {param = "radialAcceleration", label = "Radial Accel", eType = t.inputField, inputListener = updateParam }, {param = "radialAccelVariance", label = "Var", eType = t.inputField, inputListener = updateParam } },
						[5] = { {param = "tangentialAcceleration", label = "Tangent Accel", eType = t.inputField, inputListener = updateParam }, {param = "tangentialAccelVariance", label = "Var", eType = t.inputField, inputListener = updateParam } },
				} },
				[4] = { label = "Radial", startHidden = true, elements = {
						[1] = { {param = "maxRadius", label = "Max Radius", eType = t.inputField, inputListener = updateParam }, {param = "maxRadiusVariance", label = "Var", eType = t.inputField, inputListener = updateParam } },
						[2] = { {param = "minRadius", label = "Min Radius", eType = t.inputField, inputListener = updateParam }, {param = "minRadiusVariance", label = "Var", eType = t.inputField, inputListener = updateParam } },
						[3] = { {param = "rotatePerSecond", label = "Rotations/sec", eType = t.inputField, inputListener = updateParam }, {param = "rotatePerSecondVariance", label = "Var", eType = t.inputField, inputListener = updateParam } }
				} },
				[5] = { label = "Particles", elements = {
						[1] = { {param = "maxParticles", label = "Max Particles", eType = t.inputField, inputListener = updateParam } },
						[2] = { {param = "particleLifespan", label = "Lifespan", eType = t.inputField, inputListener = updateParam }, {param = "particleLifespanVariance", label = "Var", eType = t.inputField, inputListener = updateParam } },
						[3] = { {param = "startParticleSize", label = "Start Size", eType = t.inputField, inputListener = updateParam }, {param = "startParticleSizeVariance", label = "Var", eType = t.inputField, inputListener = updateParam } },
						[4] = { {param = "finishParticleSize", label = "End Size", eType = t.inputField, inputListener = updateParam }, {param = "finishParticleSizeVariance", label = "Var", eType = t.inputField, inputListener = updateParam } },
						[5] = { {param = "rotationStart", label = "Start Rot", eType = t.inputField, inputListener = updateParam }, {param = "rotationStartVariance", label = "Var", eType = t.inputField, inputListener = updateParam } },
						[6] = { {param = "rotationEnd", label = "End Rot", eType = t.inputField, inputListener = updateParam }, {param = "rotationEndVariance", label = "Var", eType = t.inputField, inputListener = updateParam } },
						[7] = { {param = "blendFuncSource", label = "Blend Src", eType = t.dropdown, selectListener = updateParam, table = blendModes } },
						[8] = { {param = "blendFuncDestination", label = "Blend Dest", eType = t.dropdown, selectListener = updateParam, table = blendModes } }
				} },
				[6] = { label = "Colours", elements = {
						[1] = { {param = "startColorRed", label = "Start R", eType = t.inputField, inputListener = updateParam }, {param = "startColorGreen", label = "G", eType = t.inputField, inputListener = updateParam },
								{param = "startColorBlue", label = "B", eType = t.inputField, inputListener = updateParam }, {param = "startColorAlpha", label = "A", eType = t.inputField, inputListener = updateParam } },
						[2] = { {param = "startColorVarianceRed", label = "Var R", eType = t.inputField, inputListener = updateParam }, {param = "startColorVarianceGreen", label = "G", eType = t.inputField, inputListener = updateParam },
								{param = "startColorVarianceBlue", label = "B", eType = t.inputField, inputListener = updateParam }, {param = "startColorVarianceAlpha", label = "A", eType = t.inputField, inputListener = updateParam } },
						[3] = { {param = "finishColorRed", label = "Finish R", eType = t.inputField, inputListener = updateParam }, {param = "finishColorGreen", label = "G", eType = t.inputField, inputListener = updateParam },
								{param = "finishColorBlue", label = "B", eType = t.inputField, inputListener = updateParam }, {param = "finishColorAlpha", label = "A", eType = t.inputField, inputListener = updateParam } },
						[4] = { {param = "finishColorVarianceRed", label = "Var R", eType = t.inputField, inputListener = updateParam }, {param = "finishColorVarianceGreen", label = "G", eType = t.inputField, inputListener = updateParam },
								{param = "finishColorVarianceBlue", label = "B", eType = t.inputField, inputListener = updateParam }, {param = "finishColorVarianceAlpha", label = "A", eType = t.inputField, inputListener = updateParam } }
			} } }
			self.settingsWindowParams = {
				x = 20, y = 20, width = 300, height = 800,
				label = "settings", closable = true, movable = true,
				sceneGroup = sceneGroup, sectionData = self.settingsWindowSections, --put settingsWindowSections in emitter to access collision listeners from emitter
				object = emitter
			}
		end

		local function spawnPointClicked()
			--print("spawnPoint clicked")
			if (emitter.spawnPoint.isVisible == true) then
				emitter.spawnPoint.isMoving = true
			end
		end

		emitter.spawnPoint = display.newImage( spawnPointGroup, "content/ui/x.png")
		emitter.spawnPoint.x, emitter.spawnPoint.y = display.contentCenterX, display.contentCenterY
		emitter.spawnPoint:setFillColor( .5, .5, .5 )
		physics.addBody( emitter.spawnPoint, "static" )
		emitter.spawnPoint.clickListener = spawnPointClicked
		emitter.spawnPoint.isMoving = false

		function emitter:onFrame()

			if (self.spawnPoint.isMoving) then
				if (mouse.pressed) then
					self.spawnPoint.x, self.spawnPoint.y = self.spawnPoint.x + mouse.delta.x, self.spawnPoint.y + mouse.delta.y	 --move object
					self.x, self.y = self.spawnPoint.x, self.spawnPoint.y
					if (self.emitterObject) then
						self.emitterObject.x, self.emitterObject.y = self.spawnPoint.x, self.spawnPoint.y
					end
				else  --only do movement of window when mouse button is held down
					self.spawnPoint.isMoving = false
				end
			end
		end

		function emitter:restart() -- for changing some params, requires emitter to be stopped and started
			if (self.emitterObject) then --emitter exists
				if (self.emitterObject.state == "playing") then --only restart if emitter is already started
					self.emitterObject:stop()
					self.group:removeSelf()
					self.emitterObject = nil
					self:createObject()
					self.emitterObject:start()
				end
			end
		end

		function emitter:createObject()
			self.group = display.newGroup()
			for k, v in pairs(self.params) do
				--print("params: "..k, v)
			end
			self.emitterObject = display.newEmitter( self.params )
			self.emitterObject.x, self.emitterObject.y = self.x or display.contentCenterX, self.y or display.contentCenterY
			self.group:insert(self.emitterObject)
			emitterGroup:insert(self.group)
			--print("call toolbar window ")
		end
		emitter:createObject()
		editor.toolbarObjectList:update() --calls the function in the editor toolbar to update the list of emitters


		function emitter:createSettingsWindow() --called when emitter is created, but also when window is shown after closing
			self.settingsWindow = editor.createWindow( self.settingsWindowParams, sceneGroup )
			for param, value in pairs(self.params) do
				self.settingsWindow:paramValueChanged(param, value) --set default values of all elements
			end
		end

		emitter:createWindowSettings()
		emitter:createSettingsWindow()

	end

	local function firstFrame()

		debug.createGroup()

		sceneGroup:insert(emitterGroup)
		sceneGroup:insert(spawnPointGroup)

		key.init() --initiate key input

		local toolbarWindowSections = { --sections in the settings window that hold elements, uses index for ordering in ui
			[1] = { label = "Emitters", collapsable = false, elements = {
					[1] = { { label = "", eType = editor.elementTypes.button, text = "Create Emitter", clickListener = createEmitter } },
					[2] = { { eType = editor.elementTypes.objectList, objectStore = emitterStore } }
			} },
		}
		local toolbarWindowParams = {
			x = display.actualContentWidth - 400, y = 20, width = 200, height = 200,
			label = "toolbar", closable = false, movable = true,
			sceneGroup = sceneGroup, sectionData = toolbarWindowSections
		}

		--local settingsWindow = createWindow( settingsWindowParams )
		toolbarWindow = editor.createWindow( toolbarWindowParams, sceneGroup )

		mouse.init() -- registers the mouse on frame event

	end

	local function onFrame( event )

		for i = 1, #emitterStore do
			emitterStore[i]:onFrame()
		end
		editor.onFrame() --update everything in editor interface
		debug.onFrame()

	end

	function scene:create( event )
		display.setDefault( "background", .09, .09, .09 )
		-- Called when scene's view does not exist.
		--
		-- INSERT code here to initialize scene
		-- e.g. add display objects to 'sceneGroup', add touch listeners, etc.
		-- create scene group

		local sceneGroup = self.view
		-- We need physics started to add bodies
		physics.start()
		physics.setGravity( 0, 0 )

	end

	function scene:show( event )
		local sceneGroup = self.view
		local phase = event.phase

		if phase == "will" then
			-- Called when scene is still off screen and is about to move on screen
		elseif phase == "did" then
			-- Called when scene is now on screen
			--
			-- INSERT code here to make scene come alive
			-- e.g. start timers, begin animation, play audio, etc.

			--print("scene loaded")

			firstFrame()

			--add listerer for every frame to process all game logic
			Runtime:addEventListener( "enterFrame", onFrame )

		end
	end

	function scene:hide( event )
		local sceneGroup = self.view

		local phase = event.phase

		if event.phase == "will" then
			-- Called when scene is on screen and is about to move off screen
			--
			-- INSERT code here to pause scene
			-- e.g. stop timers, stop animation, unload sounds, etc.)

			timer.cancel( "menu" ) --cancels all running timers
			transition.cancelAll() --cancels all transitions

			Runtime:addEventListener( "enterFrame", onFrame )

		elseif phase == "did" then
			-- Called when scene is now off screen
		end
	end

	function scene:destroy( event )

		-- Called prior to removal of scene's "view" (sceneGroup)
		--
		-- INSERT code here to cleanup scene
		-- e.g. remove display objects, remove touch listeners, save state, etc.
		local sceneGroup = self.view

		package.loaded[physics] = nil
		physics = nil

	end

	---------------------------------------------------------------------------------

	-- Listener setup
	scene:addEventListener( "create", scene )
	scene:addEventListener( "show", scene )
	scene:addEventListener( "hide", scene )
	scene:addEventListener( "destroy", scene )

	-----------------------------------------------------------------------------------------

	return scene