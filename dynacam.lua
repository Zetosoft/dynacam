---------------------------------------------- Dynacam - Dynamic Lighting Camera System - Basilio Germán
local moduleParams = ...
local moduleName = moduleParams.name or moduleParams
local requirePath = moduleParams.path or ""
local projectPath = string.gsub(requirePath, "%.", "/")

require(requirePath.."shaders.rotate")
require(requirePath.."shaders.apply")
require(requirePath.."shaders.light")

local quantum = require(requirePath.."quantum")
local CoronaLibrary = require("CoronaLibrary")
local physics = require("physics")

local dynacam = setmetatable(CoronaLibrary:new({
	name = "dynacam",
	publisherId="com.zetosoft",
	version = 1,
	revision = 1,
}), { -- Quantum provides object creation
	__index = function(self, index)
		return quantum[index]
	end,
})
---------------------------------------------- Variables
local targetRotation
local finalX, finalY
local radAngle
local focusRotationX, focusRotationY
local rotationX, rotationY

local initialized
local isTracking
local cameras
---------------------------------------------- Constants
local CULL_LIMIT_MIN = -0.4
local CULL_LIMIT_MAX = 1.4
local RADIANS_MAGIC = math.pi / 180 -- Used to convert degrees to radians
local DEFAULT_ATTENUATION = {0.4, 3, 20}
local DEFAULT_AMBIENT_LIGHT = {0, 0, 0, 1}

local TRANSFORM_PROPERTIES_MATCHER = {
	["x"] = true,
	["y"] = true,
	["xScale"] = true,
	["yScale"] = true,
	["rotation"] = true,
}
local FLAG_REMOVE = "_removeFlag"
local SCALE_LIGHTS = 1000 / display.viewableContentHeight
---------------------------------------------- Cache
local mathAbs = math.abs
local mathHuge = math.huge
local mathCos = math.cos
local mathSin = math.sin

local tableRemove = table.remove

local ccx = display.contentCenterX
local ccy = display.contentCenterY
local vcw = display.viewableContentWidth
local vch = display.viewableContentHeight

local vcwr = 1 / vcw
local vchr = 1 / vch

local display = display
local easing = easing
local transition = transition

local rawset = rawset
local rawget = rawget
---------------------------------------------- Metatable
local touchMonitorMetatable = { -- Monitor transform changes
	__index = function(self, index)
		return self._superMetaTouch.__index(self, index)
	end,
	__newindex = function(self, index, value)
		if TRANSFORM_PROPERTIES_MATCHER[index] then -- Replicate transform to maskObject
			rawget(self, "maskObject")[index] = value
		end
		self._superMetaTouch.__newindex(self, index, value)
	end
}
---------------------------------------------- Local functions 
local function cameraAdd(self, lightObject, isFocus)
	if lightObject.normalObject then -- Only lightObjects have a normalObject property
		if isFocus then
			self.values.focus = lightObject
		end
		
		lightObject.camera = self
		
		self.diffuseView:insert(lightObject)
		self.normalView:insert(lightObject.normalObject)
		
		self.objects[#self.objects + 1] = lightObject
	else -- Regular object
		self.defaultView:insert(lightObject)
	end
end

local function cameraSetZoom(self, zoom, zoomDelay, zoomTime, onComplete)
	zoom = zoom or 1
	zoomDelay = zoomDelay or 0
	zoomTime = zoomTime or 500
	
	transition.cancel(self.diffuseView)
	transition.cancel(self.normalView)
	transition.cancel(self.defaultView)
	transition.cancel(self.values)
		
	if zoomDelay <= 0 and zoomTime <= 0 then
		self.values.zoom = zoom
		
		self.diffuseView.xScale = zoom
		self.diffuseView.yScale = zoom
		
		self.normalView.xScale = zoom
		self.normalView.yScale = zoom
		
		self.defaultView.xScale = zoom
		self.defaultView.yScale = zoom
		
		if onComplete then
			onComplete()
		end
	else
		transition.to(self.values, {zoom = zoom, time = zoomTime, delay = zoomDelay, transition = easing.inOutQuad, onComplete = onComplete})
		
		transition.to(self.diffuseView, {xScale = zoom, yScale = zoom, time = zoomTime, delay = zoomDelay, transition = easing.inOutQuad})
		transition.to(self.normalView, {xScale = zoom, yScale = zoom, time = zoomTime, delay = zoomDelay, transition = easing.inOutQuad})
		transition.to(self.defaultView, {xScale = zoom, yScale = zoom, time = zoomTime, delay = zoomDelay, transition = easing.inOutQuad})
	end
end

local function cameraGetZoom(self)
	return self.values.zoom
end

local function removeTouchArea(object)
	local touchArea = object.touchArea
	display.remove(touchArea)
	object.touchArea = nil
end

local function forwardAreaEvent(event)
	local touchArea = event.target
	if touchArea then
		local object = touchArea.object
		if object then
			if not rawget(object, FLAG_REMOVE) then -- Avoid sending event to destroyed one
				event.target = object
				return object:dispatchEvent(event)
			end
		end
	end
end

local function finalizeMaskedObject(event)
	local object = event.target
	
	display.remove(object.maskObject)
	object.maskObject = nil
end

local function protectedMaskInsert(self, newObject)
	self:regularInsert(newObject)
	local maskObject = self.maskObject
	
	local newMaskObject = self.buildMaskGroup(newObject, true, self.touchArea.color)
	maskObject:insert(newMaskObject)
end

local function createMaskInsert(self, newObject)
	local status, value = pcall(protectedMaskInsert, self, newObject)
	if not status then
		error("Touch object insert failed", 2)
	end
end

local function buildMaskGroup(object, internalFlag, color)
	local maskObject = nil
	
	if object.numChildren then -- Is Group
		maskObject = display.newGroup()
		for index = 1, object.numChildren do
			local childMaskObject = buildMaskGroup(object[index], true, color)
			
			maskObject:insert(childMaskObject)
		end
		
		object.regularInsert = object.insert
		object.insert = createMaskInsert
		object.buildMaskGroup = buildMaskGroup
	elseif object.path then -- ShapeObject
		local path = object.path
		
		local x = internalFlag and object.x or 0
		local y = internalFlag and object.y or 0
		
		if path.type == "rect" then
			maskObject = display.newRect(x, y, path.width, path.height)
		elseif path.type == "circle" then
			maskObject = display.newCircle(x, y, path.radius)
		elseif path.type == "roundedRect" then
			maskObject = display.newRoundedRect(x, y, path.width, path.height, path.radius)
		elseif path.type == "polygon" then
			maskObject = display.newPolygon(x, y, object.vertices)
		else -- Fallback: Mesh? TODO: implement mesh, maybe?
			maskObject = display.newRect(x, y, path.width or object.width, path.height or object.height)
		end
		
		maskObject.fill = color
		maskObject.x = x
		maskObject.y = y
		maskObject.anchorX = object.anchorX
		maskObject.anchorY = object.anchorY
		maskObject:scale(object.xScale, object.yScale)
	end
	
	object.maskObject = maskObject -- Object itself will update maskObject transform, save reference
	if internalFlag then -- Only child object need to be monitored
		local superMetaTouch = getmetatable(object)
		rawset(object, "_superMetaTouch", superMetaTouch)
		setmetatable(object, touchMonitorMetatable)
		
		object:addEventListener("finalize", finalizeMaskedObject) -- TODO: maybe add another finalize listener to maskObject?
	end
	
	return maskObject
end

local function buildTouchArea(camera, object)
	local color = (object.touchArea and object.touchArea.color) or {
		math.random(1, 4) / 4,
		math.random(1, 4) / 4,
		math.random(1, 4) / 4,
	}
	display.remove(object.touchArea)
		
	local touchArea = buildMaskGroup(object, nil, color) -- Works as intended, but can be replaced with rect + mask (Tried it but needs to save individual temp files, too much)
	touchArea.isHitTestable = true
	touchArea.alpha = 0.25
	touchArea:toFront()
	touchArea.color = color
	touchArea.object = object
	touchArea.camera = camera
	touchArea:addEventListener("tap", forwardAreaEvent)
	touchArea:addEventListener("touch", forwardAreaEvent)
	touchArea:addEventListener("mouse", forwardAreaEvent)
	camera.touchView:insert(touchArea)
	object.touchArea = touchArea
end

local function enterFrame(event) -- Do not refactor! performance is better
	for cIndex = 1, #cameras do
		if (event.frame % #cameras) == (cIndex - 1) then
			local camera = cameras[cIndex]
			
			-- Handle damping
			if camera.values.prevDamping ~= camera.values.damping then -- Damping changed
				camera.values.prevDamping = camera.values.damping
				camera.values.dampingRatio = 1 / camera.values.damping
			end
			
			-- Handle focus
			if camera.values.focus then
				targetRotation = camera.values.trackRotation and -camera.values.focus.rotation or camera.values.targetRotation
				
				-- Damp and apply rotation
				camera.diffuseView.rotation = (camera.diffuseView.rotation - (camera.diffuseView.rotation - targetRotation) * camera.values.dampingRatio)
				camera.normalView.rotation = camera.diffuseView.rotation
				camera.defaultView.rotation = camera.diffuseView.rotation
				
				-- Damp x and y
				camera.values.currentX = (camera.values.currentX - (camera.values.currentX - (camera.values.focus.x)) * camera.values.dampingRatio)
				camera.values.currentY = (camera.values.currentY - (camera.values.currentY - (camera.values.focus.y)) * camera.values.dampingRatio)
										
				-- Boundary checker TODO: support scale?
				camera.values.currentX = camera.values.minX < camera.values.currentX and camera.values.currentX or camera.values.minX
				camera.values.currentX = camera.values.maxX > camera.values.currentX and camera.values.currentX or camera.values.maxX
				camera.values.currentY = camera.values.minY < camera.values.currentY and camera.values.currentY or camera.values.minY
				camera.values.currentY = camera.values.maxY > camera.values.currentY and camera.values.currentY or camera.values.maxY
				
				-- Transform and calculate final position
				radAngle = camera.diffuseView.rotation * RADIANS_MAGIC -- Faster convert to radians
				focusRotationX = mathSin(radAngle) * camera.values.currentY
				rotationX = mathCos(radAngle) * camera.values.currentX
				finalX = (-rotationX + focusRotationX) * camera.values.zoom
				
				focusRotationY = mathCos(radAngle) * camera.values.currentY
				rotationY = mathSin(radAngle) * camera.values.currentX
				finalY = (-rotationY - focusRotationY) * camera.values.zoom
				
				-- Apply x and y
				camera.diffuseView.x = finalX
				camera.diffuseView.y = finalY

				camera.normalView.x = finalX
				camera.normalView.y = finalY
				
				camera.defaultView.x = finalX
				camera.defaultView.y = finalY
				
				-- Update rotation normal on all children
				if camera.values.trackRotation then -- Only if global rotation has significantly changed
					if (camera.diffuseView.rotation - (camera.diffuseView.rotation % 1)) ~= (targetRotation - (targetRotation % 1)) then
						for cIndex = 1, camera.diffuseView.numChildren do
							camera.diffuseView[cIndex].parentRotation = camera.diffuseView.rotation
						end
					end
				end
			end
			
			for oIndex = 1, #camera.objects do
				camera.diffuseView:insert(camera.objects[oIndex])
				camera.normalView:insert(camera.objects[oIndex].normalObject)
			end
			
			-- Prepare buffers
			camera.lightBuffer:setBackground(0) -- Clear buffers
			camera.diffuseBuffer:setBackground(0)
			camera.normalBuffer:setBackground(0)
			
			camera.diffuseBuffer:draw(camera.diffuseView)
			camera.diffuseBuffer:invalidate({accumulate = camera.values.accumulateBuffer})
			
			camera.normalBuffer:draw(camera.normalView)
			camera.normalBuffer:invalidate({accumulate = camera.values.accumulateBuffer})
			
			-- Handle light drawer pooling
			if camera.lightDrawers.numChildren ~= #camera.lights then
				local diff = #camera.lights - camera.lightDrawers.numChildren
				
				if diff > 0 then -- Create
					local vcw = camera.values.vcw or vcw
					local vch = camera.values.vch or vch
					
					for aIndex = 1, diff do 
						local lightDrawer = display.newRect(0, 0, vcw, vch)
						lightDrawer.fill = {type = "image", filename = camera.normalBuffer.filename, baseDir = camera.normalBuffer.baseDir}
						lightDrawer.fill.blendMode = "add"
						lightDrawer.fill.effect = "filter.custom.light"
						camera.lightDrawers:insert(lightDrawer)
					end
				elseif diff < 0 then -- Remove
					local target = camera.lightDrawers.numChildren + diff + 1
					for rIndex = camera.lightDrawers.numChildren, target, -1 do
						display.remove(camera.lightDrawers[rIndex])
					end
				end
			end
			
			-- Handle lights
			local vcwr = camera.values.vcwr or vcwr
			local vchr = camera.values.vchr or vchr
			
			for lIndex = #camera.lights, 1, -1 do
				local light = camera.lights[lIndex]
				
				if rawget(light, FLAG_REMOVE) then
					tableRemove(camera.lights, lIndex)
				else
					local x, y = light:localToContent(0, 0)
				
					light.position[1] = (x) * vcwr + 0.5
					light.position[2] = (y) * vchr + 0.5
					light.position[3] = light.z
					
		--			if (light.position[1] >= CULL_LIMIT_MIN) and (light.position[1] <= CULL_LIMIT_MAX) and (light.position[2] >= CULL_LIMIT_MIN) and (light.position[1] <= CULL_LIMIT_MAX) then
						local lightDrawer = camera.lightDrawers[lIndex]
						lightDrawer.fill.effect.pointLightPos = light.position
						lightDrawer.fill.effect.pointLightColor = light.color
						lightDrawer.fill.effect.attenuationFactors = light.attenuationFactors or DEFAULT_ATTENUATION
						lightDrawer.fill.effect.pointLightScale = 1 / (camera.values.zoom * light.scale * SCALE_LIGHTS) -- TODO: implement light.inverseScale -- (1 / scale)
		--			end
				end
			end
			camera.lightBuffer:draw(camera.lightDrawers)
			camera.lightBuffer:invalidate({accumulate = false})
			
			-- Handle physics bodies
			for bIndex = #camera.bodies, 1, -1 do
				local body = camera.bodies[bIndex]
				
				if rawget(body, FLAG_REMOVE) then
					tableRemove(camera.bodies, bIndex)
				else
					body.normalObject.x = body.x
					body.normalObject.y = body.y
					body.rotation = body.rotation -- This will propagate changes to normal object
				end
			end
			
			-- Handle touch objects
			for lIndex = #camera.listenerObjects, 1, -1 do
				local object = camera.listenerObjects[lIndex]
				
				if rawget(object, FLAG_REMOVE) then
					tableRemove(camera.listenerObjects, lIndex)
					
					removeTouchArea(object)
				else
					local x, y = object:localToContent(0, 0)
					
					-- Override our values
					object.touchArea.xScale = camera.values.zoom
					object.touchArea.yScale = camera.values.zoom
					object.touchArea.x = x 
					object.touchArea.y = y 
					object.touchArea.rotation = object.viewRotation
				end
			end
	
		end
	end
end

local function cameraSetBounds(self, minX, maxX, minY, maxY)
	minX = minX or -mathHuge
	maxX = maxX or mathHuge
	minY = minY or -mathHuge
	maxY = maxY or mathHuge
	
	if "boolean" == type(minX)  or minX == nil then -- Reset camera bounds
		self.values.minX, self.values.maxX, self.values.minY, self.values.maxY = -mathHuge, mathHuge, -mathHuge, mathHuge
	else
		self.values.minX, self.values.maxX, self.values.minY, self.values.maxY = minX, maxX, minY, maxY
	end
end

local function cameraToPoint(self, x, y, options)
	local tempFocus = {
		x = x or ccx,
		y = y or ccy
	}
	
	self:setFocus(tempFocus, options)
	
	return tempFocus
end

local function cameraRemoveFocus(self)
	self.values.focus = nil
end

local function cameraSetFocus(self, object, options)
	options = options or {}
	
	local trackRotation = options.trackRotation
	local soft = options.soft
	
	if object and object.x and object.y and self.values.focus ~= object then -- Valid object and is not in focus
		self.values.focus = object
		
		if not soft then
			self.values.currentX = object.x
			self.values.currentY = object.y
		end
	else
		self.values.focus = nil
	end
	
	if not soft then
		self.diffuseView.rotation = 0
		self.normalView.rotation = 0
		self.defaultView.rotation = 0
	end
	self.values.trackRotation = trackRotation
end

local function finalizeCamera(event)
	local camera = event.target
	
	for cIndex = 1, #cameras do -- FInd self and remove from camera lists
		if cameras[cIndex] == camera then
			tableRemove(cameras, camera)
			
			break
		end
	end
end

local function finalizeCameraBody(event) -- Physics
	local body = event.target
	rawset(body, FLAG_REMOVE, true)
end

local function finalizeCameraLight(event)
	local light = event.target
	rawset(light, FLAG_REMOVE, true)
end

local function finalizeTouchObject(event)
	local object = event.target
	rawset(object, FLAG_REMOVE, true)
end

local function cameraTrackBody(self, body)
	if body and body.bodyType then
		self.bodies[#self.bodies + 1] = body
		body:addEventListener("finalize", finalizeCameraBody)
	end
end

local function cameraAddBody(self, object, ...)
	if physics.addBody(object, ...) then
		self:trackBody(object)
		
		return true
	end
	return false
end

local function cameraTrackLight(self, light)
	light.camera = self
	self.lights[#self.lights + 1] = light
	
	light:addEventListener("finalize", finalizeCameraLight)
end

local function cameraNewLight(self, options)
	local light = quantum.newLight(options, self.values.debug)
	self:trackLight(light)
	
	return light
end

local function cameraAddListenerObject(self, object) -- Add tap and touch forwarder rects
	if (object.camera == self) and (not object.touchArea) then
		self.listenerObjects[#self.listenerObjects + 1] = object
		
		buildTouchArea(self, object)
		
		object:addEventListener("finalize", finalizeTouchObject) -- Remove touchArea and remove from list
	else
		return false
	end
end

local function cameraSetDrawMode(self, value)
	self.values.debug = value
	
	self.touchView.isVisible = false
	if value == "light" then
		self.canvas.fill = {type = "image", filename = self.lightBuffer.filename, baseDir = self.lightBuffer.baseDir}
	elseif value == "normal" then
		self.canvas.fill = {type = "image", filename = self.normalBuffer.filename, baseDir = self.normalBuffer.baseDir}
	elseif value == "diffuse" then
		self.canvas.fill = {type = "image", filename = self.diffuseBuffer.filename, baseDir = self.diffuseBuffer.baseDir}
	elseif value == "listeners" then
		self.touchView.isVisible = true
		self.canvas.fill = self.canvas.defaultFill -- Restore saved default fill
		self.canvas.fill.effect = "composite.custom.apply"
		self.canvas.fill.effect.ambientLightColor = self.ambientLightColor
	elseif not value then -- Default
		self.canvas.fill = self.canvas.defaultFill -- Restore saved default fill
		self.canvas.fill.effect = "composite.custom.apply"
		self.canvas.fill.effect.ambientLightColor = self.ambientLightColor
	end
	
	for lIndex = 1, #self.lights do
		self.lights[lIndex].debug.isVisible = value
	end
end

local function addCameraFramebuffers(camera)
	if camera.canvas then
		
		camera:insert(camera.diffuseView)
		camera:insert(camera.normalView)
		
		camera.diffuseBuffer:releaseSelf()
		camera.normalBuffer:releaseSelf()
		camera.lightBuffer:releaseSelf()
	end
	
	local vcw = camera.values.vcw or vcw
	local vch = camera.values.vch or vch
	
	camera.diffuseBuffer = graphics.newTexture({type = "canvas", width = vcw, height = vch})
	camera.normalBuffer = graphics.newTexture({type = "canvas", width = vcw, height = vch})
	camera.lightBuffer = graphics.newTexture({type = "canvas", width = vcw, height = vch})
	
	if not camera.canvas then
		camera.canvas = display.newRect(0, 0, vcw, vch) -- Canvas - this is what is actually shown
	else
		camera.canvas.width = vcw
		camera.canvas.height = vch
	end
	
	camera.canvas.defaultFill = { -- Save default fill
		type = "composite",
		paint1 = {type = "image", filename = camera.diffuseBuffer.filename, baseDir = camera.diffuseBuffer.baseDir},
		paint2 = {type = "image", filename = camera.lightBuffer.filename, baseDir = camera.lightBuffer.baseDir}
	}
	camera.canvas.fill = camera.canvas.defaultFill
	camera.canvas.fill.effect = "composite.custom.apply"
	camera.canvas.fill.effect.ambientLightColor = camera.ambientLightColor
end

local function initialize()
	if not initialized then
		initialized = true
		
		cameras = {}
	end
end
---------------------------------------------- Functions
function dynacam.start()
	if not isTracking then
		isTracking = true
		Runtime:addEventListener("enterFrame", enterFrame)
	end
end

function dynacam.stop()
	if isTracking then
		isTracking = false
		Runtime:removeEventListener("enterFrame", enterFrame)
	end
end

function dynacam.refresh()
	ccx = display.contentCenterX
	ccy = display.contentCenterY
	vcw = display.viewableContentWidth
	vch = display.viewableContentHeight
	
	vcwr = 1 / vcw
	vchr = 1 / vch
	
	for cIndex = 1, #cameras do
		addCameraFramebuffers(cameras[cIndex])
	end
end

function dynacam.newCamera(options)
	options = options or {}
	
	local damping = options.damping or 10
	local ambientLightColor = options.ambientLightColor or DEFAULT_AMBIENT_LIGHT
	
	local camera = display.newGroup()
	
	camera.values = {
		-- Optional size
		vcw = options.width,
		vch = options.height,
		vcwr = options.width and (1 / options.width) or nil,
		vchr = options.height and (1 / options.height) or nil,
		
		-- Camera Limits
		minX = -mathHuge,
		maxX = mathHuge,
		minY = -mathHuge,
		maxY = mathHuge,
		
		-- Camera rotation 
		targetRotation = 0,
		
		-- Damping & internal stuff
		damping = damping, -- Can be used to transition
		prevDamping = damping, -- Used to check damping changes
		dampingRatio = 1 / damping, -- Actual value used, pre divide
		currentX = 0, -- Internal
		currentY = 0, -- Internal
		
		-- Zoom
		zoom = options.zoom or 1,
		
		-- Flags
		accumulateBuffer = false,
		trackRotation = false,
		debug = false,
	}
	
	camera.diffuseView = display.newGroup()
	camera.normalView = display.newGroup()
	camera.defaultView = display.newGroup() -- Default objects will be inserted on a top layer
	camera.touchView = display.newGroup()
	
	camera.touchView.isVisible = false
	camera.touchView.isHitTestable = true
	
	camera.bodies = {}
	camera.lights = {}
	camera.objects = {}
	camera.listenerObjects = {} -- Touch & tap proxies
	camera.lightDrawers = display.newGroup()
	camera.ambientLightColor = ambientLightColor
	
	-- Frame buffers
	addCameraFramebuffers(camera)
	
	camera:insert(camera.canvas)
	camera:insert(camera.defaultView)
	camera:insert(camera.touchView)
	
	camera.add = cameraAdd
	camera.setZoom = cameraSetZoom
	camera.getZoom = cameraGetZoom
	camera.setBounds = cameraSetBounds
	
	camera.setFocus = cameraSetFocus
	camera.removeFocus = cameraRemoveFocus
	camera.toPoint = cameraToPoint
	
	camera.addListenerObject = cameraAddListenerObject
	
	camera.setDrawMode = cameraSetDrawMode
	camera.newLight = cameraNewLight
	camera.trackLight = cameraTrackLight
	camera.addBody = cameraAddBody
	camera.trackBody = cameraTrackBody
	
	camera:addEventListener("finalize", finalizeCamera)
	
	cameras[#cameras + 1] = camera
	
	return camera
end
----------------------------------------------
initialize()

return dynacam 
 