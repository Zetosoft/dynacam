---------------------------------------------- Quantum - Light object creation - Basilio Germán
local quantum = {}
---------------------------------------------- Constants
local DEFAULT_ATTENUATION = {0.4, 3, 20}
local DEFAULT_COLOR = {1, 1, 1, 1}
local DEFAULT_Z = 0.2
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
		if index == "parentRotation" then
			return self.parent.viewRotation -- Will be nil once we hit normal objects in hierarchy
		elseif index == "fill" then
			rawset(self.fillProxy, "fill", self._oldMeta.__index(self, index)) -- Update original fill reference in proxy, skipping metamethods
			
			return self.fillProxy -- Fill proxy can now be modified
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
				normalObject.fill.effect.rotation = math.rad(self.viewRotation + self.fill.rotation) -- Fill might be rotated
			end
			
			if self.numChildren then
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
local function finalizeLightObject(event)
	local lightObject = event.target
	display.remove(lightObject.normalObject)
	
	lightObject.normalObject = nil
end

local function entangleFunction(object, functionIndex)
	local originalFunction = object[functionIndex]
	
	object["_"..functionIndex] = originalFunction
	object[functionIndex] = function(self, ...)
		self["_"..functionIndex](self, ...)
		self.normalObject[functionIndex](self.normalObject, ...)
	end
end

local function entangleObject(lightObject)
	lightObject.viewRotation = 0
	
	lightObject.fillProxy = setmetatable({
		normalObject = lightObject.normalObject,
		fill = nil, -- Is set during query
	}, fillProxyMetatable)
	
	entangleFunction(lightObject, "rotate")
	entangleFunction(lightObject, "scale")
	entangleFunction(lightObject, "setMask")
	entangleFunction(lightObject, "toBack")
	entangleFunction(lightObject, "toFront")
	entangleFunction(lightObject, "translate")
	entangleFunction(lightObject, "removeSelf")
	
	rawset(lightObject, "_oldMeta", getmetatable(lightObject))
	setmetatable(lightObject, entangleMetatable)
	
	lightObject:addEventListener("finalize", finalizeLightObject)
end

local function lightInsert(self, lightObject)
	self:oldInsert(lightObject)
	self.normalObject:insert(lightObject.normalObject)
	
	lightObject.parentRotation = self.viewRotation -- Let metatable update efefct
end
---------------------------------------------- Module functions
function quantum.newLight(options) -- Only meant to be used internally by dynacam, or will fail to be updated
	options = options or {}
	
	local z = options.z or DEFAULT_Z
	local color = options.color or DEFAULT_COLOR
	local attenuationFactors = options.attenuationFactors or DEFAULT_ATTENUATION
	
	local light = display.newGroup()
	light.normalObject = display.newGroup()
	
	if options.debug then
		display.newCircle(light, 0, 0, 5) -- Debug view
	end
	
	entangleObject(light)
	
	light.position = {0, 0, z} -- Internal table, auto updates for fast shader data pass
	light.z = z
	light.attenuationFactors = attenuationFactors
	light.color = color
	
	return light
end

function quantum.newGroup()
	local lightGroup = display.newGroup()
	lightGroup.normalObject = display.newGroup()
	
	lightGroup.oldInsert = lightGroup.insert
	lightGroup.insert = lightInsert
	
	entangleObject(lightGroup)
	
	return lightGroup
end

function quantum.newCircle(x, y, radius)
	local lightCircle = display.newCircle(x, y, radius)
	local normalCircle = display.newCircle(x, y, radius)
	
	normalCircle.fill.effect = "filter.custom.rotate"
	
	lightCircle.normalObject = normalCircle
	entangleObject(lightCircle)
	
	return lightCircle
end

function quantum.newContainer(width, height)
	local lightContainer = display.newContainer(width, height)
	lightContainer.normalObject = display.newContainer(width, height)
	
	lightContainer.oldInsert = lightContainer.insert
	lightContainer.insert = lightInsert
	
	entangleObject(lightContainer)
	
	return lightContainer
end

function quantum.newImage(filename, normalFilename, baseDir)
	baseDir = baseDir or system.ResourceDirectory

	local lightImage = display.newImage(filename, baseDir)
	local normalImage = display.newImage(normalFilename, baseDir)
	
	normalImage.fill.effect = "filter.custom.rotate"
	
	lightImage.normalObject = normalImage
	entangleObject(lightImage)
	
	return lightImage
end

function quantum.newImageRect(filename, normalFilename, baseDir, width, height)
	baseDir = baseDir or system.ResourceDirectory
	
	local lightImageRect = display.newImageRect(filename, baseDir, width, height)
	local normalImageRect = display.newImageRect(normalFilename, baseDir, width, height)
	
	normalImageRect.fill.effect = "filter.custom.rotate"
	
	lightImageRect.normalObject = normalImageRect
	entangleObject(lightImageRect)
	
	return lightImageRect
end

function quantum.newLine(...)
	local lightLine = display.newLine(...)
	local normalLine = display.newLine(...)
	normalLine:setStrokeColor(0.5, 0.5, 1.0) -- Normal vector facing up
	
	entangleFunction(lightLine, "append")
	
	lightLine.normalObject = normalLine
	entangleObject(lightLine)
	
	return lightLine
end

function quantum.newMesh(options)
	local lightMesh = display.newMesh(options)
	local normalMesh = display.newMesh(options)
	
	lightMesh.pathFunctions = {
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
	
	normalPolygon.fill.effect = "filter.custom.rotate"
	
	lightPolygon.normalObject = normalPolygon
	entangleObject(lightPolygon)
	
	return lightPolygon
end

function quantum.newRoundedRect(x, y, width, height, cornerRadius)
	local lightRoundedRect = display.newRoundedRect(x, y, width, height, cornerRadius)
	local normalRoundedRect = display.newRoundedRect(x, y, width, height, cornerRadius)
	
	normalRoundedRect.fill.effect = "filter.custom.rotate"
	
	lightRoundedRect.normalObject = normalRoundedRect
	entangleObject(lightRoundedRect)
	
	return lightRoundedRect
end

function quantum.newSnapshot(width, height)
	local lightSnapshot = display.newSnapshot(width, height)
	local normalSnapshot = display.newSnapshot(width, height)
	
	lightSnapshot.oldInsert = lightSnapshot.insert
	lightSnapshot.insert = lightInsert
	
	entangleFunction(lightSnapshot, "invalidate")
	
	lightSnapshot.normalObject = normalSnapshot
	entangleObject(lightSnapshot)
	
	return lightSnapshot
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
	
	normalRect.fill.effect = "filter.custom.rotate"
	
	lightRect.normalObject = normalRect
	entangleObject(lightRect)
	
	return lightRect
end

function quantum.newSprite(diffuseSheet, normalSheet, sequenceData)
	local lightSprite = display.newSprite(diffuseSheet, sequenceData)
	local normalSprite = display.newSprite(normalSheet, sequenceData)
	
	entangleFunction(lightSprite, "play")
	entangleFunction(lightSprite, "pause")
	entangleFunction(lightSprite, "setFrame")
	entangleFunction(lightSprite, "setSequence")
	
	normalSprite.fill.effect = "filter.custom.rotate"
	
	lightSprite.normalObject = normalSprite
	entangleObject(lightSprite)
	
	return lightSprite
end

return quantum