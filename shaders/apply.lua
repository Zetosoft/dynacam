display.setDefault("isShaderCompilerVerbose", true)

local kernel = {}

kernel.language = "glsl"
kernel.category = "composite"
kernel.group = "custom"
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

P_NORMAL float proportion = CoronaTexelSize.y / CoronaTexelSize.x;

P_COLOR vec4 FragmentKernel(P_UV vec2 texCoord) {
	// Diffuse color
	P_COLOR vec4 texColor = texture2D(u_FillSampler0, texCoord);

	// Lightmap color
	P_NORMAL vec4 encoded = texture2D(u_FillSampler1, texCoord);
	P_NORMAL vec3 diffuseIntensity = encoded.xyz;
	
	// Intensity map
	P_NORMAL float intensity = encoded.w;
	
	texColor.rgb *= ambientLightColor + diffuseIntensity;

	return (texColor * v_ColorScale);
}
]]

graphics.defineEffect(kernel)

return kernel
