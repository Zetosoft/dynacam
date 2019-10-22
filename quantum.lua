---------------------------------------------- Quantum - Light object creation - Basilio Germán
local quantum = {}
---------------------------------------------- Constants
local DEFAULT_NORMAL = {0.5, 0.5, 1.0}
local DEFAULT_Z = 0.2

local FUNCTIONS = {
	SPRITE = {"play", "pause", "setFrame", "setSequence"},
	SNAPSHOT = {"invalidate"},
	LINE = {"append"},
	DISPLAY = {"rotate", "scale", "setMask", "toBack", "toFront", "translate", "removeSelf"},
}

local HIT_REFRESH = {
	["alpha"] = true,
	["isVisible"] = true,
	["isHitTestable"] = true,
}
---------------------------------------------- Metatables
local meshPathEntangleMetatable = { -- used to intercept mesh path functions and replicate to normal
	__index = function(self, index)
		if index == "path" then
			return self.pathFunctions
		end
		return self._oldMetaMesh.__index(self, index)
	end,
	__newindex = function(self, index, value)
		self._oldMetaMesh.__newindex(self, index, value)
	end
}

local fillProxyMetatable = { -- Used to intercept .fill transform changes and replicate to normal
	__index = function(self, index)
		return self.fill[index]
	end,
	__newindex = function(self, index, value)
		if index ~= "effect" then
			self.normalObject.fill[index] = value
		end
		
		self.fill[index] = value
	end,
}

local entangleMetatable = {
	__index = function(self, index)
		if index == "parentRotation" then -- .parent can be nil apparently when deleting object
			return self.parent and self.parent.viewRotation -- Will be nil once we hit normal objects in hierarchy
		elseif index == "fill" then
			rawset(self.fillProxy, "fill", self._oldMeta.__index(self, index)) -- Update original fill reference in proxy, skipping metamethods
			return self.fillProxy -- Fill proxy can now be modified
		elseif index == "normal" then
			return self.normalObject.fill
		elseif index == "addEventListener" then
			return self.addEventListenerPirate
		elseif index == "camera" then
			return self._camera
		end
		return self._oldMeta.__index(self, index)
	end,
	__newindex = function(self, index, value)
		local normalObject = self.normalObject
		if index == "normal" then
			if normalObject.fill then
				normalObject.fill = value
				normalObject.fill.effect = "filter.custom.rotate"
				normalObject.fill.effect.rotation = math.rad(self.viewRotation + self.fill.rotation) -- Fill might be rotated
			end
		elseif index == "parentRotation" then -- Parent is telling us to update our view rotation 
			self.viewRotation = value + self.rotation
			
			if normalObject.fill and normalObject.fill.effect then
				normalObject.fill.effect.rotation = math.rad(self.viewRotation + (self.fill.rotation or 0)) -- Fill might be rotated
			end
			
			if self.numChildren then
				for cIndex = 1, self.numChildren do
					local lightObject = self[cIndex]
					
					lightObject.parentRotation = self.viewRotation
				end
			end
		elseif index == "camera" and value then
			rawset(self, "_camera", value)
			
			if self.forwardEvents then
				value:addListenerObject(self) -- value is `_camera`
			end
			
			if self.numChildren then
				for cIndex = 1, self.numChildren do
					local lightObject = self[cIndex]
					
					lightObject.camera = value
				end
			end
		else
			normalObject[index] = value -- Send values to entangled pair
			self._oldMeta.__newindex(self, index, value)
			
			if HIT_REFRESH[index] and rawget(self, "touchArea") then
				local touchArea = rawget(self, "touchArea")
				touchArea.isHitTestable = (self.isVisible and (self.alpha > 0)) or self.isHitTestable
			end
			
			if index == "rotation" and value then -- Propagate rotation change
				-- Rotation was already set in _oldMeta
				self.viewRotation = (self.parentRotation or 0) + value -- parentRotation can be nil
				
				if self.numChildren then
					for cIndex = 1, self.numChildren do
						local lightObject = self[cIndex]
						
						lightObject.parentRotation = self.viewRotation
					end
				end
			end
		end
	end,
}
---------------------------------------------- Caches
local tableRemove = table.remove
---------------------------------------------- Constants
---------------------------------------------- Local functions
local function finalizeEntangledObject(event)
	local lightObject = event.target
	
	display.remove(lightObject.normalObject)
	lightObject.normalObject = nil
end

local function entangleFunction(object, functionIndex)
	local originalFunction = object[functionIndex]
	
	object["_"..functionIndex] = originalFunction
	rawset(object, functionIndex, function(self, ...)
		self["_"..functionIndex](self, ...)
		self.normalObject[functionIndex](self.normalObject, ...)
	end)
end

local function addEventListenerPirate(self, eventName, eventFunction) -- Metatable called function
	if eventName == "tap" or eventName == "touch" or eventName == "mouse" then
		if self.camera then
			self.camera:addListenerObject(self)
		else
			self.forwardEvents = true
		end
	end
	return self._oldMeta.__index(self, "addEventListener")(self, eventName, eventFunction)
end

local function entangleObject(lightObject) -- Basic light object principle, where we make object pairs in different worlds (diffuse & normal)
	lightObject.viewRotation = 0
	
	lightObject.fillProxy = setmetatable({ -- Fill proxy is used to forward fill property changes to normal object
		normalObject = lightObject.normalObject,
		fill = nil, -- Is set during metatable query
	}, fillProxyMetatable)
	
	for fIndex = 1, #FUNCTIONS.DISPLAY do
		entangleFunction(lightObject, FUNCTIONS.DISPLAY[fIndex])
	end
	
	lightObject.addEventListenerPirate = addEventListenerPirate
	
	rawset(lightObject, "_oldMeta", getmetatable(lightObject))
	setmetatable(lightObject, entangleMetatable)
	
	lightObject:addEventListener("finalize", finalizeEntangledObject)
end

local function lightInsert(self, lightObject)
	self:diffuseInsert(lightObject)
	self.normalObject:insert(lightObject.normalObject)
	
	lightObject.camera = self.camera
	
	lightObject.parentRotation = self.viewRotation -- Let metatable update efefct
end
---------------------------------------------- Module functions
function quantum.newLight(options) -- Only meant to be used internally by dynacam, or will fail to be updated
	options = options or {}
	
	local z = options.z or DEFAULT_Z
	local color = options.color or {1, 1, 1, 1} -- New instance of white
	local scale = options.scale or 1
	local attenuationFactors = options.attenuationFactors or {0.4, 3, 20} -- Default attenuation here as we don't have table copy
	
	local light = display.newGroup()
	light.normalObject = display.newGroup()
	
	light.debug = display.newCircle(light, 0, 0, 5)
	light.debug.isVisible = options.debug
	
	entangleObject(light)
	
	light.position = {0, 0, z} -- Internal table, auto updates for fast shader data pass
	light.scale = scale
	light.z = z
	light.attenuationFactors = attenuationFactors
	light.color = color
	
	return light
end

function quantum.newGroup()
	local lightGroup = display.newGroup()
	lightGroup.normalObject = display.newGroup()
	
	lightGroup.diffuseInsert = lightGroup.insert
	lightGroup.insert = lightInsert
	
	entangleObject(lightGroup)
	
	return lightGroup
end

function quantum.newCircle(x, y, radius)
	local lightCircle = display.newCircle(x, y, radius)
	local normalCircle = display.newCircle(x, y, radius)
	
	return quantum.newLightObject(lightCircle, normalCircle)
end

function quantum.newContainer(width, height)
	local lightContainer = display.newContainer(width, height)
	lightContainer.normalObject = display.newContainer(width, height)
	
	lightContainer.diffuseInsert = lightContainer.insert
	lightContainer.insert = lightInsert
	
	entangleObject(lightContainer)
	
	return lightContainer
end

function quantum.newImage(filename, normalFilename, baseDir)
	baseDir = baseDir or system.ResourceDirectory

	local lightImage = display.newImage(filename, baseDir)
	local normalImage = display.newImage(normalFilename, baseDir)
	
	return quantum.newLightObject(lightImage, normalImage)
end

function quantum.newImageRect(filename, normalFilename, baseDir, width, height)
	baseDir = baseDir or system.ResourceDirectory
	
	local lightImageRect = display.newImageRect(filename, baseDir, width, height)
	local normalImageRect = display.newImageRect(normalFilename, baseDir, width, height)
	
	return quantum.newLightObject(lightImageRect, normalImageRect)
end

function quantum.newLine(...)
	local lightLine = display.newLine(...)
	local normalLine = display.newLine(...)
	normalLine:setStrokeColor(unpack(DEFAULT_NORMAL)) -- Normal vector facing up
	
	return quantum.newLightObject(lightLine, normalLine, FUNCTIONS.LINE)
end

function quantum.newMesh(options)
	local lightMesh = display.newMesh(options)
	local normalMesh = display.newMesh(options)
	
	lightMesh.pathFunctions = {
		type = "mesh",
		path = lightMesh.path,
		normalPath = normalMesh.path,
		
		setVertex = function(self, index, x, y)
			self.path:setVertex(index, x, y)
			self.normalPath:setVertex(index, x, y)
		end,
		getVertex = function(self, index)
			return self.path:getVertex(index)
		end,
		setUV= function(self, index, u, v)
			self.path:setUV(index, u, v)
			self.normalPath:setUV(index, u, v)
		end,
		getUV = function(self, index)
			return self.path:getUV(index)
		end,
		getVertexOffset = function(self)
			return self.path:getVertexOffset()
		end
	}
	
	normalMesh.fill.effect = "filter.custom.rotate"
	
	lightMesh.normalObject = normalMesh
	entangleObject(lightMesh)
	
	rawset(lightMesh, "_oldMetaMesh", getmetatable(lightMesh))
	setmetatable(lightMesh, meshPathEntangleMetatable)
	
	return lightMesh
end

function quantum.newPolygon(x, y, vertices)
	local lightPolygon = display.newPolygon(x, y, vertices)
	local normalPolygon = display.newPolygon(x, y, vertices)
	
	lightPolygon.vertices = vertices -- Save vertices in case of touch listener mask rebuild
	
	return quantum.newLightObject(lightPolygon, normalPolygon)
end

function quantum.newRoundedRect(x, y, width, height, cornerRadius)
	local lightRoundedRect = display.newRoundedRect(x, y, width, height, cornerRadius)
	local normalRoundedRect = display.newRoundedRect(x, y, width, height, cornerRadius)
	
	return quantum.newLightObject(lightRoundedRect, normalRoundedRect)
end

function quantum.newSnapshot(width, height)
	local lightSnapshot = display.newSnapshot(width, height)
	local normalSnapshot = display.newSnapshot(width, height)
	
	lightSnapshot.diffuseInsert = lightSnapshot.insert
	lightSnapshot.insert = lightInsert
	
	return quantum.newLightObject(lightSnapshot, normalSnapshot, FUNCTIONS.SNAPSHOT)
end

function quantum.newText(options)
	options = options or {}
	local normal = options.normal or {0.5, 0.5, 1.0}
	
	local lightText = display.newText(options)
	local normalText = display.newText(options)
	normalText.fill = normal
	
	lightText.normalObject = normalText
	entangleObject(lightText)
	
	return lightText
end

function quantum.newRect(x, y, width, height)
	local lightRect = display.newRect(x, y, width, height)
	local normalRect = display.newRect(x, y, width, height)
	
	return quantum.newLightObject(lightRect, normalRect)
end

function quantum.newSprite(diffuseSheet, normalSheet, sequenceData)
	local lightSprite = display.newSprite(diffuseSheet, sequenceData)
	local normalSprite = display.newSprite(normalSheet, sequenceData)
	
	return quantum.newLightObject(lightSprite, normalSprite, FUNCTIONS.SPRITE)
end

-- Used internally to create lightObjects
function quantum.newLightObject(diffuseObject, normalObject, entangleFunctions)
	entangleFunctions = entangleFunctions or {}
	diffuseObject.normalObject = normalObject
	
	for fIndex = 1, #entangleFunctions do
		entangleFunction(diffuseObject, entangleFunctions[fIndex])
	end
	
	if normalObject.fill then
		normalObject.fill.effect = "filter.custom.rotate"
	end
	
	entangleObject(diffuseObject)
	
	return diffuseObject
end

return quantum