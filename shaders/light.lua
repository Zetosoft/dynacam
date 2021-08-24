---------------------------------------------- Light shader - Lightmap is processed for later adding on a framebuffer - Basilio Germán
display.setDefault("isShaderCompilerVerbose", true)

local kernel = {}

kernel.language = "glsl"
kernel.category = "filter"
kernel.group = "dynacam"
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
	{
		name = "pointLightScale",
		default = 1,
		type = "scalar",
		index = 3, -- u_UserData3
	},
}

kernel.vertex = [[
uniform P_COLOR vec4 u_UserData0; // pointLightColor
uniform P_UV vec3 u_UserData1; // pointLightPos
uniform P_COLOR vec3 u_UserData2; // attenuationFactors
uniform P_DEFAULT float u_UserData3; // pointLightScale

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
uniform P_DEFAULT float u_UserData3; // pointLightScale

varying P_COLOR vec3 pointLightColor;

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
	P_NORMAL float proportion = CoronaTexelSize.y / CoronaTexelSize.x;
	P_UV vec3 fragmentToLight = (pointLightPos - vec3(texCoord, 0.0));
	fragmentToLight.x *= proportion;
	fragmentToLight.xy *= u_UserData3;

	P_UV vec3 lightDirection = normalize(fragmentToLight);
	
	// Distance attenuation.
	P_UV float attenuation = GetDistanceAttenuation( u_UserData2, length(fragmentToLight));

	// Apply light intensity, avoid negative intensities
	P_UV float diffuseIntensity = max(dot(lightDirection, normalPixel), 0.0);

	// Apply light distance attenuation.
	diffuseIntensity *= attenuation;

	// Add point light color.
	P_COLOR vec4 lightColor = vec4(pointLightColor * diffuseIntensity, 1.0);
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	#if 0 // Debug and testing
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
				// Gray when in top
				return vec4(0.5, 0.5, 0.5, 1.0);
			} else {
				// Red when behind
				return vec4(1.0, 0.0, 0.0, 1.0);
			}
		}
		else if (lightDistance < outer_threshold) {
			// White outline
			return vec4( 1.0, 1.0, 1.0, 1.0);
		}
	#endif

	return lightColor;
}
]]

graphics.defineEffect(kernel)

return kernel
