---------------------------------------------- Dynacam - Dynamic Lighting Camera System - Basilio Germán
local moduleParams = ...
local moduleName = moduleParams.name or moduleParams
local requirePath = moduleParams.path or ""
local projectPath = string.gsub(requirePath, "%.", "/")

require(requirePath.."shaders.rotate")
require(requirePath.."shaders.apply")
require(requirePath.."shaders.light")

local quantum = require(requirePath.."quantum")
local physics = require("physics")

local dynacam = setmetatable({}, { -- Quantum provides object creation
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
---------------------------------------------- Constants
local RADIANS_MAGIC = math.pi / 180 -- Used to convert degrees to radians
local DEFAULT_ATTENUATION = {0.4, 3, 20}
local DEFAULT_AMBIENT_LIGHT = {0, 0, 0, 1}
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
---------------------------------------------- Local functions 
local function cameraAdd(self, lightObject, isFocus)
	if lightObject.normalObject then -- Only lightObjects have a normalObject property
		if isFocus then
			self.values.focus = lightObject
		end
		
		lightObject.camera = self
		
		self.diffuseView:insert(lightObject)
		self.normalView:insert(lightObject.normalObject)
	end
end

local function cameraSetZoom(self, zoomLevel, zoomDelay, zoomTime, onComplete)
	zoomLevel = zoomLevel or 1
	zoomDelay = zoomDelay or 0
	zoomTime = zoomTime or 500
	self.values.zoom = zoomLevel
	self.values.zoomMultiplier = 1 / zoomLevel
	local targetScale = (1 - zoomLevel) * 0.5
	
	transition.cancel(self)
	if zoomDelay <= 0 and zoomTime <= 0 then
		self.diffuseView.xScale = zoomLevel
		self.diffuseView.yScale = zoomLevel
		
		self.diffuseView.x = vcw * targetScale
		self.diffuseView.y = vch * targetScale
		
		if onComplete then
			onComplete()
		end
	else
		local x = vcw * targetScale
		local y = vch * targetScale
		
		transition.to(self.diffuseView, {xScale = zoomLevel, yScale = zoomLevel, x = x, y = y, time = zoomTime, delay = zoomDelay, transition = easing.inOutQuad, onComplete = onComplete})
	end
end

local function cameraGetZoom(self)
	return self.values.zoom
end

local function cameraEnterFrame(self, event) 
	-- Handle damping
	if self.values.prevDamping ~= self.values.damping then -- Damping changed
		self.values.prevDamping = self.values.damping
		self.values.dampingRatio = 1 / self.values.damping
	end
	
	-- Handle focus
	if self.values.focus then
		targetRotation = self.values.trackRotation and -self.values.focus.rotation or self.rotation
		
		-- Damp and apply rotation
		self.diffuseView.rotation = (self.diffuseView.rotation - (self.diffuseView.rotation - targetRotation) * self.values.dampingRatio)
		self.normalView.rotation = self.diffuseView.rotation
		
		-- Damp x and y
		self.values.currentX = (self.values.currentX - (self.values.currentX - (self.values.focus.x)) * self.values.dampingRatio)
		self.values.currentY = (self.values.currentY - (self.values.currentY - (self.values.focus.y)) * self.values.dampingRatio)
								
		-- Boundary checker TODO: support scale
		self.values.currentX = self.values.minX < self.values.currentX and self.values.currentX or self.values.minX
		self.values.currentX = self.values.maxX > self.values.currentX and self.values.currentX or self.values.maxX
		self.values.currentY = self.values.minY < self.values.currentY and self.values.currentY or self.values.minY
		self.values.currentY = self.values.maxY > self.values.currentY and self.values.currentY or self.values.maxY
		
		-- Transform and calculate final position
		radAngle = self.diffuseView.rotation * RADIANS_MAGIC -- Faster convert to radians
		focusRotationX = mathSin(radAngle) * self.values.currentY
		rotationX = mathCos(radAngle) * self.values.currentX
		finalX = -rotationX + focusRotationX
		
		focusRotationY = mathCos(radAngle) * self.values.currentY
		rotationY = mathSin(radAngle) * self.values.currentX
		finalY = -rotationY - focusRotationY
		
		-- Apply x and y
		self.diffuseView.x = finalX
		self.diffuseView.y = finalY
		
		-- Replicate transforms on normalView
		self.normalView.x = self.diffuseView.x
		self.normalView.y = self.diffuseView.y
		
		-- Update rotation on all children
		if self.values.trackRotation then
			if (self.diffuseView.rotation - (self.diffuseView.rotation % 1)) ~= (targetRotation - (targetRotation % 1)) then
				for cIndex = 1, self.diffuseView.numChildren do
					self.diffuseView[cIndex].parentRotation = self.diffuseView.rotation
				end
			end
		end
	end
	
	-- Prepare buffers
	self.lightBuffer:setBackground(0) -- Clear buffers
	self.diffuseBuffer:setBackground(0)
	
	self.diffuseBuffer:draw(self.diffuseView)
	self.diffuseBuffer:invalidate({accumulate = self.values.accumulateBuffer})
	
	self.normalBuffer:draw(self.normalView)
	self.normalBuffer:invalidate({accumulate = self.values.accumulateBuffer})
	
	-- Handle lights
	for lIndex = 1, #self.lightDrawers do
		display.remove(self.lightDrawers[lIndex])
	end
	
	for lIndex = 1, #self.lights do
		local light = self.lights[lIndex]
		
		local x, y = light:localToContent(0, 0)
		
		light.position[1] = (x) * vcwr + 0.5
		light.position[2] = (y) * vchr + 0.5
		light.position[3] = light.z
		
		local lightDrawer = display.newRect(0, 0, vcw, vch)
		lightDrawer.fill = {type = "image", filename = self.normalBuffer.filename, baseDir = self.normalBuffer.baseDir}
		lightDrawer.fill.blendMode = "add"
		lightDrawer.fill.effect = "filter.custom.light"
		lightDrawer.fill.effect.pointLightPos = light.position
		lightDrawer.fill.effect.pointLightColor = light.color
		lightDrawer.fill.effect.attenuationFactors = light.attenuationFactors or DEFAULT_ATTENUATION
		
		self.lightBuffer:draw(lightDrawer)
		
		self.lightDrawers[lIndex] = lightDrawer
	end
	self.lightBuffer:invalidate({accumulate = false})
	
	-- Handle physics bodies
	for bIndex = 1, #self.bodies do
		self.bodies[bIndex].normalObject.x = self.bodies[bIndex].x
		self.bodies[bIndex].normalObject.y = self.bodies[bIndex].y
		self.bodies[bIndex].rotation = self.bodies[bIndex].rotation -- This will propagate changes to normal object
	end
	
	-- Handle touch objects
	for tIndex = 1, #self.listenerObjects do
		local object = self.listenerObjects[tIndex]
		
		local x, y = object:localToContent(0, 0)
		object.touchArea.x = x
		object.touchArea.y = y
		object.touchArea.rotation = object.viewRotation
	end
end

local function cameraStart(self)
	if not self.values.isTracking then
		self.values.isTracking = true
		Runtime:addEventListener("enterFrame", self)
	end
end

local function cameraStop(self)
	if self.values.isTracking then
		Runtime:removeEventListener("enterFrame", self)
		self.values.isTracking = false
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
	
	self:stop()
	self:setFocus(tempFocus, options)
	self:start()
	
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
	end
	self.values.trackRotation = trackRotation
end

local function finalizeCamera(event)
	local camera = event.target
	if camera.values.isTracking then
		Runtime:removeEventListener("enterFrame", camera)
	end
end

local function removeObjectFromTable(table, object)
	if table and "table" == type(table) then
		for index = #table, 1, -1 do
			if object == table[index] then
				tableRemove(table, index) -- Used as it re indexes table
				return true
			end
		end
	end
	return
end

local function finalizeCameraBody(event) -- Physics
	local body = event.target
	local camera = body.camera
	
	removeObjectFromTable(camera.bodies, body)
end

local function finalizeCameraLight(event)
	local light = event.target
	local camera = light.camera
	
	removeObjectFromTable(camera.lights, light)
end

local function cameraAddBody(self, object, ...)
	if physics.addBody(object, ...) then
		object:addEventListener("finalize", finalizeCameraBody)
		
		self.bodies[#self.bodies + 1] = object
		
		return true
	end
	return false
end

local function cameraNewLight(self, options)
	if self.values.debug then
		options.debug = true
	end
	
	local light = quantum.newLight(options)
	light.camera = self
	light:addEventListener("finalize", finalizeCameraLight)
	
	self.lights[#self.lights + 1] = light
	
	return light
end

local function forwardAreaEvent(event)
	local touchArea = event.target
	local object = touchArea.object
	
	event.target = object
	return object:dispatchEvent(event)
end

local function buildMaskGroup(object)
	local maskGroup = display.newGroup()
	
	if object.numChildren then
		for index = 1, object.numChildren do
			local childMaskGroup = buildMaskGroup(object[index])
			
			maskGroup:insert(childMaskGroup)
		end
	elseif object.path then
		local path = object.path
		
		if path.type == "rect" then
			local maskObject = display.newRect(object.x, object.y, path.width, path.height)
			maskObject.anchorX = object.anchorX
			maskObject.anchorY = object.anchorY
			maskObject:scale(object.xScale, object.yScale)
			maskGroup:insert(maskObject)
		elseif path.type == "circle" then
			local maskObject = display.newCircle(object.x, object.y, path.radius)
			maskObject.anchorX = object.anchorX
			maskObject.anchorY = object.anchorY
			maskObject:scale(object.xScale, object.yScale)
			maskGroup:insert(maskObject)
		elseif path.type == "" then
			
		end
	end
	
	return maskGroup
end

local function cameraAddListenerObject(self, object) -- Add tap and touch forwarder rects
	self.listenerObjects[#self.listenerObjects + 1] = object
	
	local touchArea = buildMaskGroup(object)
	touchArea.alpha = 0.5
	touchArea:toFront()
	touchArea.object = object
	touchArea:addEventListener("tap", forwardAreaEvent)
	touchArea:addEventListener("touch", forwardAreaEvent)
	self.touchView:insert(touchArea)
	object.touchArea = touchArea
end

local function cameraSetDebug(self, value)
	self.values.debug = value
	
	if value == "light" then
		self.canvas.fill = {type = "image", filename = self.lightBuffer.filename, baseDir = self.lightBuffer.baseDir}
	elseif value == "normal" then
		self.canvas.fill = {type = "image", filename = self.normalBuffer.filename, baseDir = self.normalBuffer.baseDir}
	elseif not value then
		self.canvas.fill = self.canvas.defaultFill -- Restore saved default fill
		self.canvas.fill.effect = "composite.custom.apply"
		self.canvas.fill.effect.ambientLightColor = self.ambientLightColor
	end
	
	for lIndex = 1, #self.lights do
		self.lights[lIndex].debug.isVisible = value
	end
end
---------------------------------------------- Functions
function dynacam.refresh()
	ccx = display.contentCenterX
	ccy = display.contentCenterY
	vcw = display.viewableContentWidth
	vch = display.viewableContentHeight
	
	vcwr = 1 / vcw
	vchr = 1 / vch
end

function dynacam.newCamera(options)
	options = options or {}
	
	local damping = options.damping or 10
	local zoomMultiplier = options.zoomMultiplier or 1
	local ambientLightColor = options.ambientLightColor or DEFAULT_AMBIENT_LIGHT
	
	local camera = display.newGroup()
	
	camera.values = {
		-- Camera Limits
		minX = -mathHuge,
		maxX = mathHuge,
		minY = -mathHuge,
		maxY = mathHuge,
		
		-- Damping & internal stuff
		damping = damping, -- Can be used to transition
		prevDamping = damping, -- Used to check damping changes
		dampingRatio = 1 / damping, -- Actual value used, pre divide
		currentX = 0, -- Internal
		currentY = 0, -- Internal
		
		-- Zoom
		zoom = options.zoom or 1,
		zoomMultiplier = options.zoomMultiplier or 1,
		
		-- Flags
		accumulateBuffer = false,
		trackRotation = false,
		isTracking = false,
		debug = false,
	}
	
	camera.diffuseView = display.newGroup()
	camera.normalView = display.newGroup()
	camera.touchView = display.newGroup()
	
	-- Frame buffers
	camera.diffuseBuffer = graphics.newTexture({type = "canvas", width = vcw, height = vch})
	camera.normalBuffer = graphics.newTexture({type = "canvas", width = vcw, height = vch})
	camera.lightBuffer = graphics.newTexture({type = "canvas", width = vcw, height = vch})
	
	camera.bodies = {}
	camera.lights = {}
	camera.listenerObjects = {} -- Touch & tap proxies
	camera.lightDrawers = {}
	camera.ambientLightColor = ambientLightColor
	
	-- Canvas - this is what is actually shown
	local canvas = display.newRect(0, 0, vcw, vch)
	canvas.defaultFill = { -- Save default fill
		type = "composite",
		paint1 = {type = "image", filename = camera.diffuseBuffer.filename, baseDir = camera.diffuseBuffer.baseDir},
		paint2 = {type = "image", filename = camera.lightBuffer.filename, baseDir = camera.lightBuffer.baseDir}
	}
	canvas.fill = canvas.defaultFill
	canvas.fill.effect = "composite.custom.apply"
	canvas.fill.effect.ambientLightColor = ambientLightColor
	
	camera.canvas = canvas
	camera:insert(camera.canvas)
	camera:insert(camera.touchView)
	
	camera.add = cameraAdd
	camera.setZoom = cameraSetZoom
	camera.getZoom = cameraGetZoom
	camera.enterFrame = cameraEnterFrame
	camera.start = cameraStart
	camera.stop = cameraStop
	camera.setBounds = cameraSetBounds
	
	camera.setFocus = cameraSetFocus
	camera.removeFocus = cameraRemoveFocus
	camera.toPoint = cameraToPoint
	
	camera.addListenerObject = cameraAddListenerObject
	
	camera.setDebug = cameraSetDebug
	camera.newLight = cameraNewLight
	camera.addBody = cameraAddBody
	
	camera:addEventListener("finalize", finalizeCamera)
	
	return camera
end

return dynacam 
 
