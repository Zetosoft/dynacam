---------------------------------------------- Apply shader - Mixes composites for final shaded result - Basilio Germán
display.setDefault("isShaderCompilerVerbose", true)

local kernel = {}

kernel.language = "glsl"
kernel.category = "composite"
kernel.group = "dynacam"
kernel.name = "apply"
kernel.uniformData =
{
	{
		name = "ambientLightColor",
		default = {0, 0, 0, 1}, -- Color RGB and intensity (alpha)
		min = {0, 0, 0, 0},
		max = {1, 1, 1, 1},
		type = "vec4",
		index = 0, -- u_UserData0
	},
}

kernel.vertex = [[
uniform P_COLOR vec4 u_UserData0; // ambientLightColor

varying P_COLOR vec3 ambientLightColor;

P_POSITION vec2 VertexKernel(P_POSITION vec2 position) {
	// Pre-multiply the light color with intensity
	ambientLightColor = (u_UserData0.rgb * u_UserData0.a);

	return position;
}
]]

kernel.fragment = [[
uniform P_COLOR vec4 u_UserData0; // ambientLightColor

varying P_COLOR vec3 ambientLightColor;

P_COLOR vec4 FragmentKernel(P_UV vec2 texCoord) {
	P_NORMAL float proportion = CoronaTexelSize.y / CoronaTexelSize.x;
	
	// Diffuse color
	P_COLOR vec4 diffuseColor = texture2D(u_FillSampler0, texCoord);

	// Lightmap color
	P_NORMAL vec4 lightBuffer = texture2D(u_FillSampler1, texCoord);
	
	// Intensity map
	P_COLOR vec3 bufferColor = lightBuffer.xyz;
	P_NORMAL float nothing = lightBuffer.w;
	
	diffuseColor.rgb *= ambientLightColor + bufferColor;
	
	return (diffuseColor * v_ColorScale);
}
]]

graphics.defineEffect(kernel)

return kernel
