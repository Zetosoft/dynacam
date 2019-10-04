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
			
			if normalObject.fill then
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

local function lightGroupInsert(self, lightObject)
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
	lightGroup.insert = lightGroupInsert
	
	entangleObject(lightGroup)
	
	return lightGroup
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
	
	lightSprite.oldPlay = lightSprite.play
	lightSprite.oldPause = lightSprite.pause
	lightSprite.oldSetFrame = lightSprite.setFrame
	lightSprite.oldSetSequence = lightSprite.setSequence
	
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