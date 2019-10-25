---------------------------------------------- Quantum - Light object creation - Basilio Germán
local moduleName = ...
local upRequire = string.match(moduleName or "", "(.*[%.])") or ""

local normalShaders = require(upRequire.."shaders.normal")

local quantum = {
	utils = {
		copy = function(fTable) -- Simple copy
			local copy = {}
			for key, value in pairs(fTable) do
				copy[key] = value
			end
			return copy
		end,
		merge = function(table1, table2) -- Simple merge
			local result = {}
			for key, value in pairs(table1) do
				result[key] = value
			end
			for key, value in pairs(table2) do
				result[key] = value
			end
			return result
		end,
	}
}
---------------------------------------------- Constants
local DEFAULT_NORMAL = {0.5, 0.5, 1.0}
local DEFAULT_Z = 0.2
local DEFAULT_ATTENUATION = {0.4, 3, 20}

local FUNCTIONS_DISPLAY = {"rotate", "scale", "setMask", "toBack", "toFront", "translate", "removeSelf"}
local FUNCTIONS = {
	DISPLAY = FUNCTIONS_DISPLAY,
	SPRITE = quantum.utils.merge(FUNCTIONS_DISPLAY, {"play", "pause", "setFrame", "setSequence"}),
	SNAPSHOT = quantum.utils.merge(FUNCTIONS_DISPLAY, {"invalidate"}),
	LINE = quantum.utils.merge(FUNCTIONS_DISPLAY, {"append"}),
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
		return self._superMetaMesh.__index(self, index)
	end,
	__newindex = function(self, index, value)
		self._superMetaMesh.__newindex(self, index, value)
	end
}

local effectProxyMetatable = {
	__index = function(self, index)
		return self.effect[index]
	end,
	__newindex = function(self, index, value)
		if self.normalObject.fill.effect.effect then -- Update normal version of effect (Indexed at .effect)
			self.normalObject.fill.effect.effect[index] = value
		end
		
		self.effect[index] = value
	end,
}

local fillProxyMetatable = { -- Used to intercept .fill transform changes and replicate to normal
	__index = function(self, index)
		if index == "effect" then
			if self.fill.effect then
				rawset(self.effectProxy, "effect", self.fill.effect)
				return self.effectProxy -- Effect proxy can now be modified
			end
		end
		return self.fill[index]
	end,
	__newindex = function(self, index, value)
		if index == "effect" then -- Get same effect in normal variant
			self.normalObject.fill.effect = normalShaders.getEffect(value)
		else -- x, y, scaleX, scaleY, colors, etc
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
			rawset(self.fillProxy, "fill", self._superMeta.__index(self, index)) -- Update original fill & normal reference in proxy, skipping metamethods
			rawset(self.fillProxy, "normal", self.normalObject.fill)
			return self.fillProxy -- Fill proxy can now be modified
		elseif index == "normal" then
			return self.normalObject.fill
		elseif index == "addEventListener" then
			return self.addEventListenerPirate
		elseif index == "camera" then
			return self._camera
		end
		return self._superMeta.__index(self, index)
	end,
	__newindex = function(self, index, value)
		local normalObject = self.normalObject
		if index == "normal" then
			if normalObject.fill then
				normalObject.fill = value
				normalObject.fill.effect = normalShaders.getEffect()
				normalObject.fill.effect.rotate.rotation = math.rad(self.viewRotation + self.fill.rotation) -- Fill might be rotated
			end
		elseif index == "parentRotation" then -- Parent is telling us to update our view rotation 
			self.viewRotation = value + self.rotation
			
			if normalObject.fill and normalObject.fill.effect then
				normalObject.fill.effect.rotate.rotation = math.rad(self.viewRotation + (self.fill.rotation or 0)) -- Fill might be rotated
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
			self._superMeta.__newindex(self, index, value)
			
			if HIT_REFRESH[index] and rawget(self, "touchArea") then
				local touchArea = rawget(self, "touchArea")
				touchArea.isHitTestable = (self.isVisible and (self.alpha > 0)) or self.isHitTestable
			end
			
			if index == "rotation" and value then -- Propagate rotation change
				-- Rotation was already set in _superMeta
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
		
		if self.normalObject then
			self.normalObject[functionIndex](self.normalObject, ...)
		end
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
	return self._superMeta.__index(self, "addEventListener")(self, eventName, eventFunction)
end

local function entangleObject(lightObject) -- Basic light object principle, where we make object pairs in different worlds (diffuse & normal)
	lightObject.viewRotation = 0
	
	-- Fill & Effect are replaced by proxies that forward  set values to diffuse and normal objects at the same time.
	local effectProxy = {
		normalObject = lightObject.normalObject, -- Needed to update effect
		effect = nil, -- Set during meta query (fill)
	}
	
	local fillProxy = {
		normalObject = lightObject.normalObject, -- Needed to update fill
		effectProxy = setmetatable(effectProxy, effectProxyMetatable),
		fill = nil, -- Set during meta query (fill)
	}
	lightObject.fillProxy = setmetatable(fillProxy, fillProxyMetatable)
	
	
	
	
	lightObject.addEventListenerPirate = addEventListenerPirate
	
	local superMeta = getmetatable(lightObject)
	rawset(lightObject, "_superMeta", superMeta)
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
function quantum.newLight(options, debugLight) -- Only meant to be used internally by dynacam, or will fail to be updated
	options = options or {}
	
	local z = options.z or DEFAULT_Z
	local color = options.color or {1, 1, 1, 1} -- New instance of white
	local scale = options.scale or 1
	local attenuationFactors = options.attenuationFactors or DEFAULT_ATTENUATION -- Default attenuation here as we don't have table copy
	
	local light = display.newGroup()
	light.normalObject = display.newGroup()
	
	light.debug = display.newCircle(light, 0, 0, 5)
	light.debug.isVisible = debugLight
	
	entangleObject(light)
	
	light.position = {0, 0, z} -- Internal table, auto updates for fast shader data pass
	light.scale = scale
	light.z = z
	light.attenuationFactors = quantum.utils.copy(attenuationFactors)
	light.color = quantum.utils.copy(color)
	
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
	
	normalMesh.fill.effect = normalShaders.getEffect()
	
	lightMesh.normalObject = normalMesh
	entangleObject(lightMesh)
	
	local superMetaMesh = getmetatable(lightMesh)
	rawset(lightMesh, "_superMetaMesh", superMetaMesh)
	setmetatable(lightMesh, meshPathEntangleMetatable)
	
	return lightMesh
end

function quantum.newPolygon(x, y, vertices)
	local lightPolygon = display.newPolygon(x, y, vertices)
	local normalPolygon = display.newPolygon(x, y, vertices)
	
	lightPolygon.vertices = quantum.utils.copy(vertices) -- Save vertices in case of touch listener mask rebuild
	
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
	local normal = options.normal or quantum.utils.copy(DEFAULT_NORMAL)
	
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
	diffuseObject.entangleFunctions = entangleFunctions
	
	if normalObject.fill then
		normalObject.fill.effect = normalShaders.getEffect() -- Default normal shader
	end
	
	entangleObject(diffuseObject)
	
	return diffuseObject
end

return quantum