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
---------------------------------------------- Caches
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
function quantum.newLight(self, options)
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
	
	return light
end

function quantum.newGroup()
	
end

function quantum.newRect()
	
end

function quantum.newSprite(diffuseSheet, normalSheet, sequenceData)
	local diffuseSprite = display.newSprite(diffuseSheet, sequenceData)
	local normalSprite = display.newSprite(normalSheet, sequenceData)
	
	diffuseSprite.oldPlay = diffuseSprite.play
	diffuseSprite.oldPause = diffuseSprite.pause
	diffuseSprite.oldSetFrame = diffuseSprite.setFrame
	diffuseSprite.oldSetSequence = diffuseSprite.setSequence
	
	entangleFunction(diffuseSprite, "play")
	entangleFunction(diffuseSprite, "pause")
	entangleFunction(diffuseSprite, "setFrame")
	entangleFunction(diffuseSprite, "setSequence")
	
	normalSprite.fill.effect = "filter.custom.rotate"
	
	diffuseSprite.normalObject = normalSprite
	entangleObject(diffuseSprite)
	
	return diffuseSprite
end


return quantum