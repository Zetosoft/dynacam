*# dynacam.**
### Overview
---

The Dynamic lighting camera system adds dynamic lighting and full camera tracking to your game using normal maps and light objects

### Notes

- All *lightObject* are created inside the **quantum.*** engine
- All *lightObject* inherit all properties and functions from the conventional *displayObject*. 
- All *lightObject* constructor functions from **quantum.*** engine are available and reflected on **dynacam.*** as well (You can use *dynacam.newGroup()*, for example)
- All **quantum.*** constructor functions take in the same parameters as the **display.*** library, except for specified parameters in the next section
- Physics bodies must be paired or created with a camera so lights can be calculated correctly for them

### Functions
---

- dynacam.*
	- dynacam.*newCamera(**options**)*
		- Returns new *cameraObject*
	- dynacam.*refresh()*
		- Refresh internal display values in case of a viewport dimensions change
- *cameraObject*
    - cameraObject:*start()*
    - cameraObject:*stop()*
    - cameraObject:*setBounds(**minX**, **maxX**, **minY**, **maxY**)*
    - cameraObject:*newLight(**options**)*
    - cameraObject:*addBody(**object**, **...**)*
        - Same as *physics.addBody()*, but auto registers body to camera for proper normal updating
    - cameraObject:*setFocus(**object**, **options**)*
    - cameraObject:*removeFocus()*
    - cameraObject:*toPoint(**x**, **y**, **options**)*
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

---
Copyright (c) 2019, Basilio Germán
All rights reserved.