
local meta = {
	["Name"] = "navmesh";
}

local content = {}

table.insert(content, {
	["Type"] = "IntroHeader";
	["Name"] = "Navmesh data structure";
	["Description"] = "A navmesh is a 2d datastructure for A-star pathfinding. It supports arbitrary shapes.";
})

table.insert(content, {
	["Type"] = "Header";
	["Name"] = "Constructors";
	["Description"] = "";
})

table.insert(content, {
	["Type"] = "Constructor";
	["Name"] = "new";
	["Arguments"] = {"trisOrLines", "margin"};
	["Description"] = "Creates a new navmesh instance.\n- trisOrLines: an array containing either triangle instances of line2 instances. In the case of a triangle, its whole volume is traversable. For lines, you can only pathfind along the lines.\n- margin: Defaults to 0.01. When pathfinding, a path along the edges of the graph is constructed. Then during post-processing, shortcuts *through* triangles are considred. However, due to floating point precision shortcuts may not always get found. Adding a margin helps in finding those shortcuts, but if the margin is too large the algorithm may return a path that goes through walls.";
	["CodeMarkup"] = "<k>local</k> t1 <k>=</k> <f>triangle</f>(<f>vector2</f>(<n>30</n>, <n>30</n>), <f>vector2</f>(<n>60</n>, <n>70</n>), <f>vector2</f>(<n>15</n>, <n>85</n>))\n<k>local</k> t2 <k>=</k> <f>triangle</f>(<f>vector2</f>(<n>30</n>, <n>30</n>), <f>vector2</f>(<n>60</n>, <n>70</n>), <f>vector2</f>(<n>80</n>, <n>20</n>))\n<k>local</k> t3 <k>=</k> <f>triangle</f>(<f>vector2</f>(<n>130</n>, <n>20</n>), <f>vector2</f>(<n>180</n>, <n>55</n>), <f>vector2</f>(<n>140</n>, <n>75</n>))\n<k>local</k> l <k>=</k> <f>line2</f>(<f>vector2</f>(<n>80</n>, <n>20</n>), <f>vector2</f>(<n>130</n>, <n>20</n>))\n\n<k>local</k> navigator <k>=</k> <f>navmesh</f>({t1, t2, t3, l}, <n>0.01</n>)\n<k>local</k> path <k>=</k> navigator:<f>pathfind</f>(<f>vector2</f>(<n>30</n>, <n>70</n>), <f>vector2</f>(<n>165</n>, <n>75</n>), <n>15</n>)\n<c>-- visualize path here</c>";
	["Demo"] = function()
		local canvas = love.graphics.newCanvas(200, 100)
		canvas:renderTo(
			function()
				local t1 = triangle(vector2(30, 30), vector2(60, 70), vector2(15, 85))
				local t2 = triangle(vector2(30, 30), vector2(60, 70), vector2(80, 20))
				local t3 = triangle(vector2(130, 20), vector2(180, 55), vector2(140, 75))
				local l = line2(vector2(80, 20), vector2(130, 20))

				local navigator = navmesh({t1, t2, t3, l}, 0.01)
				local path = navigator:pathfind(vector2(30, 70), vector2(165, 75), 15)

				local lw = love.graphics.getLineWidth()
				local r, g, b, a = love.graphics.getColor()
				love.graphics.setColor(0, 0, 0)
				love.graphics.rectangle("fill", 0, 0, 200, 100)
				love.graphics.setColor(1, 1, 1)

				love.graphics.setLineWidth(3)
				for node, connected in pairs(navigator.Connections) do
					local nodeVector = navigator.Vectors[node]
					for i, _ in pairs(connected) do -- use pairs because the array may have holes in it
						local otherVector = navigator.Vectors[i]
						love.graphics.line(nodeVector.x, nodeVector.y, otherVector.x, otherVector.y)
					end
				end

				love.graphics.setLineWidth(2)
				love.graphics.setColor(1, 0.3, 0.6)
				for i = 1, #path - 1 do
					love.graphics.line(path[i].x, path[i].y, path[i+1].x, path[i+1].y)
				end

				love.graphics.setColor(0.3, 0.3, 1)
				love.graphics.circle("fill", 30, 70, 3)
				love.graphics.setColor(0.2, 1, 0.4)
				love.graphics.circle("fill", 165, 75, 3)

				love.graphics.setLineWidth(lw)
				love.graphics.setColor(r, g, b, a)
			end
		)
		return ui.newImageFrame(canvas)
	end
})

table.insert(content, {
	["Type"] = "Header";
	["Name"] = "Properties";
	["Description"] = "Note that these are the properties of a quadtree, not of the module creating the quadtrees!";
})

table.insert(content, {
	["Type"] = "Property";
	["Name"] = "Connections";
	["ValueType"] = "dictionary";
	["ReadOnly"] = true;
	["Description"] = "FOR INTERNAL USE ONLY. A dictionary that stores which vectors in the Vectors array are connected to each other. Keys are node numbers (the index in the Vectors array) and values are arrays with node ids that the given key is connected to.";
})

table.insert(content, {
	["Type"] = "Property";
	["Name"] = "Margin";
	["ValueType"] = "number";
	["ReadOnly"] = true;
	["Description"] = "The margin supplied when creating the navmesh. Margins are used during pathfinding to prevent floating point imprecision from ruling out more direct paths.";
})

table.insert(content, {
	["Type"] = "Property";
	["Name"] = "Quadtree";
	["ValueType"] = "quadtree";
	["ReadOnly"] = true;
	["Description"] = "The quadtree used internally for faster look-ups when checking if a given start and end-point falls within the navmesh.";
})

table.insert(content, {
	["Type"] = "Property";
	["Name"] = "Vectors";
	["ValueType"] = "array";
	["ReadOnly"] = true;
	["Description"] = "FOR INTERNAL USE ONLY. An array of vector2s that make up the navmesh.";
})

table.insert(content, {
	["Type"] = "Header";
	["Name"] = "Methods";
	["Description"] = "";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "getVectorIndex";
	["Arguments"] = {"vector2"};
	["Description"] = "FOR INTERNAL USE ONLY. Returns the index at which the a vector2 with the given values is stored.";
})

table.insert(content, {
	["Type"] = "Method";
	["Name"] = "pathfind";
	["Arguments"] = {"from", "to", "epsilon"};
	["Description"] = "Return an array of vector2s that form a path from the vector2 'from' to the vector2 'to'. If no path is found it returns nil.\n\nEpsilon is a number that allows you to specify a starting and end point that fall a certain distance off the path. If these points fall out of bounds, the returned path will have a starting and/or end point as close to these locations as possible.";
})


return {
	["Meta"] = meta;
	["Content"] = content;
}