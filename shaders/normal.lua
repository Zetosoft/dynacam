---------------------------------------------- Normal shader factory - Fuse rotate shader with any other effect
local normal = {}
----------------------------------------------
local normalEffects = {}

local existTested = {}
---------------------------------------------- Local functions
local function effectExists(effectName)
	local exists = false
	
	if existTested[effectName] == nil then
		local testRect = display.newRect(0, 0, 1, 1)
		testRect.fill.effect = effectName
		existTested[effectName] = testRect.fill.effect ~= nil
		display.remove(testRect)
	end
	
	return existTested[effectName]
end
---------------------------------------------- Module functions
function normal.getEffect(effectName)
	if effectName and effectExists(effectName) then
		local internalName = string.gsub(effectName, "%.", "")
		
		if not normalEffects[effectName] then
			local kernel = {}

			kernel.language = "glsl"
			kernel.category = "filter"
			kernel.group = "normal"
			kernel.name = internalName

			kernel.graph = {
				nodes = {
					rotate = {effect = "filter.custom.rotate", input1 = "paint1"},
					effect = {effect = effectName, input1 = "rotate"},
				},
				output = "effect",
			}
			graphics.defineEffect(kernel)
			
			normalEffects[effectName] = kernel
		end
		
		return "filter.normal."..internalName
	else
		if not normalEffects["default"] then
			local kernel = {}

			kernel.language = "glsl"
			kernel.category = "filter"
			kernel.group = "normal"
			kernel.name = "default"

			kernel.graph = {
				nodes = {
					rotate = {effect = "filter.custom.rotate", input1 = "paint1"},
				},
				output = "rotate",
			}
			graphics.defineEffect(kernel)
			
			normalEffects["default"] = kernel
		end
		
		return "filter.normal.default"
	end
end
			
return normal