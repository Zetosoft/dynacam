*# dynacam.**
### Overview
---

Dynamic Lights + Camera

Feel that your game needs to expand beyond the screen limits? Want to add dynamic lighting effects to your game? This is the plugin for you.
This plugin adds dynamic lighting and full camera tracking to your game using normal maps and light objects.

### Notes

- The **quantum.*** engine is responsible for *lightObject* creation
- All *lightObject* creator functions in **quantum.*** are available and reflected on **dynacam.*** as well (You can call *dynacam.newGroup()*, for example)
- All *lightObject* inherit all properties and functions from the conventional *displayObject*, Additional functions and properties are listed below
- All **quantum.*** constructor functions take in the same parameters as the **display.*** library, except for specified parameters listed below (Usually a normal map filename)
- Physics bodies must be added to, or created with a camera, so lights can be calculated correctly for them
- Lights can be created with **quantum.*** but will not be tracked until added to a camera as well
- groups can be inserted into lightGroups, but will not work correctly the other way around.

### Gotchas
- Because objects are drawn to a canvas, and the graphics engine "owns" these objects, touch, tap, and mouse listeners are forwarded using a mirror object hierarchy that sit on front of the canvas. Complex, large objects will make the engine stutter if the hierarchy is too dynamic (Objects deleted, created, moved or scaled constantly).
- All default functions have been replaced with a pointer table, for your own safety do not reference them/it as it loses its pointed function after referencing it again, even with a different index (translate, scale, rotate, etc.)
- Performance wise, light objects count as 2 display objects, event forwarded objects count as 3, so these can stack up easily, test well for performance!

### Functions
---

- dynacam.*
	- dynacam.*newCamera(**options**)* : Returns new *cameraObject*
		- **options.damping** (number) Number specifying damping. Higher value means slower camera tracking. Default is 10
		- **options.ambientLightColor** (table) 4 Indexed table specifying RGB and intensity respective float values. Default is black *{0, 0, 0, 1}*
	- dynacam.*refresh()*
		- Refresh internal display values in case of a viewport dimensions change
- *cameraObject*
    - cameraObject:*add(**lightObject**, **isFocus**)*
        - Add specified *lightObject* to camera hierarchy. Think of it like an *:insert()* replacement.
    - cameraObject:*start()*
        - Starts updating the camera
    - cameraObject:*stop()*
        - Stops updating the camera
    - cameraObject:*getZoom()*
        - Returns zoom value. Default is 1
    - cameraObject:*setZoom(**zoom**, **zoomDelay**, **zoomTime**, **onComplete**)*
        - Sets camera **zoom** (number), as a scale number
        - **zoomDelay** (number) delay in milliseconds before zoom begins or sets
        - **zoomTime** (number) time in milliseconds for zoom to get to specified value
        - **onComplete** Optional function called when zoom animation completes.
    - cameraObject:*setBounds(**minX**, **maxX**, **minY**, **maxY**)*
        - Sets camera boundaries
    - cameraObject:*newLight(**options**)* : Creates and tracks new light
        - **options.color** (table) Table containing normalized RGB and intensity values
		- **options.attenuationFactors** (table) Table containing *constant*, *linear* and *quadratic* light attenuation factors
		- **options.z** (number) Light height (0 - 1 range)
	- cameraObject:*trackLight(**light**)*
	    - Adds light to camera so light can be rendered
    - cameraObject:*addBody(**object**, **...**)*
        - Create and track physics body. Uses same parameters as *physics.addBody()*
    - cameraObject:*trackBody(**body**)*
        - Track physics body. Used to update physics body normal rotation correctly. Lights will not work on a physics body correctly until tracked by a camera.
    - cameraObject:*setFocus(**object**, **options**)*
        - Will track and follow **object** in camera center.
        - **options.soft** (bool) If *false*, focus will be immediate
        - **options.trackRotation** (bool) If *true*, will track object rotation
    - cameraObject:*removeFocus()*
        - Removes any object from focus
    - cameraObject:*toPoint(**x**, **y**, **options**)*
        - Sets focus on the specified **x** and **y** coordinates. **options** are the same as *cameraObject:setFocus()*
    - cameraObject:*setDrawMode(**value**)*
        - **value** (string/bool) Can be set to one of the following:
            - *true* to view lights as small dots
            - *"diffuse"* to view diffuse frameBuffer
            - *"normal"* to view normal frameBuffer
            - *"listeners"* to view touch forward areas.
            - *"light"* to view lightBuffer
    - cameraObject:*addListenerObject(**object**)*
        - Internal function used to forward touch, tap and mouse events to objects owned by the camera canvas. This is done automatically and internally by all *lightObject*
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
    - lightObject.*normal* (paint) : Supports any paint like *lightObject.fill*, but is intended for normal maps. A normal map rotation fix effect is placed by default, if removed, normal maps will stop illuminating correctly if rotated!
	- lightObject.*super* (table) : Table to call default display object functions that only affect the diffuse part of the object. for example: `lightObject.super:setFillColor(1)`
- *cameraObject*
    - cameraObject.values.*targetRotation* (number) : Use this value to manually rotate the internal camera view.

---
Copyright (c) 2019, Basilio Germán
All rights reserved.