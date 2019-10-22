---------------------------------------------- Normal shader factory - Fuse rotate shader with any other effect
local normal = {}

local normalEffects = {}

function normal.getEffect(effectName)
	if effectName then
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