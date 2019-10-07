require("mobdebug").start()
----------------------------------------------- Demo game - Basilio Germán
local physics = require("physics")
local widget = require("widget")
local dynacam = require("dynacam")
----------------------------------------------- Variables
local camera

local lightData

local mapGroup

local pCharacter

local holdingKey = {
	right = false,
	left = false,
	up = false,
	down = false,
}
----------------------------------------------- Constants
local CAM_PAN_LIMIT = {
	X = display.actualContentHeight * 0.4,
	Y = display.viewableContentHeight * 0.4,
}

local FILLS = {
	[1] = {
		diffuse = "images/wall.png",
		normal = "images/wall_n.png",
	},
	[2] = {
		diffuse = "images/brick.png",
		normal = "images/brick_n.png",
	},
}
local MAP = {
	{1,1,1,1,1,1,1,2,1,1,2,2,2,2},
	{1,1,1,2,1,1,1,1,1,1,1,1,1,2},
	{1,1,2,2,2,2,1,2,1,1,1,2,2,2},
	{1,2,2,2,2,2,1,2,2,2,2,2,2,2},
	{1,2,2,2,2,1,1,1,1,1,1,1,1,1},
	{1,2,2,2,2,1,1,1,1,1,1,1,1,1},
	{1,2,2,1,1,1,1,1,1,1,1,1,1,1},
	{2,1,1,1,1,1,1,1,1,2,2,1,1,1},
	{2,2,2,2,1,1,1,1,1,1,2,1,1,1},
}

local ACCELERATION = 1000

local FORCES_KEY = {
	right = {torque = ACCELERATION * 5},
	left = {torque = -ACCELERATION * 5},
	up = {force = ACCELERATION},
	down = {force = -ACCELERATION},
}
----------------------------------------------- Caches
----------------------------------------------- Functions
local function keyListener(event)
	if holdingKey[event.keyName] ~= nil then -- Prevent other keys from registering
		if event.phase == "down" then
			holdingKey[event.keyName] = true
		elseif event.phase == "up" then
			holdingKey[event.keyName] = false
		end
	end
end

local function createBackground()
	-- Tiles
	local size = 250
	for y = 1, #MAP do
		for x = 1, #MAP[y] do
			local rect = dynacam.newRect(x * size, y * size, size, size)
			rect.fill = {type = "image", filename = FILLS[MAP[y][x]].diffuse}
			rect.normal = {type = "image", filename = FILLS[MAP[y][x]].normal}
			
			mapGroup:insert(rect)
		end
	end
end

local function addlights()
	-- Add lights to world
	for lIndex = 1, #lightData do 
		local lData = lightData[lIndex]
		
		local lOptions = {
			color = lData.color,
		}
		local light = camera:newLight(lOptions)
		light.x = lData.position[1]
		light.y = lData.position[2]
		light.z = lData.position[3]
		light.attenuationFactors = lData.attenuationFactors
		mapGroup:insert(light)
	end
end

local function addTestSprites()
	 -- Test sprite coin
	local coinSpriteSheet = {
		sheetData = {width = 34, height = 34, numFrames = 16},
		sequenceData = {{name = "idle", start = 1, count = 16, time = 1000}},
		diffuse = "images/spinning_coin_gold.png",
		normal = "images/spinning_coin_gold_n.png",
	}
	local cDiffuseSheet = graphics.newImageSheet(coinSpriteSheet.diffuse, coinSpriteSheet.sheetData)
	local cNormalSheet = graphics.newImageSheet(coinSpriteSheet.normal, coinSpriteSheet.sheetData)
	
	local gridSize = 10
	for index = 1, 50 do
		local x = index % gridSize
		local y = math.ceil(index * (1 / gridSize))
		
		local coinGroup = dynacam.newGroup()
		coinGroup.x = 1500 + (x * 100)
		coinGroup.y = 1200 + (y * 100)
		
		local coinSprite = dynacam.newSprite(cDiffuseSheet, cNormalSheet, coinSpriteSheet.sequenceData)
		coinSprite:setSequence("idle")
		coinSprite:play()
		coinGroup:insert(coinSprite)
		
		camera:addBody(coinGroup, "dynamic", {friction = 0.5, bounce = 0.1, density = 1, radius = 17})
		coinGroup.angularDamping = 0.5
		coinGroup.linearDamping = 0.8
		
		local coinLight = camera:newLight({color = {1, 0.843, 0, 0.25}})
		coinLight.z = 0.05
		coinLight.attenuationFactors = {1, 5, 50}
		coinGroup:insert(coinLight)
		
		mapGroup:insert(coinGroup)
	end
	
	-- Test sprite health box
	local spriteGroup = dynacam.newGroup()
	spriteGroup.x = 1000
	spriteGroup.y = 1100
	
	local spriteSheet = {
		sheetData = {width = 64, height = 64, numFrames = 2},
		sequenceData = {{name = "idle", start = 1, count = 2, time = 500}},
		diffuse = "images/powerup_health.png",
		normal = "images/powerup_health_n.png",
	}
	local diffuseSheet = graphics.newImageSheet(spriteSheet.diffuse, spriteSheet.sheetData)
	local normalSheet = graphics.newImageSheet(spriteSheet.normal, spriteSheet.sheetData)
	
	local sprite = dynacam.newSprite(diffuseSheet, normalSheet, spriteSheet.sequenceData)
	sprite:setSequence("idle")
	sprite:play()
	spriteGroup:insert(sprite)
	
	local healthLight = camera:newLight({color = {1, 0, 0, 1}})
	healthLight.x = 0
	healthLight.y = 0
	healthLight.z = 0.1
	spriteGroup:insert(healthLight)
	
	mapGroup:insert(spriteGroup)
	camera:addBody(spriteGroup, "dynamic", {friction = 0.5, bounce = 0.1, density = 1, box = {halfWidth = 32, halfHeight = 32}})
	spriteGroup.angularDamping = 0.2
	spriteGroup.linearDamping = 0.6
end

local function addPlayerCharacter()
	-- Player Character
	pCharacter = dynacam.newGroup()
	pCharacter.x = 800
	pCharacter.y = 800
	mapGroup:insert(pCharacter)
	
	local ship = dynacam.newRect(0, 0, 256, 196)
	ship.fill = {type = "image", filename = "images/spaceship_carrier_01.png"}
	ship.normal = {type = "image", filename = "images/spaceship_carrier_01_n.png"}
	ship.fill.effect = "filter.pixelate"
	ship.fill.effect.numPixels = 8
	transition.to(ship.fill.effect, {time = 5000, numPixels = 1,})
	pCharacter:insert(ship)
	pCharacter.ship = ship
	
	local shipLight = camera:newLight({color = {1, 1, 1, 1}})
	shipLight.x = 300
	shipLight.y = 0
	shipLight.z = 0.15
	shipLight.state = true
	pCharacter:insert(shipLight)
	pCharacter.shipLight = shipLight
	
	camera:addBody(pCharacter, "dynamic", {friction = 0.5, bounce = 0.1, density = 1, box = {halfWidth = 120, halfHeight = 64}})
	pCharacter.angularDamping = 2
	pCharacter.linearDamping = 0.5
	
	pCharacter.isHitTestable = true
	pCharacter:addEventListener("tap", function(event)
		local light = pCharacter.shipLight
		
		light.state = not light.state
		local intensity = light.state and 1 or 0
		
		light.color[4] = intensity
	end)
end

local function addTestOther()
	-- Text test
	local textOptions = {
		x = 1250,
		y = 300,
		font = native.systemFontBold,
		fontSize = 60,
		text = "Dynacam test playground!",
		normal = {0.5, 0.5, 1},
	}
	local text = dynacam.newText(textOptions)
	mapGroup:insert(text)
	
	-- Mesh test
	local mesh = dynacam.newMesh({
		x = 0,
		y = 0,
		mode = "fan",
		vertices = {
			200,0, 0,0, 0,400, 400,400, 400,0
		}
	})
	mesh:translate(mesh.path:getVertexOffset())  -- Translate mesh so that vertices have proper world coordinates
	mesh.fill = {type = "image", filename = FILLS[2].diffuse}
	mesh.normal = {type = "image", filename = FILLS[2].normal}
	local vertexX, vertexY = mesh.path:getVertex(3)
	mesh.path:setVertex(3, vertexX + 50, vertexY - 50)
	mapGroup:insert(mesh)
	
	-- Normal Line
	local line = dynacam.newLine(0, 0, 1000, 1000)
	line:append(1300, 1000)
	line:append(2000, 2000)
	line:append(2000, 1000)
	line:append(1500, 250)
	line.strokeWidth = 10
	mapGroup:insert(line)
	
	-- Line without normal
	local dLine = display.newLine(50, 100, 1050, 1100)
	dLine:append(1350, 1100)
	dLine:append(2050, 2100)
	dLine:append(2050, 1100)
	dLine:append(1550, 350)
	dLine.strokeWidth = 10
	mapGroup:oldInsert(dLine) -- Used to insert displayObjects
	
	-- Polygon test
	local vertices = { 0,-110, 27,-35, 105,-35, 43,16, 65,90, 0,45, -65,90, -43,15, -105,-35, -27,-35, }
	local polygon = dynacam.newPolygon(1500, 1250, vertices)
	polygon.fill = {type = "image", filename = FILLS[2].diffuse}
	polygon.normal = {type = "image", filename = FILLS[2].normal}
	polygon.fill.rotation = 90
	mapGroup:insert(polygon)
	
	-- Circle
	local circle = dynacam.newCircle(1250, 1250, 100)
	circle.fill = {type = "image", filename = FILLS[1].diffuse}
	circle.normal = {type = "image", filename = FILLS[1].normal}
	circle.fill.scaleX = 5
	circle.fill.scaleY = 5
	mapGroup:insert(circle)
	
	-- RoundedRect
	local roundedRect = dynacam.newRoundedRect(1750, 1250, 200, 150, 50)
	roundedRect.fill = {type = "image", filename = FILLS[2].diffuse}
	roundedRect.normal = {type = "image", filename = FILLS[2].normal}
	mapGroup:insert(roundedRect)
	
	-- Container
	local container = dynacam.newContainer(200, 200)
	container.x = 2750
	container.y = 1500
	mapGroup:insert(container)
	
	-- newImage
	local containerShip = dynacam.newImage("images/spaceship_carrier_02.png", "images/spaceship_carrier_02_n.png")
	container:insert(containerShip)
	
	local otherShip = dynacam.newImage("images/spaceship_carrier_02.png", "images/spaceship_carrier_02_n.png")
	otherShip.x = 2750
	otherShip.y = 1250
	mapGroup:insert(otherShip)
end

local function createWorld()
	display.remove(mapGroup)
	mapGroup = dynacam.newGroup()
	
	createBackground()
	addlights()
	addTestOther()
	addTestSprites()
	addPlayerCharacter()
end

local function sliderListener(event)
	local slider = event.target
	local index = slider.index
	local value = event.value

	local float = (value * slider.valueScale) + slider.offset

	pCharacter.shipLight.attenuationFactors[index] = float
	
	print(float)
end

local function createSliders()
	if false then -- Sliders 
		local valueScales = {
			0.02,
			0.05,
			0.5,
		}
		
		local offsets = {
			0,
			0,
			0,
		}
		
		for index = 1, 3 do
			local slider = widget.newSlider({
				x = display.screenOriginX + index * 50,
				y = display.screenOriginY + display.actualContentHeight - 100,
				orientation = "vertical",
				height = 150,
				value = 50,
				listener = sliderListener
			})
			slider.index = index
			slider.valueScale = valueScales[index]
			slider.offset = offsets[index]
		end
	end
end

local function startGame()
	camera:start()
	camera:add(mapGroup)
	
	local focus = camera:toPoint(0, 0)
	pCharacter.focus = focus
	
--	camera:setZoom(2) -- TODO: fix zoom
	 
	local counter = 0
	Runtime:addEventListener("enterFrame", function()
		counter = (counter + 1) % (360 * 4)
		local angle = math.rad(counter * 0.25)
		camera.lights[4].x = 700 + math.cos(angle) * 600
		camera.lights[4].y = 700 + math.sin(angle) * 600
		camera.lights[4].color[1] = math.cos(angle * 4)
		
		for key, holding in pairs(holdingKey) do
			local force = holding and FORCES_KEY[key].force
			if force then
				local fX = math.cos(math.rad(pCharacter.rotation)) * force
				local fY = math.sin(math.rad(pCharacter.rotation)) * force
				
				pCharacter:applyForce(fX, fY, pCharacter.x, pCharacter.y)
			end
			
			if holding and FORCES_KEY[key].torque then
				pCharacter:applyTorque(FORCES_KEY[key].torque)
			end
		end
		
		local fX, fY = pCharacter:getLinearVelocity()
		
		fX = (fX > CAM_PAN_LIMIT.X) and CAM_PAN_LIMIT.X or ((fX < -CAM_PAN_LIMIT.X) and -CAM_PAN_LIMIT.X) or fX
		fY = (fY > CAM_PAN_LIMIT.Y) and CAM_PAN_LIMIT.Y or ((fY < -CAM_PAN_LIMIT.Y) and -CAM_PAN_LIMIT.Y) or fY
		
		pCharacter.focus.x = pCharacter.x + fX
		pCharacter.focus.y = pCharacter.y + fY
	end)

--	Runtime:addEventListener("tap", function(event)
--		local light = pCharacter.shipLight
		
--		light.state = not light.state
--		local intensity = light.state and 1 or 0
		
--		light.color[4] = intensity
--	end)
end

local function cleanUp()
	camera:stop()
end

local function initialize()
	display.setStatusBar( display.HiddenStatusBar )
	
	camera = dynacam.newCamera({damping = 10})
	camera:setDebug(false)
	camera.x = display.contentCenterX
	camera.y = display.contentCenterY
	
--	camera.isVisible = false
	
	physics.start()
	physics.setGravity(0, 0)
	
--	display.setDefault( "background", 1,1,1)
	
	lightData = {
		{position = {400, 400, 0.2}, color = {1, 1, 1, 1}},
		{position = {700, 900, 0.2}, color = {1, 1, 1, 1}},
		{position = {900, 900, 0.2}, color = {1, 1, 0, 1}},
		{position = {0, 0, 0.2}, color = {1, 0, 1, 1}},
		{position = {500, 2000, 0.05}, color = {0.1, 0.1, 0.1, 1}}, -- Black light?
		{position = {2500, 800, 0.25}, color = {0, 1, 0, 1}},
		{position = {2200, 1200, 0.15}, color = {0, 0.5, 1, 1}},
		{position = {1400, 1800, 0.1}, color = {0, 0.5, 1, 1}},
		{position = {3000, 2000, 0.1}, color = {1, 1, 1, 1}, attenuationFactors = {0.1, 2, 5}},
	}
	
	Runtime:addEventListener("key", keyListener)
end
----------------------------------------------- Module functions 
initialize()
createWorld()
createSliders()
startGame()
