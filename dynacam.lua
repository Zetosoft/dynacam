---------------------------------------------- Dynacam - Dynamic Lighting Camera System - Basilio Germán
local sceneParams = ...
local sceneName = sceneParams.name or sceneParams
local requirePath = sceneParams.path or ""
local projectPath = string.gsub(requirePath, "%.", "/")

require(requirePath.."shaders.rotate")
require(requirePath.."shaders.apply")
require(requirePath.."shaders.light")

local dynacam = {}
---------------------------------------------- Variables
local targetRotation, focusAngle
local otherRotationX, otherRotationY
local rotationX, rotationY
local finalX, finalY
---------------------------------------------- Constants
local RADIANS_MAGIC = 0.0174532925 -- Used to convert degrees to radians (pi / 180)
---------------------------------------------- Cache
local mathAbs = math.abs
local mathHuge = math.huge
local mathCos = math.cos
local mathSin = math.sin

local ccx = display.contentCenterX
local ccy = display.contentCenterY
local vcw = display.viewableContentWidth
local vch = display.viewableContentHeight

local display = display
local easing = easing
local transition = transition
---------------------------------------------- Metatables
local entangleMetatable = {
	__index = function(self, index)
		if index == "parentRotation" then
			return self.parent.viewRotation -- Will be nil once we hit normal objects in hierarchy
		end
		return self._oldMeta.__index(self, index)
	end,
	__newindex = function(self, index, value)
		local normalObject = self.normalObject
		if index == "normal" then
			if normalObject.fill then
				normalObject.fill = value
				normalObject.fill.effect = "filter.custom.rotate"
				normalObject.fill.effect.rotation = math.rad(self.viewRotation)
			end
		elseif index == "parentRotation" then -- Parent is telling us to update our view rotation 
			self.viewRotation = value + self.rotation
			
			if normalObject.fill then
				normalObject.fill.effect.rotation = math.rad(self.viewRotation)
			end
			
			if self.isLightGroup then
				for cIndex = 1, self.numChildren do
					local lightObject = self[cIndex]
					
					lightObject.parentRotation = self.viewRotation
				end
			end
		else
			normalObject[index] = value -- Send values to entangled pair
			self._oldMeta.__newindex(self, index, value)
			
			if index == "rotation" then -- Propagate rotation change
				-- Rotation was already set in _oldMeta
				self.viewRotation = (self.parentRotation or 0) + value -- parentRotation can be nil
				
				if self.isLightGroup then
					for cIndex = 1, self.numChildren do
						local lightObject = self[cIndex]
						
						lightObject.parentRotation = self.viewRotation
					end
				end
			end
		end
	end,
}
---------------------------------------------- Local functions part 2
local function cameraAdd(self, lightObject, isFocus)
	if lightObject.normalObject then -- Only lightObjects have a normalObject property
		if isFocus then
			self.values.focus = lightObject
		end
		
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
		self.xScale = zoomLevel
		self.yScale = zoomLevel
		self.x = self.values.x + display.viewableContentWidth * targetScale
		self.y = self.values.y + display.viewableContentHeight * targetScale
		
		if onComplete then
			onComplete()
		end
	else
		transition.to(self, {xScale = zoomLevel, yScale = zoomLevel, x = self.values.x + vcw * targetScale, y = self.values.y + vch * targetScale, time = zoomTime, delay = zoomDelay, transition = easing.inOutQuad, onComplete = onComplete})
	end
end

local function cameraGetZoom(self)
	return self.values.zoom
end

local function cameraEnterFrame(self, event)
	-- Handle damping
	if self.values.prevDamping ~= self.damping then
		self.values.prevDamping = self.damping
		self.values.damping = 1 / self.damping
	end
	
	-- Handle focus
	if self.values.focus then
		self.scrollX, self.scrollY = self.diffuseView.x, self.diffuseView.y
					
		targetRotation = self.values.trackRotation and -self.values.focus.rotation or self.values.defaultRotation
		
		self.diffuseView.rotation = (self.diffuseView.rotation - (self.diffuseView.rotation - targetRotation) * self.values.damping)

		focusAngle = self.diffuseView.rotation * RADIANS_MAGIC
		
		self.values.targetX = (self.values.targetX - (self.values.targetX - (self.values.focus.x)) * self.values.damping)
		self.values.targetY = (self.values.targetY - (self.values.targetY - (self.values.focus.y)) * self.values.damping)
								
		self.values.targetX = self.values.x1 < self.values.targetX and self.values.targetX or self.values.x1
		self.values.targetX = self.values.x2 > self.values.targetX and self.values.targetX or self.values.x2
		
		self.values.targetY = self.values.y1 < self.values.targetY and self.values.targetY or self.values.y1
		self.values.targetY = self.values.y2 > self.values.targetY and self.values.targetY or self.values.y2
		
		otherRotationX = mathSin(focusAngle) * self.values.targetY
		rotationX = mathCos(focusAngle) * self.values.targetX
		finalX = -rotationX + otherRotationX
		
		otherRotationY = mathCos(focusAngle) * self.values.targetY
		rotationY = mathSin(focusAngle) * self.values.targetX
		finalY = -rotationY - otherRotationY
		
		self.diffuseView.x = finalX
		self.diffuseView.y = finalY
		
		-- Replicate transforms on normalView
		self.normalView.x = self.diffuseView.x
		self.normalView.y = self.diffuseView.y
		self.normalView.rotation = self.diffuseView.rotation
		
		-- Update rotation on all normals
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
	self.diffuseBuffer:invalidate({accumulate = false})
	
	self.normalBuffer:draw(self.normalView)
	self.normalBuffer:invalidate({accumulate = false})
	
	-- Handle lights
	for lIndex = 1, #self.lightDrawers do
		display.remove(self.lightDrawers[lIndex])
	end
	
	for lIndex = 1, #self.lights do
		local light = self.lights[lIndex]
		
		local x, y = light:localToContent(0, 0)
		
		light.position[1] = (x) / vcw + 0.5
		light.position[2] = (y) / vch + 0.5
		light.position[3] = light.z
		
		local lightDrawer = display.newRect(0, 0, vcw, vch)
		lightDrawer.fill = {type = "image", filename = self.normalBuffer.filename, baseDir = self.normalBuffer.baseDir}
		lightDrawer.fill.blendMode = "add"
		lightDrawer.fill.effect = "filter.custom.light"
		
		lightDrawer.fill.effect.pointLightPos = light.position
		lightDrawer.fill.effect.pointLightColor = light.color
		
		self.lightBuffer:draw(lightDrawer)
		
		self.lightDrawers[lIndex] = lightDrawer
	end
	self.lightBuffer:invalidate({accumulate = false})
	
	-- Handle physics bodies
	for pIndex = 1, #self.bodies do
		
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

local function cameraSetBounds(self, x1, x2, y1, y2)
	x1 = x1 or -mathHuge
	x2 = x2 or mathHuge
	y1 = y1 or -mathHuge
	y2 = y2 or mathHuge
	
	if "boolean" == type(x1)  or x1 == nil then -- Reset camera bounds
		self.values.x1, self.values.x2, self.values.y1, self.values.y2 = -mathHuge, mathHuge, -mathHuge, mathHuge
	else
		self.values.x1, self.values.x2, self.values.y1, self.values.y2 = x1, x2, y1, y2
	end
end

local function cameraSetPosition(self, x, y)
	self.values.x = x
	self.values.y = y
	self.x = x
	self.y = y
end

local function cameraPlaySound(self, soundID, x, y) -- TODO could add zoom precision
	local leftX = self.values.targetX - vcw * 0.5
	local rightX = self.values.targetX + vcw * 0.5
	
	local topY = self.values.targetY - vch * 0.5
	local bottomY = self.values.targetY + vch * 0.5
	
	if x > leftX and x < rightX then
		if y < topY and y > bottomY then
			sound.play(soundID)
		end
	end
end

local function cameraToPoint(self, x, y, options)
	x = x or ccx
	y = y or ccy
	
	self:stop()
	local tempFocus = {x = x, y = y}
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
	
	if object and object.x and object.y and self.values.focus ~= object then
		self.values.focus = object
		
		if not soft then
			self.values.targetX = object.x
			self.values.targetY = object.y
		end
	else
		self.values.focus = nil
	end
	
	self.values.defaultRotation = 0 --Reset rotation
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

local function finalizeLightObject(event)
	local lightObject = event.target
	display.remove(lightObject.normalObject)
end

local function entangleObject(lightObject)
	lightObject.viewRotation = 0
	
	rawset(lightObject, "_oldMeta", getmetatable(lightObject))
	setmetatable(lightObject, entangleMetatable)
	
	lightObject:addEventListener("finalize", finalizeLightObject)
end

local function lightGroupInsert(self, lightObject)
	self:oldInsert(lightObject)
	self.normalObject:insert(lightObject.normalObject)
	
	lightObject.parentRotation = self.viewRotation -- Let metatable update efefct
end

local function cameraNewLight(self, options)
	options = options or {}
	
	local color = options.color or {1, 1, 1, 1}
	
	local light = display.newGroup()
	light.normalObject = display.newGroup()
	
	display.newCircle(light, 0, 0, 5) -- Debug view
	
	entangleObject(light)
	
	light.position = {0, 0, 0.2} -- Auto updates for fast shader data pass
	light.z = 0.2
	light.color = color
	light.isLight = true
	
	self.lights[#self.lights + 1] = light
	
	return light
end
---------------------------------------------- Functions
function dynacam.refresh()
	ccx = display.contentCenterX
	ccy = display.contentCenterY
	vcw = display.viewableContentWidth
	vch = display.viewableContentHeight
end

function dynacam.newSprite(diffuseSheet, normalSheet, sequenceData)
	local diffuseSprite = display.newSprite(diffuseSheet, sequenceData)
	local normalSprite = display.newSprite(normalSheet, sequenceData)
	
	diffuseSprite.oldPlay = diffuseSprite.play
	diffuseSprite.oldPause = diffuseSprite.pause
	diffuseSprite.oldSetFrame = diffuseSprite.setFrame
	diffuseSprite.oldSetSequence = diffuseSprite.setSequence
	
	diffuseSprite.play = function(self, ...)
		self:oldPlay(...)
		self.normalObject:play(...)
	end
	
	diffuseSprite.pause = function(self, ...)
		self:oldPause(...)
		self.normalObject:pause(...)
	end
	
	diffuseSprite.setFrame = function(self, ...)
		self:oldSetFrame(...)
		self.normalObject:setFrame(...)
	end
	
	diffuseSprite.setSequence = function(self, ...)
		self:oldSetSequence(...)
		self.normalObject:setSequence(...)
	end
	
	normalSprite.fill.effect = "filter.custom.rotate"
	
	diffuseSprite.normalObject = normalSprite
	entangleObject(diffuseSprite)
	
	return diffuseSprite
end

function dynacam.newRect(x, y, width, height)
	local diffuseRect = display.newRect(x, y, width, height)
	local normalRect = display.newRect(x, y, width, height)
	
	normalRect.fill.effect = "filter.custom.rotate"
	
	diffuseRect.normalObject = normalRect
	entangleObject(diffuseRect)
	
	return diffuseRect
end

function dynacam.newGroup()
	local diffuseGroup = display.newGroup()
	diffuseGroup.normalObject = display.newGroup()
	
	diffuseGroup.isLightGroup = true
	
	diffuseGroup.oldInsert = diffuseGroup.insert
	diffuseGroup.insert = lightGroupInsert
	
	entangleObject(diffuseGroup)
	
	return diffuseGroup
end

function dynacam.newCamera(options)
	options = options or {}
	
	local camera = display.newGroup()
	camera.scrollX = options.x or 0
	camera.scrollY = options.y or 0
	camera.damping = options.damping or 10
	
	camera.values = {
		x1 = -mathHuge,
		x2 = mathHuge,
		y1 = -mathHuge,
		y2 = mathHuge,
		prevDamping = options.damping or 10,
		damping = 0.1,
		zoom = options.zoom or 1,
		zoomMultiplier = options.zoomMultiplier or 1,
		defaultRotation = options.defaultRotation or 0,
		x = options.x or 0,
		y = options.y or 0,
		
		trackRotation = false,
		isTracking = false,
	}
	
	camera.diffuseView = display.newGroup()
	camera.normalView = display.newGroup()
	
	-- Frame buffers
	camera.diffuseBuffer = graphics.newTexture({type = "canvas", width = vcw, height = vch})
	camera.normalBuffer = graphics.newTexture({type = "canvas", width = vcw, height = vch})
	camera.lightBuffer = graphics.newTexture({type = "canvas", width = vcw, height = vch})
	
	camera.bodies = {}
	camera.lights = {}
	camera.lightDrawers = {}
	
	-- Canvas - this is what is actually shown
	local canvas = display.newRect(0, 0, vcw, vch)
	canvas.fill = {
		type = "composite",
		paint1 = {type = "image", filename = camera.diffuseBuffer.filename, baseDir = camera.diffuseBuffer.baseDir},
		paint2 = {type = "image", filename = camera.lightBuffer.filename, baseDir = camera.lightBuffer.baseDir}
	}
	canvas.fill.effect = "composite.custom.apply"
	canvas.fill.effect.ambientLightColor = {0, 0, 0, 1}
	
	if options.debug then
		canvas.fill = {type = "image", filename = camera.normalBuffer.filename, baseDir = camera.normalBuffer.baseDir}
	end
	
	camera.canvas = canvas
	camera:insert(camera.canvas)
	
	camera.add = cameraAdd
	camera.setZoom = cameraSetZoom
	camera.getZoom = cameraGetZoom
	camera.enterFrame = cameraEnterFrame
	camera.start = cameraStart
	camera.stop = cameraStop
	camera.setBounds = cameraSetBounds
	camera.setPosition = cameraSetPosition
	camera.playSound = cameraPlaySound
	camera.toPoint = cameraToPoint
	camera.removeFocus = cameraRemoveFocus
	camera.setFocus = cameraSetFocus
	
	camera.debug = options.debug
	camera.newLight = cameraNewLight

	camera:addEventListener("finalize", finalizeCamera)
	
	return camera
end

return dynacam 
 
