local screen = require("screen")

display.setDefault("isShaderCompilerVerbose", true)

local kernel = {}

kernel.language = "glsl"
kernel.category = "filter"
kernel.group = "custom"
kernel.name = "light"
kernel.uniformData =
{
	{
		name = "pointLightColor",
		default = {1, 1, 1, 1}, -- Color RGB and intensity (alpha)
		min = {0, 0, 0, 0},
		max = {1, 1, 1, 1},
		type = "vec4",
		index = 0, -- u_UserData0
	},
	{
		name = "pointLightPos",
		default = {0.5, 0.5, 0.5}, -- x, y, z
		min = {0, 0, 0},
		max = {1, 1, 1},
		type = "vec3",
		index = 1, -- u_UserData1
	},
	{
		name = "attenuationFactors",
		default = {0.4, 3, 20}, -- Constant, Linear, Quadratic
		type = "vec3",
		index = 2, -- u_UserData2
	},
}

kernel.vertex = [[
uniform P_COLOR vec4 u_UserData0; // pointLightColor
uniform P_UV vec3 u_UserData1; // pointLightPos
uniform P_COLOR vec3 u_UserData2; // attenuationFactors

varying P_COLOR vec3 pointLightColor;

P_POSITION vec2 VertexKernel(P_POSITION vec2 position) {
	// Pre-multiply the light color with intensity
	pointLightColor = (u_UserData0.rgb * u_UserData0.a);

	return position;
}
]]

kernel.fragment = [[
uniform P_COLOR vec4 u_UserData0; // pointLightColor
uniform P_UV vec3 u_UserData1; // pointLightPos
uniform P_COLOR vec3 u_UserData2; // attenuationFactors

varying P_COLOR vec3 pointLightColor;

P_NORMAL float proportion = CoronaTexelSize.y / CoronaTexelSize.x;

P_UV float GetDistanceAttenuation(in P_UV vec3 attenuationFactors, in P_UV float lightDistance) {
	P_UV float constantFactor = attenuationFactors.x;
	P_UV float linearFactor = attenuationFactors.y;
	P_UV float quadraticFactor = attenuationFactors.z;

	// Calculate attenuation
	P_UV float constantAtt = constantFactor;
	P_UV float linearAtt = (linearFactor * lightDistance);
	P_UV float quadraticAtt = (quadraticFactor * lightDistance * lightDistance);

	return (1.0 / (constantAtt + linearAtt + quadraticAtt));
}

P_COLOR vec4 FragmentKernel(P_UV vec2 texCoord) {
	P_UV vec3 pointLightPos = u_UserData1;

	// Get normal map pixel values
	P_NORMAL vec3 normalPixel = texture2D( u_FillSampler0, texCoord).xyz;

	// Transform from 0.0 <> 1.0 to -1.0 <> 1.0 range.
	normalPixel.xyz = normalize((normalPixel.xyz * 2.0) - 1.0);

	// Invert Y component as Corona is inverted
	normalPixel.y = -normalPixel.y;
	
	// Fix scale proportion
	P_UV vec3 fragment_to_light = (pointLightPos - vec3(texCoord, 0.0));
	fragment_to_light.x *= proportion;

	P_UV vec3 lightDirection = normalize(fragment_to_light);
	
	// Distance attenuation.
	P_UV float attenuation = GetDistanceAttenuation( u_UserData2, length(fragment_to_light));

	// Apply light intensity, avoid negative intensities
	P_UV float diffuseIntensity = max(dot(lightDirection, normalPixel), 0.0);

	// Apply light distance attenuation.
	diffuseIntensity *= attenuation;

	// Add point light color.
	P_COLOR vec4 lightColor = vec4(pointLightColor * diffuseIntensity, 1.0);

	////////////////////////////////////////////////////////////////////////////////////////////////
	#if 1 // Debug and testing
		// Adjust for resolution
		P_UV vec2 adjustedTexCoord = vec2(texCoord);
		adjustedTexCoord.x *= proportion;
		
		P_UV vec2 adjustedPos = vec2(pointLightPos.xy);
		adjustedPos.x *= proportion;
		
		P_UV float lightDistance = distance(adjustedTexCoord, adjustedPos);

		// Inner and outer thresholds
		const P_UV float inner_threshold = (1.0 / 150.0);
		const P_UV float outer_threshold = (1.0 / 130.0);

		if (lightDistance < inner_threshold) {
			if( pointLightPos.z >= 0.0 ) {
				// White when in top
				return vec4(0.5, 0.5, 0.5, 1.0);
			} else {
				// Red when behind
				return vec4(1.0, 0.0, 0.0, 1.0);
			}
		}
		else if(lightDistance < outer_threshold) {
			// The outline is always white.
			return vec4( 1.0, 1.0, 1.0, 1.0 );
		}
	#endif

	#if 0 // Debug and testing
		return (lightColor * v_ColorScale);
	#endif

	return vec4((pointLightColor * diffuseIntensity), diffuseIntensity);
}
]]

graphics.defineEffect(kernel)

return kernel
