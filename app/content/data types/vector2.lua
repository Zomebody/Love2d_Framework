
local meta = {
	["Name"] = "vector2";
}

local content = {}

table.insert(content, {
	["Type"] = "IntroHeader";
	["Name"] = "The vector2 data type";
	["Description"] = "An object representing a 2D vector2.";
})

table.insert(content, {
	["Type"] = "Header";
	["Name"] = "Properties";
	["Description"] = "";
})

table.insert(content, {
	["Type"] = "Property";
	["Name"] = "x";
	["ValueType"] = "number";
	["ReadOnly"] = true;
	["Description"] = "The x component of the vector2.";
})

table.insert(content, {
	["Type"] = "Property";
	["Name"] = "y";
	["ValueType"] = "number";
	["ReadOnly"] = true;
	["Description"] = "The y component of the vector2.";
})

table.insert(content, {
	["Type"] = "Header";
	["Name"] = "Methods";
	["Description"] = "";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "angleDiff";
	["Arguments"] = {"vector2"};
	["Description"] = "Returns the smallest angle between itself and the given vector2, in radians.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "array";
	["Arguments"] = {};
	["Description"] = "Returns the vector2 in array form: {x,y}.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "clamp";
	["Arguments"] = {"min", "max"};
	["Description"] = "If the vector2's magnitude is smaller than min, it is scaled up to min. If the vector2's magnitude is larger than max, it is scaled down to max.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "clone";
	["Arguments"] = {"vector2"};
	["Description"] = "Create and return a new vector2 with the same x and y values as the given vector2.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "dist";
	["Arguments"] = {"vector2"};
	["Description"] = "Returns the Pythagorian distance between the current vector2 and the supplied vector2.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "dot";
	["Arguments"] = {"vector2"};
	["Description"] = "Returns the dot product between itself and the given vector2.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "getMag";
	["Arguments"] = {};
	["Description"] = "Calculates and returns the magnitude of the vector2, which is a simple 2D Pythagoras.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "heading";
	["Arguments"] = {};
	["Description"] = "Returns the current angle of the vector2 in radians.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "limit";
	["Arguments"] = {"number"};
	["Description"] = "If the vector2's magnitude if higher than the given number, it is scaled down to the given number.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "magSq";
	["Arguments"] = {};
	["Description"] = "Calculates and returns (x*x+y*y).";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "norm";
	["Arguments"] = {};
	["Description"] = "Normalizes the vector2. This means the vector2 is scaled to have a magnitude of exactly 1.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "pivot";
	["Arguments"] = {"angle", "vector2"};
	["Description"] = "Rotates the vector2 around a given vector2 by a given amount in radians. TODO: figure out if it's clockwise or counter-clockwise";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "projectOnto";
	["Arguments"] = {"vector2"};
	["Description"] = "Projects the vector2 onto the given vector2. This is like squiching the vector2 onto a surface, represented by the given factor. The example below visualizes the projection of the black vector2 onto the blue vector2, resulting in the new red vector2.";
	["Demo"] = function()
		local Image = love.graphics.newImage("test_images/projectOnto.png")
		local ImageFrame = ui.newImageFrame(Image)
		return ImageFrame
	end
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "reflect";
	["Arguments"] = {"normal", "multiplier"};
	["Description"] = "Reflects the vector2 along the given normal vector2, which is the same as mirroring the vector2 along a normal and then pointing it in the opposite direction. Multiplier will apply a scaling to the reflected vector2, but defaults to 1.\n\nBelow is a quick visualization where the black vector2 is being reflected along the blue line and then a multiplier of ~3 is applied.";
	["Demo"] = function()
		local Image = love.graphics.newImage("test_images/reflect.png")
		local ImageFrame = ui.newImageFrame(Image)
		return ImageFrame
	end
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "replace";
	["Arguments"] = {"vector2"};
	["Description"] = "Replace the values of itself with the values of the given vector2.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "rotate";
	["Arguments"] = {"angle"};
	["Description"] = "Rotates the vector2 by a given amount in radians. TODO: figure out if it's clockwise or counter-clockwise.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "rotateTo";
	["Arguments"] = {"vector2", "angle"};
	["Description"] = "Rotates the vector2 by a given amount in radians towards another direction vector2. This method will not overshoot if the amount to rotate by is larger than the angle between the two vector2s.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "set";
	["Arguments"] = {"x", "y"};
	["Description"] = "Sets the x and y value of the vector2. If 'x' is a vector2, that vector2's values will be copied instead.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "setMag";
	["Arguments"] = {"magnitude"};
	["Description"] = "Sets the magnitude of itself to the given value. This means the angle stays the same, but the size is scaled to fit the new magnitude. If the vector2 has a magnitude of 0, this will cause undocumented behavior.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "stretch";
	["Arguments"] = {"vector2", "factor"};
	["Description"] = "Stretches the vector2 along another vector2 by a given factor. 'factor' is a multiplier for how much the vector2 should be stretched. The example below is a stretch operation on the black vector2 along the blue vector2, with a factor of -2, resulting in the red vector2.";
	["Demo"] = function()
		local Image = love.graphics.newImage("test_images/stretch.png")
		local ImageFrame = ui.newImageFrame(Image)
		return ImageFrame
	end;
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "unpack";
	["Arguments"] = {};
	["Description"] = "Returns the x-value followed by the y-value.";
})

table.insert(content, {
	["Type"] = "Constructor";
	["Name"] = "__add";
	["Arguments"] = {"vector2"};
	["Description"] = "Returns the result of the addition between two vector2s.";
})

table.insert(content, {
	["Type"] = "Constructor";
	["Name"] = "__div";
	["Arguments"] = {"vector2"};
	["Description"] = "Returns the division of two vector2s.";
})

table.insert(content, {
	["Type"] = "Constructor";
	["Name"] = "__eq";
	["Arguments"] = {"vector2"};
	["Description"] = "Returns true if the two vector2s have the same x and y values, and false otherwise.";
})

table.insert(content, {
	["Type"] = "Constructor";
	["Name"] = "__mul";
	["Arguments"] = {"vector2"};
	["Description"] = "Returns the product of two vector2s.";
})

table.insert(content, {
	["Type"] = "Constructor";
	["Name"] = "__sub";
	["Arguments"] = {"vector2"};
	["Description"] = "Returns the result of the subtraction between two vector2s.";
})

table.insert(content, {
	["Type"] = "Constructor";
	["Name"] = "__tostring";
	["Arguments"] = {};
	["Description"] = "Prints the color in the form (x,y,z).";
})

table.insert(content, {
	["Type"] = "Constructor";
	["Name"] = "__unm";
	["Arguments"] = {};
	["Description"] = "Inverts the x and y components of the vector2.";
})


return {
	["Meta"] = meta;
	["Content"] = content;
}