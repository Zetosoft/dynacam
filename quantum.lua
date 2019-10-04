---------------------------------------------- Quantum - Light object creation - Basilio Germán
local quantum = {}
---------------------------------------------- Variables

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
			
			if normalObject.fill and normalObject.fill.effect then
				normalObject.fill.effect.rotation = math.rad(self.viewRotation)
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
end

local function entangleObject(lightObject)
	lightObject.viewRotation = 0
	
	rawset(lightObject, "_oldMeta", getmetatable(lightObject))
	setmetatable(lightObject, entangleMetatable)
	
	lightObject:addEventListener("finalize", finalizeLightObject)
end

local function lightInsert(self, lightObject)
	self:oldInsert(lightObject)
	self.normalObject:insert(lightObject.normalObject)
	
	lightObject.parentRotation = self.viewRotation -- Let metatable update efefct
end

local function entangleFunction(object, functionIndex)
	local originalFunction = object[functionIndex]
	
	object["_"..functionIndex] = originalFunction
	object[functionIndex] = function(self, ...)
		self["_"..functionIndex](self, ...)
		self.normalObject[functionIndex](self.normalObject, ...)
	end
end
---------------------------------------------- Module functions
function quantum.newLight(options)
	options = options or {}
	
	local color = options.color or {1, 1, 1, 1}
	
	local light = display.newGroup()
	light.normalObject = display.newGroup()
	
	display.newCircle(light, 0, 0, 5) -- Debug view
	
	entangleObject(light)
	
	light.position = {0, 0, 0.2} -- Auto updates for fast shader data pass
	light.z = 0.2
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
	
	normalMesh.fill.effect = "filter.custom.rotate"
	
	lightMesh.normalObject = normalMesh
	entangleObject(lightMesh)
	
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