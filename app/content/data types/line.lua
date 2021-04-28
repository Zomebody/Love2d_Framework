

local getpath = require("framework.getpath")
local ui = require(getpath("framework/modules/ui"))
local vector = require(getpath("framework/datatypes/vector"))
local color = require(getpath("framework/datatypes/color"))
local line = require(getpath("framework/datatypes/line"))


local meta = {
	["Name"] = "line";
}

local content = {}

table.insert(content, {
	["Type"] = "IntroHeader";
	["Name"] = "The line data type";
	["Description"] = "An object representing a line.";
})

table.insert(content, {
	["Type"] = "Header";
	["Name"] = "Properties";
	["Description"] = "";
})

table.insert(content, {
	["Type"] = "Property";
	["Name"] = "from";
	["ValueType"] = "vector";
	["ReadOnly"] = true;
	["Description"] = "A vector representing the starting point of the line.";
})

table.insert(content, {
	["Type"] = "Property";
	["Name"] = "normal";
	["ValueType"] = "vector";
	["ReadOnly"] = true;
	["Description"] = "A normalized vector perpendicular to the direction of the line.";
})

table.insert(content, {
	["Type"] = "Property";
	["Name"] = "to";
	["ValueType"] = "vector";
	["ReadOnly"] = true;
	["Description"] = "A vector representing the end point of the line.";
})

table.insert(content, {
	["Type"] = "Header";
	["Name"] = "Methods";
	["Description"] = "";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "array";
	["Arguments"] = {};
	["Description"] = "Returns an array representing the line, as {x1,y1,x2,y2}.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "clone";
	["Arguments"] = {};
	["Description"] = "Creates a new line using the same parameters as the current line.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "closestTo";
	["Arguments"] = {"vector"};
	["Description"] = "Returns a position on the line that is closest to the given vector.";
	["CodeMarkup"] = "<k>local</k> l = <f>line</f>(<n>20</n>, <n>20</n>, <n>130</n>, <n>80</n>)\n<k>local</k> p = <f>vector</f>(<n>40</n>, <n>70</n>)\n<k>local</k> c = l:<f>closestTo</f>(p)\nlove.graphics.<f>line</f>(l:<f>unpack</f>())\nlove.graphics.<f>setColor</f>(<n>1</n>, <n>0</n>, <n>0</n>)\nlove.graphics.<f>circle</f>(<s>\"fill\"</s>, p.x, p.y, <n>6</n>)\nlove.graphics.<f>setColor</f>(<n>0</n>, <n>0.5</n>, <n>1</n>)\nlove.graphics.<f>circle</f>(<s>\"fill\"</s>, c.x, c.y, <n>6</n>)";
	["Demo"] = function()
		local Canvas = love.graphics.newCanvas(150, 90)
		Canvas:renderTo(
			function()
				love.graphics.setLineWidth(2)
				love.graphics.setColor(0, 0, 0)
				love.graphics.rectangle("fill", 0, 0, 150, 90)
				local l = line(20, 20, 130, 80)
				local p = vector(40, 70)
				local c = l:closestTo(p)
				love.graphics.setColor(1, 1, 1)
				love.graphics.line(l:unpack())
				love.graphics.setColor(1, 0, 0)
				love.graphics.circle("fill", p.x, p.y, 6)
				love.graphics.setColor(0, 0.5, 1)
				love.graphics.circle("fill", c.x, c.y, 6)
				love.graphics.setColor(1, 1, 1)
			end
		)
		return ui.newImageFrame(Canvas)
	end;
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "disTo";
	["Arguments"] = {"vector"};
	["Description"] = "Returns the distance between the given vector and the point on the line closest to that vector.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "getCenter";
	["Arguments"] = {};
	["Description"] = "Returns a vector that is at the center position of the line.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "getLength";
	["Arguments"] = {};
	["Description"] = "Returns the length of the line.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "interpolation";
	["Arguments"] = {"alpha"};
	["Description"] = "Returns a position along the line. If alpha is 0, it returns the starting point. If 1, it returns the end point. 0.5 is the middle, and so on.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "intersect";
	["Arguments"] = {"line"};
	["Description"] = "If the current line overlaps the given line, this returns the location of intersection. Otherwise it returns nil.";
	["CodeMarkup"] = "";
	["Demo"] = function()
		local Canvas = love.graphics.newCanvas(160, 120)
		Canvas:renderTo(
			function()
				love.graphics.setLineWidth(2)
				love.graphics.setColor(0, 0, 0)
				love.graphics.rectangle("fill", 0, 0, 160, 160)
				love.graphics.setColor(1, 1, 1)
				local l1 = line(20, 50, 110, 75)
				local l2 = line(35, 100, 130, 25)
				local hit = l1:intersect(l2)
				love.graphics.line(l1:unpack())
				love.graphics.line(l2:unpack())
				love.graphics.setColor(1, 0, 0)
				love.graphics.circle("fill", hit.x, hit.y, 6)
			end
		)
		return ui.newImageFrame(Canvas)
	end;
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "moveTo";
	["Arguments"] = {"vector", "vector"};
	["Description"] = "Sets the starting point and end point of the line to the two provided vectors (in order). This updates its normal as well.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "replace";
	["Arguments"] = {"line"};
	["Description"] = "Replaces the properties of the current line with the values of the given line.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "shift";
	["Arguments"] = {"x", "y"};
	["Description"] = "Offsets the line in the horizontal and vertical axis. Instead of two number, the first argument may also be a vector.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "toVector";
	["Arguments"] = {};
	["Description"] = "Returns a new vector that is the end point minus the starting point.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "unpack";
	["Arguments"] = {};
	["Description"] = "The same as the :array() method, but this returns a tuple as opposed to a table.";
})





table.insert(content, {
	["Type"] = "Method";
	["Name"] = "__eq";
	["Arguments"] = {};
	["Description"] = "Returns true if the two compared objects are both line instances.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "__tostring";
	["Arguments"] = {};
	["Description"] = "Returns a string which is the line in the form {vector,vector} where the first vector is the starting point and the second vector is the end point.";
})


return {
	["Meta"] = meta;
	["Content"] = content;
}