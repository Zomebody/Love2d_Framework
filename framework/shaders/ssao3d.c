// SSAO Shader

uniform mat4 perspectiveMatrix;
uniform mat4 camMatrix;

uniform float aoStrength;
uniform float kernelScalar;
//uniform float viewDistanceFactor;

uniform Image noiseTexture; // assumed to be a 16x16 noise texture where r,g,b = x,y,z normal vector with z>0

const float rangeCheckScalar = 10.0; // larger value == need to zoom out further for AO to fade away

/*
const float zNear = 0.1;
const float zFar = 1000.0;
*/
//const int sampleSize = 16;//16; // Number of samples
//const float kernelScalar = 0.85;

const vec2 sampleOffsets[16] = vec2[](
	/*
	vec2(-0.1, -0.1),
	vec2(-0.1, 0.0),
	vec2(-0.1, 0.1),
	vec2(0.0, -0.1),
	vec2(0.0, 0.0),
	vec2(0.0, 0.1),
	vec2(0.1, -0.1),
	vec2(0.1, 0.0),
	vec2(0.1, 0.1)
	*/
	vec2(-0.075, -0.075),
	vec2(-0.025, -0.075),
	vec2(0.025, -0.075),
	vec2(0.075, -0.075),
	vec2(-0.075, -0.025),
	vec2(-0.025, -0.025),
	vec2(0.025, -0.025),
	vec2(0.075, -0.025),
	vec2(-0.075, 0.025),
	vec2(-0.025, 0.025),
	vec2(0.025, 0.025),
	vec2(0.075, 0.025),
	vec2(-0.075, 0.075),
	vec2(-0.025, 0.075),
	vec2(0.025, 0.075),
	vec2(0.075, 0.075)
);

/*
const vec3 kernel[256] = vec3[]( // kernel[sampleSize]
	// first sphere
	vec3(0.0345, 0.0939, 0.0100),
	vec3(-0.0472, 0.0768, 0.0433),
	vec3(0.0070, 0.0597, 0.0799),
	vec3(0.0550, 0.0427, 0.0718),
	vec3(-0.0952, 0.0256, 0.0168),
	vec3(0.0841, 0.0085, 0.0535),
	vec3(-0.0259, -0.0085, 0.0962),
	vec3(-0.0446, -0.0256, 0.0858),
	vec3(0.0850, -0.0427, 0.0310),
	vec3(-0.0741, -0.0597, 0.0306),
	vec3(0.0271, -0.0768, 0.0580),
	vec3(0.0103, -0.0939, 0.0329),
	// second sphere
	vec3(0.0355, 0.0484, 0.0100),
	vec3(-0.0426, 0.0161, 0.0390),
	vec3(0.0051, -0.0161, 0.0576),
	vec3(0.0216, -0.0484, 0.0282)
);
*/



mat4 inverse(mat4 m) {
	float
		a00 = m[0][0], a01 = m[0][1], a02 = m[0][2], a03 = m[0][3],
		a10 = m[1][0], a11 = m[1][1], a12 = m[1][2], a13 = m[1][3],
		a20 = m[2][0], a21 = m[2][1], a22 = m[2][2], a23 = m[2][3],
		a30 = m[3][0], a31 = m[3][1], a32 = m[3][2], a33 = m[3][3],

	b00 = a00 * a11 - a01 * a10,
	b01 = a00 * a12 - a02 * a10,
	b02 = a00 * a13 - a03 * a10,
	b03 = a01 * a12 - a02 * a11,
	b04 = a01 * a13 - a03 * a11,
	b05 = a02 * a13 - a03 * a12,
	b06 = a20 * a31 - a21 * a30,
	b07 = a20 * a32 - a22 * a30,
	b08 = a20 * a33 - a23 * a30,
	b09 = a21 * a32 - a22 * a31,
	b10 = a21 * a33 - a23 * a31,
	b11 = a22 * a33 - a23 * a32,

	det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;

	if (abs(det) < 0.00001) {
		return mat4(1.0); // If determinant is 0, return identity matrix (or handle however you want)
	}

	float invDet = 1.0 / det;

	return mat4(
		(a11 * b11 - a12 * b10 + a13 * b09) * invDet,
		(a02 * b10 - a01 * b11 - a03 * b09) * invDet,
		(a31 * b05 - a32 * b04 + a33 * b03) * invDet,
		(a22 * b04 - a21 * b05 - a23 * b03) * invDet,
		(a12 * b08 - a10 * b11 - a13 * b07) * invDet,
		(a00 * b11 - a02 * b08 + a03 * b07) * invDet,
		(a32 * b02 - a30 * b05 - a33 * b01) * invDet,
		(a20 * b05 - a22 * b02 + a23 * b01) * invDet,
		(a10 * b10 - a11 * b08 + a13 * b06) * invDet,
		(a01 * b08 - a00 * b10 - a03 * b06) * invDet,
		(a30 * b04 - a31 * b02 + a33 * b00) * invDet,
		(a21 * b02 - a20 * b04 - a23 * b00) * invDet,
		(a11 * b07 - a10 * b09 - a12 * b06) * invDet,
		(a00 * b09 - a01 * b07 + a02 * b06) * invDet,
		(a31 * b01 - a30 * b03 - a32 * b00) * invDet,
		(a20 * b03 - a21 * b01 + a22 * b00) * invDet
	);
}






float calculateOcclusion(vec3 fragmentPos, vec3 normal, vec2 texCoord, Image depthTexture, mat4 invPerspectiveMatrix) {
	float occlusion = 0.0;

	// calculate a matrix that will transform a normal vector from world-space to surface-space
	vec3 up = abs(normal.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 tangent = normalize(cross(up, normal));
	vec3 bitangent = cross(normal, tangent);
	mat3 TBN = mat3(tangent, bitangent, normal); // transforms a vector from world-space to the surface normal space

	vec2 noiseSamplePosition = vec2(
		float(love_PixelCoord.x) / 2.65, // the image is 16x16 but the image repeats and so if we divide by a weird number it breaks up repetition
		float(love_PixelCoord.y) / 2.65
	);


	for (int i = 0; i < 9; i++) { // for (int i = 0; i < sampleSize; i++) {
		vec3 kernelVector = (Texel(noiseTexture, noiseSamplePosition + sampleOffsets[i])).xyz * 2.0 - vec3(1.0, 1.0, 1.0);
		vec3 worldSampleDir = TBN * kernelVector * kernelScalar; // for the current index in the kernel, calculate where it's pointing in world-space when placed on the mesh's surface
		vec3 sampleWorldPos = fragmentPos + worldSampleDir; // offset sample in world space

		// project sample position to screen space
		vec4 sampleScreenPos = perspectiveMatrix * vec4(sampleWorldPos, 1.0);
		sampleScreenPos /= sampleScreenPos.w; // Perspective divide
		vec2 sampleTexCoord = sampleScreenPos.xy * 0.5 + 0.5; // Map to [0, 1]

		float sampleDepth = Texel(depthTexture, sampleTexCoord).r;
		vec4 sampledFragmentWorldPos = invPerspectiveMatrix * vec4(sampleScreenPos.xy, sampleDepth, 1.0);
		sampledFragmentWorldPos /= sampledFragmentWorldPos.w;

		// compare depths to check for occlusion
		// these two lines were stolen from: https://learnopengl.com/Advanced-Lighting/SSAO
		if (sampledFragmentWorldPos.z > sampleWorldPos.z) { // check if the fragment at a the sampled screen coordinate is in front of a random sampled ambient point near the surface we're evaluating
			
			// let's spice this occlusion checker up a bit. We'll calculate a rangeCheck variable that will make ambient occlusion less intense as you zoom out
			// we'll also calculate a value that checks the *world space* distance between our surface point and the sampled nearby (occluded) point. As the gap between them grows, make occlusion less intense
			// for this gap we can re-use the kernelScalar value!
			
			float rangeCheck = smoothstep(0.0, 1.0, rangeCheckScalar / abs(fragmentPos.z - sampleDepth));
			float gapSize = sampledFragmentWorldPos.z - sampleWorldPos.z;
			float darkenFactor = pow(clamp(1.0 - gapSize * kernelScalar, 0.0, 1.0), 3);
			//float gapFactor = pow(clamp(1.0 - (gapSize / kernelScalar), 0.0, 1.0), 0.25); // value between 0 and 1 where 

			occlusion += darkenFactor * rangeCheck;

			// TODO: finish this section
			
		}
	}

	return occlusion / 16.0; // float(sampleSize) // (sampleSize = 16) Normalize occlusion
}






uniform Image normalTexture;


vec4 effect(vec4 color, Image tex, vec2 texCoord, vec2 screenCoords) {
	float depth = Texel(tex, texCoord).r;
	if (depth == 1.0) {
		return vec4(1.0); // No occlusion in empty space
	}



	// Reconstruct world position
	vec4 screenPos = vec4(texCoord * 2.0 - 1.0, depth, 1.0);
	//mat4 viewProjectionMatrix = perspectiveMatrix;
	mat4 invPerspectiveMatrix = inverse(perspectiveMatrix);
	vec4 worldPos = invPerspectiveMatrix * screenPos;
	worldPos /= worldPos.w;

	// Get normal from normal texture
	vec3 normal = Texel(normalTexture, texCoord).rgb * 2.0 - 1.0;
	//normal = (camMatrix * vec4(normal, 1.0)).xyz;

	// Calculate ambient occlusion
	
	float occlusion = calculateOcclusion(worldPos.xyz, normal, texCoord, tex, invPerspectiveMatrix);

	return vec4(vec3(1.0 - occlusion * aoStrength), 1.0); // Darken by occlusion amount

}


