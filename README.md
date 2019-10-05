*# dynacam.**
### Overview
---

The Dynamic lighting camera system adds dynamic lighting and full camera tracking to your game using normal maps and light objects

### Notes

- **dynacam.*** can only track *lightObject* type objects
- The **quantum.*** engine is responsible for *lightObject* creation
- All *lightObject* creator functions in **quantum.*** are available and reflected on **dynacam.*** as well (You can call *dynacam.newGroup()*, for example)
- All *lightObject* inherit all properties and functions from the conventional *displayObject*, Additional functions and properties are listed below
- All **quantum.*** constructor functions take in the same parameters as the **display.*** library, except for specified parameters listed below (Usually a normal map filename)
- Physics bodies must be added to or created with a camera so lights can be calculated correctly for them
- Lights can be created with **quantum.*** but will not be tracked until added to a camera as well

### Functions
---

- dynacam.*
	- dynacam.*newCamera(**options**)* : Returns new *cameraObject*
		- **options.damping** (number) Number specifying damping. Higher value means slower camera tracking. Default is 10
	- dynacam.*refresh()*
		- Refresh internal display values in case of a viewport dimensions change
- *cameraObject*
    - cameraObject:*start()*
        - Starts updating the camera
    - cameraObject:*stop()*
        - Stops updating the camera
    - cameraObject:*setBounds(**minX**, **maxX**, **minY**, **maxY**)*
        - Sets camera boundaries
    - cameraObject:*newLight(**options**)* : Creates and tracks new light
        - **options.color** (table) Table containing normalized RGB and intensity values
		- **options.attenuationFactors** (table) Table containing *constant*, *linear* and *quadratic* light attenuation factors
		- **options.z** (number) Light height (0 - 1 range)
    - cameraObject:*addBody(**object**, **...**)*
        - Create and track physics body. Uses same parameters as *physics.addBody()*
    - cameraObject:*setFocus(**object**, **options**)*
        - Will track and follow **object** in camera center
        - **options.soft** (bool) If *false*, focus will be immediate
        - **options.trackRotation** (bool) If *true*, will track object rotation
    - cameraObject:*removeFocus()*
        - Removes any object from focus
    - cameraObject:*toPoint(**x**, **y**, **options**)*
        - Sets focus on the specified **x** and **y** coordinates. **options** are the same as *cameraObject:setFocus()*
    - cameraObject:*setDebug(**value**)*
        - **value** (string/bool) Can be set to *true* to view lights as small dots, *"normal"* to view normal frameBuffer, or *"light"* to view lightBuffer
- quantum.*
	- quantum.*newGroup()*
	- quantum.*newLight(**options**)* : returns new untracked light. Must add light to camera using cameraObject.*addLight(**light**)*, or use cameraObject.*newLight(**options**)* to create a light instead.
		- **options.color** (table) Table containing normalized RGB and intensity values
		- **options.attenuationFactors** (table) Table containing *constant*, *linear* and *quadratic* light attenuation factors
		- **options.z** (number) Light height (0 - 1 range)
	- quantum.*newLine(**...**)*
	- quantum.*newCircle(**x**, **y**, **radius**)*
	- quantum.*newRect(**x**, **y**, **width**, **height**)*
	- quantum.*newRoundedRect(**x**, **y**, **width**, **height**, **cornerRadius**)*
	- quantum.*newImage(**filename**, **normalFilename**, **baseDir**)*
		- **normalFilename** (string) Normal map filename
	- quantum.*newContainer(**width**, **height**)*
	- quantum.*newImageRect(**filename**, **normalFilename**, **baseDir**, **width**, **height**)*
		- **normalFilename** (string) Normal map filename
	- quantum.*newPolygon(**x**, **y**, **vertices**)*
	- quantum.*newMesh(**options**)*
	- quantum.*newText(**options**)*
		- **options.normal** (table) Table containing normal vector values
	- quantum.*newSprite(**diffuseSheet**, **normalSheet**, **sequenceData**)*
		- **normalSheet** (table) same as diffuseSheet, but using normal map filename instead.
	- quantum.*newSnapshot(**width**, **height**)*

### Properties
---

- *lightObject*
    - lightObject.*normal* (paint) : Supports any paint like *lightObject.fill*, but is intended for normal maps


---
Copyright (c) 2019, Basilio Germán
All rights reserved.