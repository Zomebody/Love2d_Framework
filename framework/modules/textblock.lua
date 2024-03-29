
----------------------------------------------------[[ == IMPORTS == ]]----------------------------------------------------

local getpath = require("framework.getpath")
local fontDirectory = "framework/fonts/"
local font = require(getpath(..., "font"))
local color = require(getpath(..., "../datatypes/color"))



----------------------------------------------------[[ == MODULE == ]]----------------------------------------------------

local module = {}
local textblock = {}
textblock.__index = textblock

local function isText(t)
	return getmetatable(t) == textblock
end

local function new(fontname, size, textData, w)
	w = (w == nil) and math.huge or w
	local raw = ""
	if type(textData) == "string" then
		raw = textData
	else
		for i = 2, #textData, 2 do
			raw = raw .. textData[i]
		end
	end
	local Obj = {
		["AlignmentX"] = "left";
		["AlignmentY"] = "top";
		["Color"] = color(1, 1, 1);
		["ColoredText"] = textData;
		["Font"] = nil;
		["FontFile"] = fontname;
		["FontSize"] = size;
		["RawText"] = raw or "";
		["Text"] = love.graphics.newText(font.new(fontname, size));
		["Width"] = w; -- the *actual* width of the text is different if WrapEnabled is false, but this will keep the 'other' width in case you set WrapEnabled back to true
		["WrapEnabled"] = true; -- if text should wrap or stay on one line
	}
	Obj.Font = Obj.Text:getFont()
	Obj.Text:setf(textData, Obj.Width, "left")
	if w == math.huge then
		Obj.Width = Obj.Text:getWidth()
	end
	setmetatable(Obj, textblock)
	return Obj
end


-- "left", "right", "center", "justify"
function textblock:alignX(side)
	assert(side == "left" or side == "center" or side == "right" or side == "justify", "Method textblock:alignX(side) expects argument 'side' to be one of ('left', 'center', 'right', 'justify')")
	self.AlignmentX = side
	--self.Text:setf(self.ColoredText, self.Width, side)
	if self.WrapEnabled then
		self.Text:setf(self.ColoredText, self.Width, side)
	else
		self.Text:set(self.ColoredText)
		local maxWidth = self.Text:getWidth()
		self.Text:setf(self.ColoredText, math.max(maxWidth, self.Width), side)
	end
end

-- "bottom" / "center" / "top"
function textblock:alignY(side)
	assert(side == "bottom" or side == "center" or side == "top", "Method textblock:alignY(side) expects argument 'side' to be one of ('bottom', 'center', 'top')")
	self.AlignmentY = side
end


function textblock:getSize()
	return self.Text:getDimensions()
end


-- replace the textblock data with new textData
function textblock:setText(textData)
	local raw = ""
	if type(textData) == "string" then
		raw = textData
	else
		for i = 2, #textData, 2 do
			raw = raw .. textData[i]
		end
	end
	self.RawText = raw or "";
	self.ColoredText = textData
	--self.Text:setf(self.ColoredText, self.Width, self.AlignmentX)
	if self.WrapEnabled then
		self.Text:setf(self.ColoredText, self.Width, self.AlignmentX)
	else
		self.Text:set(self.ColoredText)
		local maxWidth = self.Text:getWidth()
		self.Text:setf(self.ColoredText, math.max(maxWidth, self.Width), self.AlignmentX)
	end
end

-- returns the raw or colored text of the textblock
function textblock:getText(isColored)
	if isColored then
		return self.ColoredText
	else
		return self.RawText
	end
end


-- resize the text to fit within the given width and height
function textblock:fitText(w, h)
	self:clearFont()
	self.Text:setf(self.ColoredText, w, self.AlignmentX)
	local startTime = love.timer.getTime()
	local loops = 0
	local ceil = math.huge -- upper bound: text of that size does not fit
	local floor = 0 -- lower bound: text of that size fits
	local curTry = 32 -- tweak this number to optimize the number of iterations. Must be power of 2!
	local lastFit = nil -- the last size that did fit in the box
	local doesFit = false
	repeat
		loops = loops + 1
		local createdFont = font.new(self.FontFile, curTry, true)
		self.Text:setFont(createdFont)

		local newWidth, wrappedText = createdFont:getWrap(self.RawText, w)
		local newHeight = createdFont:getHeight() * #wrappedText
		doesFit = (newHeight <= h)
		if doesFit then
			lastFit = curTry
			floor = curTry
			if ceil == math.huge then
				curTry = curTry * 2
			else
				curTry = (curTry + ceil) / 2
			end
		else
			ceil = curTry
			curTry = (curTry + floor) / 2
		end
	until curTry % 1 ~= 0
	
	self.FontSize = lastFit
	self.Text:setFont(font.new(self.FontFile, lastFit))
	return lastFit
end


-- change the font to one from the fonts directory, CAN BE SLOW IF CALLED EVERY FRAME!
function textblock:setFont(name)
	if love.filesystem.getInfo(fontDirectory .. name) then
		self:clearFont()
		self.FontFile = name
		self.Font = font.new(name, self.FontSize)--love.graphics.newFont(fontDirectory .. name, self.FontSize)
		self.Text:setFont(self.Font)
	end
end


-- set a new size for the text and recreate the font using the new size, CAN BE SLOW IF CALLED EVERY FRAME!
function textblock:setTextSize(size)
	size = math.floor(size + 0.5)
	if self.FontSize ~= size then
		self:clearFont()
		self.FontSize = size
		self.Font = font.new(self.FontFile, self.FontSize)--love.graphics.newFont(fontDirectory .. self.FontFile, self.FontSize)
		self.Text:setFont(self.Font)
	end
end


-- set a new maximum width for the textblock
function textblock:setWidth(w)
	self.Width = w
	if self.WrapEnabled then
		self.Text:setf(self.ColoredText, self.Width, self.AlignmentX)
	else
		self.Text:set(self.ColoredText)
		local maxWidth = self.Text:getWidth()
		self.Text:setf(self.ColoredText, math.max(maxWidth, w), self.AlignmentX)
	end
end


function textblock:setWrap(state)
	if state == self.WrapEnabled then return end
	self.WrapEnabled = state
	self:setWidth(self.Width)
end

-- called when the object that uses the textblock is being removed
function textblock:clearFont()
	self.Font = nil
	font:dereference(self.FontFile, self.FontSize)
end



----------------------------------------------------[[ == RETURN == ]]----------------------------------------------------

module.isText = isText
module.new = new

return setmetatable(module, {__call = function(_, ...) return new(...) end})

