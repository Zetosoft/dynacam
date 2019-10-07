---------------------------------------------- Rotate shader - Fixes normal vectors when object is rotated - Basilio Germán
display.setDefault("isShaderCompilerVerbose", true)

local kernel = {}

kernel.language = "glsl"
kernel.category = "filter"
kernel.group = "custom"
kernel.name = "rotate"
kernel.vertexData =
{
	{
		name = "rotation",
		default = 0,
		type = "scalar",
		index = 0, -- CoronaVertexUserData.x
	},
	{
		name = "xMult",
		default = 1,
		type = "scalar",
		index = 1, -- CoronaVertexUserData.y
	},
	{
		name = "yMult",
		default = 1,
		type = "scalar",
		index = 2, -- CoronaVertexUserData.z
	},
}
kernel.fragment = [[
P_POSITION vec2 rotate(vec2 vector, float angle) {
	P_DEFAULT float s = sin(angle);
	P_DEFAULT float c = cos(angle);
	P_DEFAULT mat2 m = mat2(c, -s, s, c);

	return m * vector;
}

P_COLOR vec4 FragmentKernel( P_UV vec2 texCoord ){
	P_NORMAL vec4 normalPixel = texture2D(CoronaSampler0, texCoord);
	
	normalPixel.xy -= 0.5; // Normal vectors are aligned from the center
	normalPixel.x *= CoronaVertexUserData.y;
	normalPixel.y *= CoronaVertexUserData.z;
	normalPixel.xy = rotate(normalPixel.xy, CoronaVertexUserData.x);
	normalPixel.xy += 0.5;
	
	normalPixel.xy *= normalPixel.w;

	return CoronaColorScale(normalPixel);
}
]]

graphics.defineEffect(kernel)

return kernel

