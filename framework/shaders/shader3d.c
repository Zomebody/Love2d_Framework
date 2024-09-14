
#ifdef VERTEX
// camera variables
uniform vec3 cameraPosition;
uniform float cameraRotation;
uniform float cameraTilt;
uniform float cameraOffset;

uniform float aspectRatio;
uniform float fieldOfView;

const float zNear = 0.1;
const float zFar = 1000.0;

// IMPORTANT: in our world we apply rotation in the order Z, X, Y
// mesh variables
uniform vec3 meshPosition;
uniform vec3 meshRotation;
uniform vec3 meshScale;

// TODO: light variables
//uniform vec3 lightPositions[8]; // input world positions of lights
//uniform vec3 lightColors[8]; // input colors of lights
//uniform float lightRanges[8]; // input ranges of lights
//uniform float lightStrengths[8]; // input strengths of lights
//uniform vec3 ambientColorClose;
//uniform float ambientClose;
//uniform vec3 ambientColorFar;
//uniform float ambientFar;
//varying vec3 fragWorldPosition; // output automatically interpolated fragment world position
//varying float fragDistanceToCamera; // used for fog



// I DON'T KNOW WHY, BUT THE FUNCTIONS GETROTATIONMATRIX AND GETSCALEMATRIX AND GETTRANSLATIONMATRIX ARE ALL TRANSPOSED AND IT JUST KIND OF WORKS

// Function to create a rotation matrix around the X axis
mat4 getRotationMatrixX(float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return mat4(
		1.0, 0.0, 0.0, 0.0,
		0.0, c,   s,  0.0,
		0.0, -s,    c,  0.0,
		0.0, 0.0, 0.0, 1.0
	);
}



// Function to create a rotation matrix around the Y axis
mat4 getRotationMatrixY(float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return mat4(
		c,   0.0, -s,   0.0,
		0.0, 1.0, 0.0, 0.0,
		s,  0.0, c,   0.0,
		0.0, 0.0, 0.0, 1.0
	);
}



// Function to create a rotation matrix around the Z axis
mat4 getRotationMatrixZ(float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return mat4(
		c,   s,   0.0, 0.0,
		-s,    c,   0.0, 0.0,
		0.0,  0.0, 1.0, 0.0,
		0.0,  0.0, 0.0, 1.0
	);
}



mat4 getScaleMatrix(vec3 amount) {
	return mat4(
		amount.x, 0.0,      0.0,      0.0,
		0.0,      amount.y, 0.0,      0.0,
		0.0,      0.0,      amount.z, 0.0,
		0.0,      0.0,      0.0,      1.0
	);
}



mat4 getTranslationMatrix(vec3 translation) {
	return mat4(
		1.0, 0.0, 0.0, 0.0,
		0.0, 1.0, 0.0, 0.0,
		0.0, 0.0, 1.0, 0.0,
		translation.x, translation.y, translation.z, 1.0
	);
}



// vertical field-of-view is used
mat4 getPerspectiveMatrix(float fieldOfView, float aspect) {
	float tanHalfFov = tan(fieldOfView / 2.0);

	mat4 perspectiveMatrix = mat4(0.0);
	perspectiveMatrix[0][0] = 1.0 / (aspect * tanHalfFov);
	perspectiveMatrix[1][1] = 1.0 / (tanHalfFov);
	perspectiveMatrix[2][2] = -(zFar + zNear) / (zFar - zNear);
	perspectiveMatrix[2][3] = -1.0;
	perspectiveMatrix[3][2] = -(2.0 * zFar * zNear) / (zFar - zNear);
	perspectiveMatrix[3][3] = 0.0; // chatgpt suggested this for some reason????

	return perspectiveMatrix;
}



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



vec4 position(mat4 transform_projection, vec4 vertex_position) {
	// model transformations
	// get the scale matrix
	mat4 scaleMatrix = getScaleMatrix(meshScale);
	// get the rotation matrix in YXZ order
	mat4 rotationMatrix = getRotationMatrixZ(meshRotation.z) * getRotationMatrixY(meshRotation.y) * getRotationMatrixX(meshRotation.x);
	// get the translation matrix
	mat4 translationMatrix = getTranslationMatrix(meshPosition);
	// combine transformations. Transformations are applied from right to left. First scale, then rotate, then translate
	mat4 modelWorldMatrix = translationMatrix * rotationMatrix * scaleMatrix;
	//vec4 vertexWorldPosition = translationMatrix * rotationMatrix * scaleMatrix * vertex_position;

	// camera transformations
	// camera translation
	mat4 camTranslationMatrix = getTranslationMatrix(cameraPosition);
	// camera rotation
	mat4 camRotationMatrix = getRotationMatrixZ(cameraRotation) * getRotationMatrixX(cameraTilt);
	// camera offset
	mat4 camOffsetMatrix = getTranslationMatrix(vec3(0, 0, cameraOffset));
	// combine it all to get the camera matrix
	mat4 cameraWorldMatrix = camTranslationMatrix * camRotationMatrix * camOffsetMatrix; // offset first to create a pivot point to rotate around, then rotate, then translate to the right position


	mat4 viewMatrix = inverse(cameraWorldMatrix);

	// now go from world space to camera space, by applying the inverse of the world matrix. Essentially this moves the camera back to the world origin and the vertex is moved along
	mat4 cameraSpaceMatrix = viewMatrix *  modelWorldMatrix;

	// TODO: set the world position variable to pass onto the fragment shader
	//fragWorldPosition = (modelWorldMatrix * vertex_position).xyz; // sets the world position of this vertex. In the fragment shader this gets interpolated correctly automatically
	// TODO: calculate distance to camera for any fog applied in the fragment shader
	//fragDistanceToCamera = length(fragWorldPosition - cameraMatrix[3].xyz); // convert camera matrix to vec3 containing only the position


	// finally calculate the perspective projection matrix to move from camera space to screen space
	mat4 projectionMatrix = getPerspectiveMatrix(fieldOfView, aspectRatio);

	// Apply the view-projection transformation
	vec4 result = projectionMatrix * cameraSpaceMatrix * vertex_position;
	return result;
}

#endif



// Fragment Shader
#ifdef PIXEL

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
	// Check if a texture is applied by sampling from it
	vec4 texColor = Texel(tex, texture_coords);

	// Check if the alpha of the texture color is below a threshold
	//if (texColor.a < 0.1) {
	//	discard;  // Discard fully transparent pixels
	//}

	// lighting is done this way:
	// first calculate surface lighting on the fragment through adding the different point light colors at that fragment together
	// then calculate the ambient color at that fragment
	// finally multiply the two to get the resulting lighting at that fragment
	// then multiply the lighting with the surface color calculated below (vertex color and mesh image thing)


	// If the texture is effectively white (no texture) or the mesh has no texture applied
	// I don't think this is necessary?
	//if (texColor == vec4(1.0, 1.0, 1.0, 1.0)) {
	//	return color;  // Return the input color without modifying it
	//}

	// calculate surface lighting based on ambient and surrounding lights in range

	// Return the texture color multiplied by the input color
	return texColor * color;
	//return texColor;
}

#endif