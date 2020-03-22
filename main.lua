---------------------------------------------- Dynacam small demo
local dynacam = require("dynacam")
---------------------------------------------- Setup
local ccx = display.contentCenterX
local ccy = display.contentCenterY

local camera = dynacam.newCamera() -- Default camera
camera.x = ccx
camera.y = ccy
---------------------------------------------- Object creation
local iTextOptions = {
	x = 0,
	y = 0,
	font = native.systemFontBold,
	fontSize = 60,
	text = "See README.md for more info",
	normal = {0.5, 0.5, 1}, -- Facing straight at camera
}
local infoText = dynacam.newText(iTextOptions)
camera:add(infoText)
camera:setFocus(infoText) -- Centers camera on infoText

local lightOptions = {x = 0, y = 0, z = 0.1, color = {1, 1, 1, 1}, attenuationFactors = {0.1, 2, 5}}
local rotatingLight = dynacam.newLight(lightOptions)
camera:add(rotatingLight)
---------------------------------------------- Start demo
dynacam.start()

-- Light rotate and color change
Runtime:addEventListener("enterFrame", function(event)
	local counter = (event.frame + 1) % (360 * 4)
	local angle = math.rad(counter * 0.25)
	rotatingLight.x = math.cos(angle) * infoText.width * 0.15
	rotatingLight.y = math.sin(angle) * infoText.width * 0.15
	
	-- Cycle colors
	rotatingLight.color[1] = math.cos(angle * 2) -- Vary R component
	rotatingLight.color[2] = math.sin(angle * 2) -- Vary G component
end)

camera:setDrawMode(true)
