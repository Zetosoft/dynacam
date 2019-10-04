----------------------------------------------- Demo game - Basilio Germán
local physics = require("physics")
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

local function buildMap()
	display.remove(mapGroup)
	mapGroup = dynacam.newGroup()
	
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
	
	local mWidth = mapGroup.width
	local mHeight = mapGroup.height
	
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
		mapGroup:insert(light)
	end
	
	 -- Test sprite coin
	local coinSpriteSheet = {
		sheetData = {width = 32, height = 32, numFrames = 8},
		sequenceData = {{name = "idle", start = 1, count = 8, time = 600}},
		diffuse = "images/test/spinning_coin_gold.png",
		normal = "images/test/spinning_coin_gold_n.png",
	}
	local cDiffuseSheet = graphics.newImageSheet(coinSpriteSheet.diffuse, coinSpriteSheet.sheetData)
	local cNormalSheet = graphics.newImageSheet(coinSpriteSheet.normal, coinSpriteSheet.sheetData)
	
	local cSprite = dynacam.newSprite(cDiffuseSheet, cNormalSheet, coinSpriteSheet.sequenceData)
	cSprite.x = 800
	cSprite.y = 300
	cSprite:setSequence("idle")
	cSprite:play()
	mapGroup:insert(cSprite)
	physics.addBody(cSprite, "dynamic", {friction = 0.5, bounce = 0.1, density = 1})
	cSprite.angularDamping = 0.2
	cSprite.linearDamping = 0.2
	
	Runtime:addEventListener("enterFrame", function(event)
		cSprite.normalObject.x = cSprite.x
		cSprite.normalObject.y = cSprite.y
		cSprite.rotation = cSprite.rotation -- This will propagate changes to normal object
	end)

	-- Test sprite health box
	local spriteGroup = dynacam.newGroup()
	spriteGroup.x = 1000
	spriteGroup.y = 1100
	
	local spriteSheet = {
		sheetData = {width = 64, height = 64, numFrames = 2},
		sequenceData = {{name = "idle", start = 1, count = 2, time = 500}},
		diffuse = "images/test/powerup_health.png",
		normal = "images/test/powerup_health_n.png",
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
	physics.addBody(spriteGroup, "dynamic", {friction = 0.5, bounce = 0.1, density = 1, box = {halfWidth = 32, halfHeight = 32}})
	spriteGroup.angularDamping = 0.2
	spriteGroup.linearDamping = 0.2
	
	Runtime:addEventListener("enterFrame", function(event)
		spriteGroup.normalObject.x = spriteGroup.x
		spriteGroup.normalObject.y = spriteGroup.y
		spriteGroup.rotation = spriteGroup.rotation -- This will propagate changes to normal object
	end)
	
	-- Player Character
	pCharacter = dynacam.newGroup()
	pCharacter.x = 800
	pCharacter.y = 800
	mapGroup:insert(pCharacter)
	
	local ship = dynacam.newRect(0, 0, 256, 196)
	ship.fill = {type = "image", filename = "images/test/spaceship_carrier_01.png"}
	ship.normal = {type = "image", filename = "images/test/spaceship_carrier_01_n.png"}
	ship.fill.effect = "filter.pixelate"
	ship.fill.effect.numPixels = 8
	transition.to(ship.fill.effect, {time = 5000, numPixels = 1,})
	pCharacter:insert(ship)
	pCharacter.ship = ship
	
	local shipLight = camera:newLight({color = {1, 1, 1, 1}})
	shipLight.x = 250
	shipLight.y = 0
	shipLight.z = 0.1
	pCharacter:insert(shipLight)
	
	physics.addBody(pCharacter, "dynamic", {friction = 0.5, bounce = 0.1, density = 1, radius = 98})
	pCharacter.angularDamping = 2
	pCharacter.linearDamping = 0.2
	
	Runtime:addEventListener("enterFrame", function(event)
		pCharacter.normalObject.x = pCharacter.x
		pCharacter.normalObject.y = pCharacter.y
		pCharacter.rotation = pCharacter.rotation -- This will propagate changes to normal object
	end)
end

local function startGame()
	camera:start()
	camera:add(mapGroup)
	camera:setFocus(pCharacter, {trackRotation = true}) -- TODO: must support rotation of lights!
	
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
	end)
end

local function cleanUp()
	camera:stop()
end

local function initialize()
	camera = dynacam.newCamera({debug = false})
	camera.x = display.contentCenterX
	camera.y = screen.contentCenterY
	
	physics.start()
	physics.setGravity(0, 0)
	
	display.setDefault( "background", 1,1,1)
	
	lightData = {
		{position = {400, 400, 0.2}, color = {1, 1, 1, 1}},
		{position = {700, 900, 0.2}, color = {1, 1, 1, 1}},
		{position = {900, 900, 0.2}, color = {1, 1, 0, 1}},
		{position = {0, 0, 0.2}, color = {1, 0, 1, 1}},
	}
	
	Runtime:addEventListener("key", keyListener)
end
----------------------------------------------- Module functions 
initialize(event)
buildMap()
startGame()
