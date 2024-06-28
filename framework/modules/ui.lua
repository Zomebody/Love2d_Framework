
----------------------------------------------------[[ == IMPORTS == ]]----------------------------------------------------

local initialized = false
local connection = require("framework.connection")
local getpath = require("framework.getpath")
--local path = ... -- path is now a string representing the path to the current directory
--print(path) -- framework.ui
--local vector = require(getpath(..., "../datatypes/vector"))
--local color = require(getpath(..., "../datatypes/color"))
local textblock = require(getpath(..., "textblock"))



----------------------------------------------------[[ == LOCAL VARIABLES == ]]----------------------------------------------------

local speedHistoryX = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
local speedHistoryY = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

local markedObjects = {} -- stores marked objects in the form ["name"] = {Obj1, Obj2, ...}
local resizedElements = {} -- the Resize event is called (a.) for each resized element after love.resize is called and (b.) for each resized element at the end of the love.update call
local resizedElementsCache = {} -- cache with resized elements in case an element is resized multiple times in a frame



----------------------------------------------------[[ == BASE OBJECTS == ]]----------------------------------------------------

--[[
	KEYBOARD FOCUS FEATURE:

	ui:focusKeyboard(obj, focusMode, modeArg):
	- obj: a list of elements to focus the keyboard on
	- focusMode: 'key' / 'click' / nil
		> 'key': keep keyboard focus until one of the keys in 'modeArg' is pressed down
			> modeArg: the keycode string (the key does not trigger KeyEntered)
		> 'click': keep keyboard focus until the mouse is pressed down
			> modeArg: 'self', 'other', nil
				- self: keep keyboardFocus until you click on a focused element
				- other: keep keyboardFocus until you click elsewhere
				- nil: keep keyboardFocus until you press the mouse
		> nil: keep focus forever, until focusKeyboard is called again
	- modeArg: depends on focusMode argument

]]
local module = {
	--["AutoRendering"] = false;
	["Changed"] = false; -- internal boolean to determine at the end of each frame if some element was added, removed, hidden, unhidden or changed position or size, so CursorFocus can be updated
	["Children"] = {};
	["CursorFocus"] = nil; -- current element the mouse is hovering over
	["DragActive"] = false; -- whether or not DragTarget is experiencing a drag
	["DragStart"] = vector();
	["DragTarget"] = nil; -- the element that is currently being dragged
	["KeyboardFocus"] = {}; -- list of UI elements that have keyboard focus at the moment
	["KeyboardFocusMode"] = {}; -- table with two indexes, tab[1] = mode, tab[2] = mode argument
	["KeyboardFocusState"] = 0; -- keeps track of how often the keyboard focus changes
	["PressedButton"] = nil;
	["PressedElement"] = nil; -- the element that is currently being pressed / held down
	["Size"] = vector(love.graphics.getDimensions()); -- TODO: use getSafeArea() to ignore the mobile inset
	["TotalCreated"] = 0; -- total number of UI elements that have been created
	["Visible"] = true; -- if set to false, ui won't be drawn, events can still technically take place (e.g. gamepad events once support is added)

	["Events"] = {}
}

local UIBase = {}
UIBase.__index = UIBase
UIBase.__tostring = function(tab) return "{UIBase: \"" .. tostring(tab.Name) .. "\" (" .. tostring(tab.Id) .. ")}" end

local Frame = setmetatable({}, UIBase)
Frame.__index = Frame
Frame.__tostring = function(tab) return "{Frame: \"" .. tostring(tab.Name) .. "\" (" .. tostring(tab.Id) .. ")}" end

local ImageFrame = setmetatable({}, UIBase)
ImageFrame.__index = ImageFrame
ImageFrame.__tostring = function(tab) return "{ImageFrame: \"" .. tostring(tab.Name) .. "\" (" .. tostring(tab.Id) .. ")}" end

local SlicedFrame = setmetatable({}, UIBase)
SlicedFrame.__index = SlicedFrame
SlicedFrame.__tostring = function(tab) return "{SlicedFrame: \"" .. tostring(tab.Name) .. "\" (" .. tostring(tab.Id) .. ")}" end

local AnimatedFrame = setmetatable({}, UIBase)
AnimatedFrame.__index = AnimatedFrame
AnimatedFrame.__tostring = function(tab) return "{AnimatedFrame: \"" .. tostring(tab.Name) .. "\" (" .. tostring(tab.Id) .. ")}" end



----------------------------------------------------[[ == UI POSITIONING / SIZING FUNCTIONS == ]]----------------------------------------------------

local contentOffsetX = 0
local contentOffsetY = 0
local OP = nil -- Obj.Parent
local function updateAbsolutePosition(Obj, wX, wY, wWidth, wHeight, ignoreParentPosition) -- ignoreParentPosition is used in combination with :renderTo() to correctly position children that are rendered without parent
	if Obj == nil or Obj == module then
		for i = 1, #module.Children do
			updateAbsolutePosition(module.Children[i], wX, wY, wWidth, wHeight)
		end
		return
	end
	-- set value depending on if this is a top-level element, or if there is a parent
	OP = Obj.Parent
	if OP and OP ~= module and (not ignoreParentPosition) then
		wX = (wX == nil and OP.AbsolutePosition.x or wX) + OP.Padding.x
		wY = (wY == nil and OP.AbsolutePosition.y or wY) + OP.Padding.y
		wWidth = (wWidth == nil and OP.AbsoluteSize.x or wWidth) - 2 * OP.Padding.x
		wHeight = (wHeight == nil and OP.AbsoluteSize.y or wHeight) - 2 * OP.Padding.y
	else
		wX = wX == nil and 0 or wX
		wY = wY == nil and 0 or wY
		wWidth = wWidth == nil and module.Size.x or wWidth
		wHeight = wHeight == nil and module.Size.y or wHeight
	end

	-- apply content offset from all ancestors
	contentOffsetX = 0
	contentOffsetY = 0
	if OP ~= nil and Obj.Parent ~= module then
		contentOffsetX = OP.ContentOffset.x
		contentOffsetY = OP.ContentOffset.y
	end

	-- calculate and apply absolute position. Then update children
	local absX = wX + contentOffsetX + Obj.Position.Offset.x + math.floor(Obj.Position.Scale.x * wWidth) - math.floor(Obj.AbsoluteSize.x * Obj.Center.x)
	local absY = wY + contentOffsetY + Obj.Position.Offset.y + math.floor(Obj.Position.Scale.y * wHeight) - math.floor(Obj.AbsoluteSize.y * Obj.Center.y)
	Obj.AbsolutePosition:set(math.floor(absX), math.floor(absY))
	for i = 1, #Obj.Children do
		updateAbsolutePosition(Obj.Children[i], absX, absY, Obj.AbsoluteSize.x, Obj.AbsoluteSize.y)
	end
end



-- when updating the absolute size of an object (and by extension its descendants), their positions may also need to be updated (for example when a child is aligned to the right of a parent that is being resized)
-- therefore, after calling updateAbsoluteSize() on an object, you should also call updateAbsolutePosition() on the same element afterwards!
local Par = nil
local function updateAbsoluteSize(Obj, ignoreParentSize) -- ignoreParentSize is a boolean to ignore the parent's size. Useful in combination with :renderTo() if the object has a parent already
	if Obj == nil or Obj == module then
		for i = 1, #module.Children do
			updateAbsoluteSize(module.Children[i])
		end
		return
	end
	Par = Obj.Parent
	local sX = 0
	local sY = 0
	if Par and Par ~= module and (not ignoreParentSize) then -- inherit size from parent
		sX = Obj.Size.Scale.x * (Par.AbsoluteSize.x - Par.Padding.x * 2) + Obj.Size.Offset.x
		sY = Obj.Size.Scale.y * (Par.AbsoluteSize.y - Par.Padding.y * 2) + Obj.Size.Offset.y
	else -- use the window's size
		sX = Obj.Size.Scale.x * module.Size.x + Obj.Size.Offset.x
		sY = Obj.Size.Scale.y * module.Size.y + Obj.Size.Offset.y
	end
	local prevX, prevY = Obj.AbsoluteSize.x, Obj.AbsoluteSize.y
	Obj.AbsoluteSize:set(math.floor(sX), math.floor(sY))
	-- store the resized element in a cache so that the 'resize' event can be called at the end of the love.update or love.resize function
	if prevX ~= math.floor(sX) or prevY ~= math.floor(sY) then
		if resizedElementsCache[Obj] == nil then
			resizedElementsCache[Obj] = true
			resizedElements[#resizedElements + 1] = Obj -- elements are ordered in Parent -> Child order so a child can always check its parent's size and it will be up-to-date
		end
	end

	if Obj.TextBlock ~= nil then
		Obj.TextBlock:setWidth(Obj.AbsoluteSize.x - 2 * Obj.Padding.x)
		if Obj.FitTextOnResize then
			Obj:fitText()
		end
	end

	if Obj.ImageFit ~= nil then
		Obj:setImageFit(Obj.ImageFit)
	end

	for i = 1, #Obj.Children do
		-- if a child's Size.Scale.x and Size.Scale.y both are 0, there is no use in updating them (because their AbsoluteSize will remain the same anyway!)
		if not (Obj.Children[i].Size.Scale.x == 0 and Obj.Children[i].Size.Scale.y == 0) then
			updateAbsoluteSize(Obj.Children[i])
		end
	end
end



----------------------------------------------------[[ == MODULE INITIALIZATION == ]]----------------------------------------------------

-- connects love2d events to UI element events
function module:initialize() -- autoRender
	if initialized then return end
	initialized = true
	--if autoRender == nil then autoRender = true end
	--[[
	if not self.Initialized then
		self.Initialized = true
	else
		return
	end]]

	-- Monkey Patching love.mousemoved (at start)
	local mousemoved = love.mousemoved or function() end -- define new mousemoved function if it doesn't exist yet
	love.mousemoved = function(x, y, dx, dy, istouch)
		mousemoved(x, y, dx, dy, istouch)
		local oldFocus = self.CursorFocus
		self.CursorFocus = self:at(x, y)

		-- find and trigger hover events if focus changed
		if oldFocus ~= self.CursorFocus then -- focus changed, check for new focus
			if oldFocus ~= nil then
				self.PressedElement = nil
				--if oldFocus.OnHoverEnd ~= nil then
				--	oldFocus.OnHoverEnd()
				if oldFocus.Events.HoverEnd ~= nil then
					connection.doEvents(oldFocus.Events.HoverEnd)
				end
			end
			--if self.CursorFocus ~= nil and self.CursorFocus.OnHoverStart ~= nil then
			--	self.CursorFocus.OnHoverStart()
			if self.CursorFocus ~= nil and self.CursorFocus.Events.HoverStart ~= nil then
				connection.doEvents(self.CursorFocus.Events.HoverStart)
			end
		end

		-- use delta movement to call (nested) drag events
		if self.DragTarget ~= nil then
			self.DragActive = true
			
			local Target = self.DragTarget
			if Target.Events.Drag ~= nil then
				connection.doEvents(Target.Events.Drag, dx, dy, self.PressedButton, x - self.DragStart.x, y - self.DragStart.y)
			end
			if Target.Events.NestedDrag ~= nil then
				connection.doEvents(Target.Events.NestedDrag, dx, dy, self.PressedButton, x - self.DragStart.x, y - self.DragStart.y)
			end
			while Target.Parent ~= nil and Target.Parent ~= module do
				Target = Target.Parent
				if Target.Events.NestedDrag ~= nil then
					connection.doEvents(Target.Events.NestedDrag, dx, dy, self.PressedButton, x - self.DragStart.x, y - self.DragStart.y)
				end
			end
		end
	end

	-- Monkey Patching love.update (at end)
	local update = love.update or function() end -- define new update function if it doesn't exist yet
	local prevX = love.mouse.getX()
	local prevY = love.mouse.getY()
	local skipSpeedUpdate = false
	love.update = function(...)
		update(...)

		-- call the resize event on the resized elements this frame
		for i = 1, #resizedElements do
			if resizedElements[i].Events.Resize ~= nil then
				connection.doEvents(resizedElements[i].Events.Resize, resizedElements[i].AbsoluteSize.x, resizedElements[i].AbsoluteSize.y)
			end
		end
		resizedElements = {}
		resizedElementsCache = {}

		-- update speed history table and recalculate cursor speed
		local newX, newY = love.mouse.getPosition()
		if not skipSpeedUpdate then
			table.remove(speedHistoryX, 1)
			speedHistoryX[#speedHistoryX + 1] = newX - prevX
			table.remove(speedHistoryY, 1)
			speedHistoryY[#speedHistoryY + 1] = newY - prevY
		end
		prevX = newX
		prevY = newY
		skipSpeedUpdate = false

		if self.Changed then
			self.Changed = false
			local oldFocus = self.CursorFocus
			self.CursorFocus = self:at(love.mouse.getPosition())
			if oldFocus ~= self.CursorFocus then
				if oldFocus ~= nil then
					self.PressedElement = nil
					if oldFocus.Events.HoverEnd ~= nil then
						connection.doEvents(oldFocus.Events.HoverEnd)
					end
				end
				if self.CursorFocus ~= nil and self.CursorFocus.Events.HoverStart ~= nil then
					connection.doEvents(self.CursorFocus.Events.HoverStart)
				end
			end
		end
	end

	-- Monkey Patching love.resize (at start)
	local resize = love.resize or function() end -- define new resize function if it doesn't exist yet
	love.resize = function(...)
		resize(...)

		self.Changed = true
		local screenW, screenH = self.Size.x, self.Size.y
		self.Size = vector(love.graphics.getDimensions())
		if self.Size.x ~= screenW or self.Size.y ~= screenH then
			screenW = self.Size.x
			screenH = self.Size.y
			for i = 1, #self.Children do
				updateAbsoluteSize(self.Children[i])
			end
			for i = 1, #self.Children do
				updateAbsolutePosition(self.Children[i])
			end
		end
		for i = 1, #resizedElements do
			if resizedElements[i].Events.Resize ~= nil then
				connection.doEvents(resizedElements[i].Events.Resize, resizedElements[i].AbsoluteSize.x, resizedElements[i].AbsoluteSize.y)
			end
		end
		resizedElements = {}
		resizedElementsCache = {}
	end

	-- Monkey Patching mouse pressed and mouse released
	local mousepressed = love.mousepressed or function() end
	love.mousepressed = function(x, y, button, istouch, presses)
		mousepressed(x, y, button, istouch, presses, self.CursorFocus ~= nil)

		-- cancel current keyboard focus if cancel mode if set to 'click'
		local loseKeyboardFocus = false
		if self.KeyboardFocusMode[1] == "click" then
			-- cancel keyboard focus when you click on a focused element
			if self.KeyboardFocusMode[2] == "self" then
				local found = false
				for i = 1, #self.KeyboardFocus do
					if self.KeyboardFocus[i] == self.CursorFocus then
						loseKeyboardFocus = true
						break
					end
				end
			-- cancel keyboard focus when you click on another element (or on nothing)
			elseif self.KeyboardFocusMode[2] == "other" then
				local selfFocused = false
				for i = 1, #self.KeyboardFocus do
					if self.KeyboardFocus[i] == self.CursorFocus then
						selfFocused = true
						break
					end
				end
				if not selfFocused then
					loseKeyboardFocus = true
				end
			-- always cancel keyboard focus when clicking
			else
				loseKeyboardFocus = true
			end
		end

		-- stop current drag
		if self.DragTarget ~= nil and self.DragActive then
			local Target = self.DragTarget
			if Target.Events.DragEnd ~= nil then
				connection.doEvents(Target.Events.DragEnd, x - self.DragStart.x, y - self.DragStart.y, button)
			end
			if Target.Events.NestedDragEnd ~= nil then
				connection.doEvents(Target.Events.NestedDragEnd, x - self.DragStart.x, y - self.DragStart.y, button)
			end
			while Target.Parent ~= nil and Target.Parent ~= module do
				Target = Target.Parent
				if Target.Events.NestedDragEnd ~= nil then
					connection.doEvents(Target.Events.NestedDragEnd, x - self.DragStart.x, y - self.DragStart.y, button)
				end
			end
		end

		-- press UI elements
		local prevKeyboardState = self.KeyboardFocusState
		if self.CursorFocus ~= nil then
			self.PressedElement = self.CursorFocus
			self.PressedButton = button

			self.DragStart:set(x, y)
			self.DragTarget = self.PressedElement

			local Target = self.CursorFocus
			if Target.Events.PressStart ~= nil then
				connection.doEvents(Target.Events.PressStart, x, y, button, istouch, presses)
			end
			if Target.Events.NestedPressStart ~= nil then
				connection.doEvents(Target.Events.NestedPressStart, x, y, button, istouch, presses)
			end
			while Target.Parent ~= nil and Target.Parent ~= module do
				Target = Target.Parent
				if Target.Events.NestedPressStart ~= nil then
					connection.doEvents(Target.Events.NestedPressStart, x, y, button, istouch, presses)
				end
			end
		end

		if loseKeyboardFocus and (prevKeyboardState == self.KeyboardFocusState) then -- keyboard focus should be lost, plus no functions altered the state in the meantime
			self:focusKeyboard()
		end

		-- on mobile, the cursor 'jumps' from the previous location to the next location
		-- so the cursor speed becomes insanely high on mobile if you press elsewhere on the screen
		-- so when you start a press, skip the next speed update to prevent these peaks, at the cost of a very slight inaccuracy
		skipSpeedUpdate = true
	end



	local mousereleased = love.mousereleased or function() end
	love.mousereleased = function(x, y, button, istouch, presses)
		mousereleased(x, y, button, istouch, presses, self.CursorFocus ~= nil)

		if self.CursorFocus ~= nil then
			local Target = self.CursorFocus
			if Target.Events.PressEnd ~= nil then
				connection.doEvents(Target.Events.PressEnd, x, y, button, istouch, presses)
			end
			if Target.Events.NestedPressEnd ~= nil then
				connection.doEvents(Target.Events.NestedPressEnd, x, y, button, istouch, presses)
			end
			while Target.Parent ~= nil and Target.Parent ~= module do
				Target = Target.Parent
				if Target.Events.NestedPressEnd ~= nil then
					connection.doEvents(Target.Events.NestedPressEnd, x, y, button, istouch, presses)
				end
			end
			if self.CursorFocus == self.PressedElement and self.CursorFocus.Events.FullPress ~= nil then
				connection.doEvents(self.CursorFocus.Events.FullPress, x, y, button, istouch, presses)
			end
		end

		-- stop current drag
		if self.DragTarget ~= nil and self.DragActive then
			local Target = self.DragTarget
			if Target.Events.DragEnd ~= nil then
				connection.doEvents(Target.Events.DragEnd, x - self.DragStart.x, y - self.DragStart.y, button)
			end
			if Target.Events.NestedDragEnd ~= nil then
				connection.doEvents(Target.Events.NestedDragEnd, x - self.DragStart.x, y - self.DragStart.y, button)
			end
			while Target.Parent ~= nil and Target.Parent ~= module do
				Target = Target.Parent
				if Target.Events.NestedDragEnd ~= nil then
					connection.doEvents(Target.Events.NestedDragEnd, x - self.DragStart.x, y - self.DragStart.y, button)
				end
			end
		end

		-- reset values after the fact so they can be used in the press callbacks, e.g. when programming a scrollable frame and you want to know is a FullPress is valid, or part of a drag
		self.PressedButton = nil
		self.PressedElement = nil
		self.DragTarget = nil
		self.DragActive = false
		--self.DragSpeed:set(0, 0)
	end

	-- Monkey patching mousescroll
	local wheelmoved = love.wheelmoved or function() end
	love.wheelmoved = function(x, y)
		wheelmoved(x, y, self.CursorFocus ~= nil)
		if self.CursorFocus ~= nil then
			if self.CursorFocus.Events.Scroll ~= nil then
				connection.doEvents(self.CursorFocus.Events.Scroll, x, y)
			end
			local Target = self.CursorFocus
			if self.CursorFocus.Events.NestedScroll ~= nil then
				connection.doEvents(self.CursorFocus.Events.NestedScroll, x, y)
			end
			while Target.Parent ~= nil and Target.Parent ~= module do
				Target = Target.Parent
				if Target.Events.NestedScroll ~= nil then
					connection.doEvents(Target.Events.NestedScroll, x, y)
				end
			end
		end
	end

	-- Monkey Patching love.keypressed
	local keypressed = love.keypressed or function() end
	love.keypressed = function(key, scancode, isrepeat)
		keypressed(key, scancode, isrepeat)
		-- check if you need to release keyboard focus
		if self.KeyboardFocusMode[1] == "key" then
			if type(self.KeyboardFocusMode[2]) == "table" then
				for i = 1, #self.KeyboardFocusMode[2] do
					if self.KeyboardFocusMode[2][i] == scancode then
						self:focusKeyboard() -- release the keyboard
						return -- return early
					end
				end
			elseif self.KeyboardFocusMode[2] == scancode then
				self:focusKeyboard() -- release the keyboard
				return -- return early to prevent KeyEntered from triggering (not that KeyboardFocus would have any indexes anyway but oh well)
			end
		end
		-- trigger KeyEntered for all focused UI elements
		for i = 1, #self.KeyboardFocus do
			if self.KeyboardFocus[i].Events.KeyEntered ~= nil then
				connection.doEvents(self.KeyboardFocus[i].Events.KeyEntered, key, scancode)
			end
		end
	end

	-- Monkey Patching love.draw if auto-render is enabled
	--[[
	if autoRender == true then
		self.AutoRendering = true
		local draw = love.draw or function() end
		love.draw = function()
			draw()
			self:render()
		end
	else
		self.AutoRendering = false
	end
	]]
end


-- add a child to the root UI element
function module:addChild(Obj)
	-- remove old parent of object
	if Obj.Parent ~= nil then
		local Parent = Obj.Parent
		for i = 1, #Parent.Children do
			if Parent.Children[i] == Obj then
				table.remove(Parent.Children, i)
				break
			end
		end
	end
	-- set new parent of object
	Obj.Parent = self
	self.Children[#self.Children + 1] = Obj
	updateAbsoluteSize(Obj)
	updateAbsolutePosition(Obj)
	if self.Events.ChildAdded ~= nil then
		connection.doEvents(self.Events.ChildAdded, Obj)
	end
	self.Changed = true
end


-- remove the object from the hierarchy (but do not remove it!)
function module:unparent(Obj)
	if Obj.Parent ~= nil then
		-- remove the object from the parent's list of children
		for i = 1, #Obj.Parent.Children do
			if Obj.Parent.Children[i] == Obj then
				table.remove(Obj.Parent.Children, i)
				break
			end
		end
		-- unparent the object
		Obj.Parent = nil
		-- other stuff
		self.Changed = true
	end
end

-- look through all children for the first child with the given name. Return either nil or the found child.
function module:child(name)
	for i = 1, #self.Children do
		if self.Children[i].Name == name then
			return self.Children[i]
		end
	end
	return nil
end

-- remove the object by calling its :remove() method
function module:remove(Obj)
	Obj:remove()
end

-- return the cursor speed from the last X frames (limit of 30 frames)
function module:getCursorSpeed(frameCount)
	frameCount = frameCount == nil and 20 or math.min(30, frameCount)
	if frameCount == 0 then frameCount = 1 end
	local sumX = 0
	local sumY = 0
	local size = #speedHistoryX
	for i = size - frameCount + 1, size do
		sumX = sumX + speedHistoryX[i]
		sumY = sumY + speedHistoryY[i]
	end
	return vector((sumX / frameCount) / love.timer.getDelta(), (sumY / frameCount) / love.timer.getDelta())
end

-- return the current word at a given location on the screen
function module:getWordAt(x, y)
	local Obj = self:at(x, y)
	if Obj ~= nil then
		return Obj:getWordAt(x, y)
	end
	return nil
end

-- focuses the keyboard on the given UI elements, triggering their key related events
function module:focusKeyboard(elements, focusMode, modeArg)
	if getmetatable(elements) ~= nil then elements = {elements} end -- check if the passed object is a ui element, if so, put it in a table
	-- see which new elements should obtain focus, and which should lose focus
	local newlyFocused = {}
	local loseFocusIndexes = {} -- don't store the elements themselves, but their indexes to make removing faster :>
	-- list elements that need focus
	if elements ~= nil then
		for i = 1, #elements do
			local hasFocus = false
			for j = 1, #self.KeyboardFocus do
				if self.KeyboardFocus[j] == elements[i] then
					hasFocus = true
					break
				end
			end
			if not hasFocus then
				newlyFocused[#newlyFocused + 1] = elements[i]
			end
		end
	end
	-- list elements that should lose focus
	for i = 1, #self.KeyboardFocus do
		local found = false
		if elements ~= nil then
			for j = 1, #elements do
				if self.KeyboardFocus[i] == elements[j] then
					found = true
					break
				end
			end
		end
		if not found then
			loseFocusIndexes[#loseFocusIndexes + 1] = i
		end
	end

	-- lose focus of those elements that need to lose focus
	local index = 0
	local Element = nil
	for i = #loseFocusIndexes, 1, -1 do -- loop backwards because table.remove() will be used
		index = loseFocusIndexes[i]
		Element = self.KeyboardFocus[index]
		if Element.Events.KeyboardLost ~= nil then
			connection.doEvents(Element.Events.KeyboardLost)
		end
		table.remove(self.KeyboardFocus, index)
	end

	-- set focus to new elements
	for i = 1, #newlyFocused do
		self.KeyboardFocus[#self.KeyboardFocus + 1] = newlyFocused[i]
	end
	for i = 1, #newlyFocused do
		if newlyFocused[i].Events.KeyboardFocus ~= nil then
			connection.doEvents(newlyFocused[i].Events.KeyboardFocus)
		end
	end

	-- set keyboard focus mode
	self.KeyboardFocusMode[1] = focusMode
	self.KeyboardFocusMode[2] = modeArg
	if #loseFocusIndexes > 0 or #newlyFocused > 0 then
		self.KeyboardFocusState = self.KeyboardFocusState + 1
	end
end


function module:unfocusKeyboard(elements)
	if getmetatable(elements) ~= nil then elements = {elements} end -- check if the passed object is a ui element, if so, put it in a table
	
	local loseFocusIndexes = {} -- stores the idexes to remove

	-- check if any of the items in the KeyboardFocus array are in the elements array
	for i = 1, #self.KeyboardFocus do
		for k = 1, #elements do
			if self.KeyboardFocus[i] == elements[k] then
				loseFocusIndexes[#loseFocusIndexes + 1] = i
				break
			end
		end
	end

	-- lose focus of those elements that need to lose focus
	local index = 0
	local Element = nil
	for i = #loseFocusIndexes, 1, -1 do -- loop backwards because table.remove() will be used
		index = loseFocusIndexes[i]
		Element = self.KeyboardFocus[index]
		if Element.Events.KeyboardLost ~= nil then
			connection.doEvents(Element.Events.KeyboardLost)
		end
		table.remove(self.KeyboardFocus, index)
	end
end



-- check if the given element currently has keyboard focus
function module:hasKeyboardFocus(element)
	return element:hasKeyboardFocus()
end

-- hides the UI
function module:hide()
	if self.Visible then
		self.Visible = false
		self.Changed = true
		return true
	end
	return false
end

-- draw all UI on screen
function module:render()
	if self.Visible then
		local x, y, w, h = love.graphics.getScissor()
		local r, g, b, a = love.graphics.getColor()
		love.graphics.setColor(1, 1, 1, 1)
		for i = 1, #self.Children do
			self.Children[i]:draw()
		end
		love.graphics.setScissor(x, y, w, h)
		love.graphics.setColor(r, g, b, a)
	end
end

-- draw all UI onto a given canvas
function module:renderTo(canv, mipmap)
	if canv == nil or (not canv:typeOf("Canvas")) then
		error("ui:renderTo(canvas, mipmap) takes a canvas as the first argument. Supplied is a " .. canv:type())
	end
	local canvasX, canvasY = canv:getDimensions()
	local curWidth, curHeight = self.Size.x, self.Size.y
	local curCanvas = love.graphics.getCanvas()
	self.Size:set(canvasX, canvasY) -- setting this somehow screws things up
	love.graphics.setCanvas(canv, mipmap or 1)
	updateAbsoluteSize(self, nil)
	updateAbsolutePosition(self, nil, nil, nil, nil, true)
	self:render()
	self.Size:set(curWidth, curHeight)
	love.graphics.setCanvas(curCanvas)
	updateAbsoluteSize()
	updateAbsolutePosition()
end


-- returns the UI element being drawn at location (x, y)
function module:at(x, y)
	if not self.Visible then
		return nil
	end
	local Obj = nil
	for i = 1, #self.Children do
		if not self.Children[i].Hidden then
			local Found = self.Children[i]:at(x, y)
			if Found ~= nil then
				Obj = Found
			end
		end
	end
	return Obj
end

-- shows the UI (enables it to be drawn)
function module:show()
	if not self.Visible then
		self.Visible = true
		self.Changed = true
		return true
	end
	return false
end


-- returns a table of objects marked with the given tag
function module:find(tag)
	if markedObjects[tag] ~= nil then
		return {unpack(markedObjects[tag])}
	end
	return {}
end


-- eventName is the name of the event to call. All event name strings are accepted, but not all of them may trigger
-- func is the function to link
function module:on(eventName, func)
	if self.Events[eventName] == nil then
		self.Events[eventName] = {}
	end
	local index = #self.Events[eventName] + 1
	local Conn = connection.new(self, eventName)
	self.Events[eventName][index] = {func, Conn}
	return Conn
end



----------------------------------------------------[[ == UIBASE METHODS == ]]----------------------------------------------------

-- eventName is the name of the event to call. All event name strings are accepted, but not all of them may trigger
-- func is the function to link
function UIBase:on(eventName, func)
	if self.Events[eventName] == nil then
		self.Events[eventName] = {}
	end
	local index = #self.Events[eventName] + 1
	local Conn = connection.new(self, eventName)
	self.Events[eventName][index] = {func, Conn}
	return Conn
end


function UIBase:renderTo(canv, mipmap)
	if canv == nil or (not canv:typeOf("Canvas")) then
		error("ui:renderTo(canvas, mipmaps) takes a canvas as the first argument. Supplied is a " .. canv:type())
	end
	local canvasX, canvasY = canv:getDimensions()
	local curWidth, curHeight = module.Size.x, module.Size.y
	local curCanvas = love.graphics.getCanvas()
	module.Size = vector(canvasX, canvasY)
	love.graphics.setCanvas(canv, mipmap or 1)
	updateAbsoluteSize(self, true) -- update size while ignoring the parent's position and size
	updateAbsolutePosition(self, nil, nil, nil, nil, true) -- update position while ignoring the parent's position and size
	self:draw() -- UIBase has no draw function, but its metatable should always have one! (draw the UI onto the canvas)
	module.Size = vector(curWidth, curHeight)
	love.graphics.setCanvas(curCanvas)
	updateAbsoluteSize(self)
	updateAbsolutePosition(self)
end

-- removes the old parent from Obj and sets its new parent to self.
function UIBase:addChild(Obj)
	-- remove old parent of object
	if Obj.Parent ~= nil then
		local Parent = Obj.Parent
		for i = 1, #Parent.Children do
			if Parent.Children[i] == Obj then
				table.remove(Parent.Children, i)
				break
			end
		end
	end
	-- set new parent of object
	Obj.Parent = self
	self.Children[#self.Children + 1] = Obj
	updateAbsoluteSize(Obj)
	updateAbsolutePosition(Obj)
	module.Changed = true
end


-- look through all children for the first child with the given name. Return either nil or the found child.
function UIBase:child(name)
	for i = 1, #self.Children do
		if self.Children[i].Name == name then
			return self.Children[i]
		end
	end
	return nil
end


--[[
	remove the object by:
	- removing its children
	- clearing its tags
	- removing its connected events
	- clearing its font from memory if that font is now unused
]]
function UIBase:remove()
	local children = {}
	for i = 1, #self.Children do
		children[i] = self.Children[i]
	end
	for i = 1, #children do
		children[i]:remove()
	end
	self.Children = {}
	-- first, remove focus (this is done before unlinking any events, so they can still trigger if there were do be unfocus-events support down the line)
	if self:hasKeyboardFocus() then
		ui:unfocusKeyboard(self)
	end
	-- clear all tags
	self:clearTags()
	-- clear any events (TODO: just setting the event list to nil should be good enough for the garbage collector)
	for eventName, eventList in pairs(self.Events) do
		for index, dataPair in pairs(eventList) do
			if dataPair[2] ~= nil and dataPair[2].Connected then
				dataPair[2]:disconnect()
			end
			dataPair[1] = nil
			dataPair[2] = nil
			eventList[index] = nil
		end
		self.Events[eventName] = nil
	end
	-- remove any fonts from memory
	if self.TextBlock ~= nil then
		self.TextBlock:clearFont()
		self.TextBlock.Text:release()
		self.TextBlock.Text = nil
	end
	if self.Parent ~= nil then
		local Par = self.Parent
		for i = 1, #Par.Children do
			if Par.Children[i] == self then
				table.remove(Par.Children, i)
				break
			end
		end
	end
	self.Parent = nil
	module.Changed = true
end

-- return true if the given Object is an (indirect) parent of the UI element
function UIBase:isDescendantOf(Obj)
	local Target = self
	while Target.Parent ~= nil do
		Target = Target.Parent
		if Target == Obj then
			return true
		end
	end
	return false
end

-- hides the UI element
function UIBase:hide()
	self.Hidden = true
	module.Changed = true
end

-- hides the UI element
function UIBase:show()
	self.Hidden = false
	module.Changed = true
end

-- return the UI element being drawn at location (x, y)
function UIBase:at(x, y)
	local Obj = nil
	local scissorX, scissorY, scissorW, scissorH = love.graphics.getScissor()
	local pX = scissorX == nil and 0 or scissorX
	local pY = scissorY == nil and 0 or scissorY
	local w = scissorW == nil and module.Size.x or scissorW
	local h = scissorH == nil and module.Size.y or scissorH
	if self.ClipContent == true then
		if x < self.AbsolutePosition.x or x > self.AbsolutePosition.x + self.AbsoluteSize.x or y < self.AbsolutePosition.y or y > self.AbsolutePosition.y + self.AbsoluteSize.y then
			return nil
		end
		love.graphics.intersectScissor(self.AbsolutePosition.x, self.AbsolutePosition.y, self.AbsoluteSize.x, self.AbsoluteSize.y)
	end
	-- in bounds and within the UI element and not VisualOnly
	if (not self.VisualOnly) and x >= pX and x <= pX + w and y >= pY and y <= pY + h then
		if x >= self.AbsolutePosition.x and x <= self.AbsolutePosition.x + self.AbsoluteSize.x and y >= self.AbsolutePosition.y and y <= self.AbsolutePosition.y + self.AbsoluteSize.y then
			Obj = self
		end
	end
	for i = 1, #self.Children do
		if not self.Children[i].Hidden then
			local Found = self.Children[i]:at(x, y)
			if Found ~= nil then
				Obj = Found
			end
		end
	end
	love.graphics.setScissor(scissorX, scissorY, scissorW, scissorH)
	return Obj
end

-- resize the UI element to (w, h)
function UIBase:resize(sw, sh, ow, oh)
	
	if vector.isVector(sw) then -- 2 vector arguments: scale, offset
		self.Size.Scale:set(sw.x, sw.y)
		self.Size.Offset:set(sh.x, sh.y)
	elseif ow ~= nil and oh ~= nil then -- 4 arguments: scale.x, scale.y, offset.x, offset.y
		self.Size.Scale:set(sw, sh)
		self.Size.Offset:set(ow, oh)
	else -- two number arguments: offset.x, offset.y
		self.Size.Scale:set(0, 0)
		self.Size.Offset:set(sw, sh)
	end
	
	--self.Size.Scale:set(sw, sh)
	--self.Size.Offset:set(ow, oh)
	updateAbsoluteSize(self)
	--if self.TextBlock ~= nil then
	--	self.TextBlock:setWidth(self.AbsoluteSize.x - 2 * self.Padding.x)
	--end
	if self.Parent ~= nil and self.Parent ~= module then
		updateAbsolutePosition(self, self.Parent.AbsolutePosition.x, self.Parent.AbsolutePosition.y, self.Parent.AbsoluteSize.x, self.Parent.AbsoluteSize.y)
	else
		updateAbsolutePosition(self) -- TODO: THIS LINE OF CODE IS NOT TESTED
	end
	--if self.FitTextOnResize and self.TextBlock ~= nil then
	--	self:fitText()
	--end
	module.Changed = true
end

-- reposition the UI element to another location
function UIBase:reposition(sx, sy, ox, oy)
	if vector.isVector(sx) then
		self.Position.Scale:set(sx)
		self.Position.Offset:set(sy)
	elseif ox == nil then
		self.Position.Scale:set(0, 0)
		self.Position.Offset:set(sx, sy)
	else
		self.Position.Scale:set(sx, sy)
		self.Position.Offset:set(ox, oy)
	end
	updateAbsolutePosition(self)
	module.Changed = true
end

-- reposition the UI element to be placed to one of the sides of the given UI element (Parents should have the same Center property to make this work)
-- side: "left" / "right" / "top" / "above" / "bottom" / "under"
function UIBase:putNextTo(Obj, side, offset)
	offset = offset == nil and 0 or offset
	self:setCenter(Obj.Center.x, Obj.Center.y)
	if side == "left" then
		self:reposition(Obj.Position.Scale, Obj.Position.Offset + vector(-self.AbsoluteSize.x - offset, 0))
	elseif side == "right" then
		self:reposition(Obj.Position.Scale, Obj.Position.Offset + vector(Obj.AbsoluteSize.x + offset, 0))
	elseif side == "top" or side == "above" then
		self:reposition(Obj.Position.Scale, Obj.Position.Offset + vector(0, -self.AbsoluteSize.y - offset))
	elseif side == "bottom" or side == "under" or side == "below" then
		self:reposition(Obj.Position.Scale, Obj.Position.Offset + vector(0, Obj.AbsoluteSize.y + offset))
	end
end

-- increase the offset of a UI element by offsetX and offsetY
function UIBase:shift(offsetX, offsetY)
	if vector.isVector(offsetX) then
		self:reposition(self.Position.Scale, self.Position.Offset + offsetX)
	else
		self:reposition(self.Position.Scale, self.Position.Offset + vector(offsetX, offsetY))
	end
end

-- increase the ContentOffset of a UI element by offsetX and offsetY
function UIBase:shiftContent(offsetX, offsetY)
	if vector.isVector(offsetX) then
		self.ContentOffset:set(self.ContentOffset.x + offsetX.x, self.ContentOffset.y + offsetX.y)
	else
		self.ContentOffset:set(self.ContentOffset.x + offsetX, self.ContentOffset.y + offsetY)
	end
	updateAbsolutePosition(self)
	module.Changed = true
end

-- set the ContentOffset of a UI element to offsetX, offsetY
function UIBase:positionContent(offsetX, offsetY)
	if vector.isVector(offsetX) then
		self.ContentOffset:set(offsetX.x, offsetX.y)
	else
		self.ContentOffset:set(offsetX, offsetY)
	end
	updateAbsolutePosition(self)
	module.Changed = true
end

-- align the children horizontally / vertically and align the top/bottom/left/right/center. Order in which the elements are aligned it based on the order of the children: first child in front, last child last
function UIBase:alignChildren(direction, side, padding)
	if #self.Children == 0 then return end
	assert(direction == "horizontal" or direction == "vertical", "The 'direction' parameter in :alignChildren(direction, side, padding) must be one of 'horizontal' or 'vertical'.")
	
	-- create a list of all visible children
	local VisibleChildren = {} -- list of all children that are visible (and thus should be aligned)
	for i = 1, #self.Children do
		if self.Children[i].Hidden == false then
			VisibleChildren[#VisibleChildren + 1] = self.Children[i]
		end
	end

	if #VisibleChildren > 0 then
		padding = (padding == nil) and 0 or padding
		if direction == "horizontal" then
			assert(side == "top" or side == "center" or side == "bottom" or side == nil, "The 'side' parameter in :alignChildren(direction, side, padding) must be one of 'top', 'center', 'bottom' or nil.")
			VisibleChildren[1]:alignX("left")
			VisibleChildren[1]:alignY(side)
			for i = 2, #VisibleChildren do
				VisibleChildren[i]:putNextTo(VisibleChildren[i - 1], "right", padding)
			end
		elseif direction == "vertical" then
			assert(side == "left" or side == "center" or side == "right" or side == nil, "The 'side' parameter in :alignChildren(direction, side, padding) must be one of 'left', 'center', 'right' or nil.")
			VisibleChildren[1]:alignX(side)
			VisibleChildren[1]:alignY("top")
			for i = 2, #VisibleChildren do
				VisibleChildren[i]:putNextTo(VisibleChildren[i - 1], "bottom", padding)
			end
		end
	end
end

-- horizontally align the element to a side, valid options: "left" / "center" / "right"
function UIBase:alignX(side)
	self.Position.Offset.x = 0
	if side == "left" then
		self.Position.Scale.x = 0
		self.Center.x = 0
	elseif side == "right" then
		self.Position.Scale.x = 1
		self.Center.x = 1
	else
		self.Position.Scale.x = 0.5
		self.Center.x = 0.5
	end
	updateAbsolutePosition(self)
	module.Changed = true
end

-- vertically align the element to a side, valid options: "bottom" / "center" / "top"
function UIBase:alignY(side)
	self.Position.Offset.y = 0
	if side == "top" then
		self.Position.Scale.y = 0
		self.Center.y = 0
	elseif side == "bottom" then
		self.Position.Scale.y = 1
		self.Center.y = 1
	else
		self.Position.Scale.y = 0.5
		self.Center.y = 0.5
	end
	updateAbsolutePosition(self)
	module.Changed = true
end

-- update the style of the component
function UIBase:setBorder(col, width)
	if type(col) == "number" then
		self.BorderWidth = math.floor(col + 0.5)
	else
		self.BorderColor = color(col)
		self.BorderWidth = math.floor(width + 0.5)
	end
	if self.ImageFit ~= nil then
		self:setImageFit(self.ImageFit)
	end
end


-- create an invisible border of a certain thickness in pixels, used to offset inner elements and text
function UIBase:setPadding(sizeX, sizeY)
	if vector.isVector(sizeX) then
		self.Padding:set(sizeX.x, sizeX.y)
	elseif sizeY == nil then
		self.Padding:set(sizeX, sizeX)
	else
		self.Padding:set(sizeX, sizeY)
	end
	if self.TextBlock ~= nil then
		self.TextBlock:setWidth(self.AbsoluteSize.x - 2 * self.Padding.x)
	end
	updateAbsoluteSize(self)
	updateAbsolutePosition(self)
	module.Changed = true
end

--[[
function UIBase:getPixelPadding()
	local px = (self.Padding.x < 1) and (self.Padding.x * 0.5 * self.AbsoluteSize.x) or (self.Padding.x)
	local py = (self.Padding.y < 1) and (self.Padding.y * 0.5 * self.AbsoluteSize.y) or (self.Padding.y)
	return px, py
end
]]

function UIBase:setCenter(x, y)
	self.Center:set(x, y)
	updateAbsolutePosition(self)
	module.Changed = true
end


-- adds a TextBlock to the UI and sets its content. If no arguments provided, removes the text. If no font size provided, text is scaled to fit the frame
function UIBase:setText(fontname, textData, size, scaleHeight)
	if fontname == nil then
		if self.TextBlock ~= nil then
			self.TextBlock:clearFont()
		end
		self.TextBlock = nil
	elseif size == nil then -- scale text to fit box
		local w = self.AbsoluteSize.x - 2 * self.Padding.x
		local h = self.AbsoluteSize.y - 2 * self.Padding.y
		local tb = textblock(fontname, size, textData, w)
		tb:fitText(w, h)
		self.FitTextOnResize = true
		self.TextBlock = tb
	else
		local w = self.AbsoluteSize.x - 2 * self.Padding.x
		local tb = textblock(fontname, size, textData, w)
		self.TextBlock = tb
		if scaleHeight then
			local width, height = tb:getSize()
			--self:resize(self.AbsoluteSize.x, height + self.Padding.y * 2)
			self:resize(self.Size.Scale.x, 0, self.Size.Offset.x, height + self.Padding.y * 2)
		end
	end
end


-- resize the text to fit perfectly within the box
function UIBase:fitText()
	if self.TextBlock ~= nil then
		self.TextBlock:fitText(self.AbsoluteSize.x - 2 * self.Padding.x, self.AbsoluteSize.y - 2 * self.Padding.y)
	end
end


function UIBase:getWordAt(x, y)
	if self.TextBlock ~= nil then
		local Font = self.TextBlock.Font

		-- relX and relY are the X and Y relative to the top left corner, incorporating active transforms (such as rotation)
		local relX
		local relY
		if self.Rotation == 0 then -- simple subtraction
			relX = x - self.AbsolutePosition.x
			relY = y - self.AbsolutePosition.y
		else -- transform magic
			love.graphics.push() -- push current graphics coordinate state
			love.graphics.translate(self.AbsolutePosition.x + self.AbsoluteSize.x * self.Pivot.x, self.AbsolutePosition.y + self.AbsoluteSize.y * self.Pivot.y)
			love.graphics.rotate(math.rad(self.Rotation))
			love.graphics.translate(-self.AbsoluteSize.x * self.Pivot.x, -self.AbsoluteSize.y * self.Pivot.y)
			relX, relY = love.graphics.inverseTransformPoint(x, y) -- get x and y relative to the rotation of the object
			love.graphics.pop() -- reset back to previous
		end

		if self.ClipContent == true and self.Rotation ~= 0 then -- part of the UI is cut off when ClipContent == true and Rotation ~= 0. So do an AABB check as well
			if x < self.AbsolutePosition.x or x > self.AbsolutePosition.x + self.AbsoluteSize.x or y < self.AbsolutePosition.y or y > self.AbsolutePosition.y + self.AbsoluteSize.y then
				return nil -- position is outside of the 'box'
			end
		end
		
		if relX >= 0 and relX <= self.AbsoluteSize.x and relY >= 0 and relY <= self.AbsoluteSize.y then
			-- calculate the height at which the text starts:
			local textStartY = 0 -- relative to the top-side of the UI element
			if self.TextBlock.AlignmentY == "top" then
				textStartY = self.Padding.y
			elseif self.TextBlock.AlignmentY == "center" then
				textStartY = (self.AbsoluteSize.y - self.TextBlock.Text:getHeight()) / 2
			else
				textStartY = self.AbsoluteSize.y - self.Padding.y - self.TextBlock.Text:getHeight()
			end

			-- get the pixel Y from the top of the current line to the current Y of the mouse. If higher than the font's height, you're in 'empty space' --> return nil
			local heightWithinLine = (relY - textStartY) % (Font:getHeight() * Font:getLineHeight())
			if heightWithinLine > Font:getHeight() then
				return nil
			end

			-- calculate which line the cursor is focused on
			local atLine = math.ceil((relY - textStartY) / (Font:getHeight() * Font:getLineHeight()))
			local width, wrappedText = Font:getWrap(self.TextBlock:getText(), self.TextBlock.Text:getWidth())
			if wrappedText[atLine] == nil then
				return nil
			end

			-- now that the line is known, find out the word within the line that is being focused on
			local line = wrappedText[atLine]
			if line:sub(line:len()) == " " then
				line = line:sub(1, line:len() - 1)
			end
			--print(line, line:len(), line:sub(1, 1):byte(), line:sub(line:len()):byte())
			local textStartX = 0
			if self.TextBlock.AlignmentX == "left" then
				textStartX = self.Padding.x
			elseif self.TextBlock.AlignmentX == "center" then
				textStartX = (self.AbsoluteSize.x - Font:getWidth(line)) / 2
			else
				textStartX = self.AbsoluteSize.x - self.Padding.x - Font:getWidth(line)
			end
			if relX < textStartX then
				return nil -- you are to the left of the left-most word in the sentence, so no word is selected
			end

			-- split the sentence into individual words. Then concatenate them back until the text width is larger than the relative cursor X position
			local splitPattern = "[%a%d']+[%a%d%-']*"
			local curLocation = 1
			local s, e = line:find(splitPattern)
			while s ~= nil do
				-- iteratively build up the string word for word until the relative mouse X is smaller than the text width! If you concatenated a word last, you are on the word, otherwise you are on a space/interpunction
				if s > curLocation then -- if true, there is empty space to check out first
					if relX - textStartX <= Font:getWidth(line:sub(1, s - 1)) then
						return nil
					end
				end

				-- check out up until the end of the word
				if relX - textStartX <= Font:getWidth(line:sub(1, e)) then
					if atLine > 1 then
						local num = 0
						for i = 1, atLine - 1 do
							num = num + wrappedText[i]:len()
						end
						return line:sub(s, e), s + num, e + num
					else
						return line:sub(s, e), s, e
					end
				end

				curLocation = e + 1
				s, e = line:find(splitPattern, curLocation)
			end
		end
	end
	return nil
end


function UIBase:getDescendants(addSelf)
	local Elements = {}
	if addSelf then
		Elements = {self}
	end
	for i = 1, #self.Children do
		local Descendants = self.Children[i]:getDescendants(true)
		for k = 1, #Descendants do
			Elements[#Elements + 1] = Descendants[k]
		end
	end
	return Elements
end


-- put the UI element to the back by moving it to the first index in the parent's Children array
function UIBase:toBack()
	if self.Parent ~= nil and self.Parent.Children ~= nil then
		local Items = self.Parent.Children
		for i = 1, #Items do
			if Items[i] == self then
				table.remove(Items, i)
				table.insert(Items, 1, self)
				return true
			end
		end
	end
	return false
end


-- put the UI element on top by moving it to the last index in the parent's Children array
function UIBase:toFront()
	if self.Parent ~= nil and self.Parent.Children ~= nil then
		local Items = self.Parent.Children
		for i = 1, #Items do
			if Items[i] == self then
				table.insert(Items, table.remove(Items, i))
				return true
			end
		end
	end
	return false
end


-- log2(n) insert search to support large numbers of tagged objects!
local function findOrderedUIInsertLocation(tbl, Obj)
	local l, r = 1, #tbl
	while l ~= r do
		local index = math.floor((l + r) / 2)
		if tbl[index].Id < Obj.Id then
			l = math.min(r, index + 1)
		else
			r = math.max(l, index - 1)
		end
	end
	return (Obj.Id > tbl[l].Id) and (l + 1) or (l)
end


local function findObjectIndexInOrderedArray(tbl, Obj)
	local l, r = 1, #tbl
	while l ~= r do
		local index = math.floor((l + r) / 2)
		if tbl[index] == Obj then
			return index
		else
			if tbl[index].Id < Obj.Id then
				l = math.min(r, index + 1)
			else
				r = math.max(l, index - 1)
			end
		end
	end
	return l
end


function UIBase:addTag(tag)
	assert(type(tag) == "string", "UIBase:addTag(tag) expects argument 'tag' to be of type 'string'.")
	-- check if the object already has the tag
	for i = 1, #self.Tags do
		if self.Tags[i] == tag then return end -- object already has that tag
	end

	-- add tag to object
	self.Tags[#self.Tags + 1] = tag

	-- insert object to list of objects with that tag
	if markedObjects[tag] == nil then
		markedObjects[tag] = {self}
	else
		local i = findOrderedUIInsertLocation(markedObjects[tag], self)
		table.insert(markedObjects[tag], i, self)
	end
end


function UIBase:clearTags()
	for i = 1, #self.Tags do
		self:removeTag(self.Tags[1]) -- self.Tags[1] because table.remove() in UIBase:removeTag() will shift other items to the first spot anyway
	end
end


function UIBase:removeTag(tag)
	-- check if the tag exists in the object, if so, remove it
	local removed = nil
	for i = 1, #self.Tags do
		if self.Tags[i] == tag then
			removed = table.remove(self.Tags, i)
			break
		end
	end

	-- if the tag has been removed from the object, also remove it from the markedObjects list
	if removed ~= nil then
		local index = findObjectIndexInOrderedArray(markedObjects[tag], self)
		table.remove(markedObjects[tag], index)
	end

	-- remove the list if it is empty
	if #markedObjects[tag] == 0 then
		markedObjects[tag] = nil
	end
end


-- return true if the object has a given tag in its tag list
function UIBase:hasTag(tag)
	for i = 1, #self.Tags do
		if self.Tags[i] == tag then
			return true
		end
	end
	return false
end


-- return true if this element has keyboard focus (listening to KeyEntered)
function UIBase:hasKeyboardFocus()
	for i = 1, #module.KeyboardFocus do
		if module.KeyboardFocus[i] == self then
			return true
		end
	end
	return false
end



----------------------------------------------------[[ == DRAW HELPERS == ]]----------------------------------------------------

-- only for internal use! This relies on there being a currently active coordinate space transformation!
function UIBase:drawText()
	-- draw text on top
	if self.TextBlock ~= nil then
		love.graphics.setColor(self.TextBlock.Color:components())
		if self.TextBlock.AlignmentY == "top" then
			love.graphics.draw(self.TextBlock.Text, -self.AbsoluteSize.x * self.Pivot.x + self.Padding.x, -self.AbsoluteSize.y * self.Pivot.y + self.Padding.y)
		elseif self.TextBlock.AlignmentY == "center" then
			love.graphics.draw(self.TextBlock.Text, -self.AbsoluteSize.x * self.Pivot.x + self.Padding.x, -self.AbsoluteSize.y * self.Pivot.y + math.floor(self.AbsoluteSize.y / 2 - self.TextBlock.Text:getHeight() / 2))
		else -- bottom
			love.graphics.draw(self.TextBlock.Text, -self.AbsoluteSize.x * self.Pivot.x + self.Padding.x, self.AbsoluteSize.y * (1 - self.Pivot.y) - self.Padding.y - self.TextBlock.Text:getHeight())
		end
	end
end

-- local 'global' variables for the next two functions
local stencilCornerArg
local cornerStencilMode, cornerStencilValue

function addCornerStencil(Obj)
	stencilCornerArg = (Obj.CornerRadius.Scale > 0 or Obj.CornerRadius.Offset > 0) and (math.min(Obj.AbsoluteSize.x, Obj.AbsoluteSize.y) * Obj.CornerRadius.Scale + Obj.CornerRadius.Offset) or nil
	-- set stencil
	if stencilCornerArg ~= nil then
		-- draw stencil (rectangle with rounded corners), then the image, then remove the stencil
		cornerStencilMode, cornerStencilValue = love.graphics.getStencilTest()
		love.graphics.setStencilTest("greater", 0)
		love.graphics.stencil( -- replaces the stencil values from 0 to 1 in all places where geometry is drawn
			function()
				love.graphics.rectangle("fill", -Obj.AbsoluteSize.x * Obj.Pivot.x, -Obj.AbsoluteSize.y * Obj.Pivot.y, Obj.AbsoluteSize.x, Obj.AbsoluteSize.y, stencilCornerArg)
			end
		)
	end
end

function clearCornerStencil(Obj)
	-- this method is (and must) always (be) called after addCornerStencil(Obj) with the same Obj argument
	-- clear stencil
	if stencilCornerArg ~= nil then
		love.graphics.setStencilTest("always", 0)
		love.graphics.stencil(function() end) -- reset all stencil values back to 0
		love.graphics.setStencilTest(cornerStencilMode, cornerStencilValue)
	end
end



----------------------------------------------------[[ == FRAME METHODS == ]]----------------------------------------------------

-- THIS FUNCTION NOW USES COORDINATE TRANSLATIONS TO SUPPORT ROTATION
-- TODO: CHECK IF THE BORDER CALCULATION IS CORRECT!!
-- draw the frame on screen
function Frame:draw()
	if self.Hidden then return end

	local scissorX, scissorY, scissorW, scissorH = love.graphics.getScissor()

	if self.ClipContent == true then
		love.graphics.intersectScissor(self.AbsolutePosition.x, self.AbsolutePosition.y, self.AbsoluteSize.x, self.AbsoluteSize.y)
	end

	local gw, gh = love.graphics.getDimensions()
	-- bounds check optimization. This will reduce GPU used! (GPU went down from 17% to 14% in a recent test)
	if not (self.AbsolutePosition.x > gw or self.AbsolutePosition.x + self.AbsoluteSize.x < 0 or self.AbsolutePosition.y > gh or self.AbsolutePosition.y + self.AbsoluteSize.y < 0) then
		local r, g, b, a = self.Color.r, self.Color.g, self.Color.b, self.Color.a
		if module.PressedElement == self then
			r, g, b, a = self.ColorHold.r, self.ColorHold.g, self.ColorHold.b, self.ColorHold.a
		elseif module.CursorFocus == self then
			r, g, b, a = self.ColorFocus.r, self.ColorFocus.g, self.ColorFocus.b, self.ColorFocus.a
		end

		love.graphics.push() -- push current graphics coordinate state
		--love.graphics.translate(self.AbsolutePosition.x + self.AbsoluteSize.x / 2, self.AbsolutePosition.y + self.AbsoluteSize.y / 2)
		love.graphics.translate(self.AbsolutePosition.x + self.AbsoluteSize.x * self.Pivot.x, self.AbsolutePosition.y + self.AbsoluteSize.y * self.Pivot.y)
		love.graphics.rotate(math.rad(self.Rotation))

		local cornerArg = (self.CornerRadius.Scale > 0 or self.CornerRadius.Offset > 0) and (math.min(self.AbsoluteSize.x, self.AbsoluteSize.y) * self.CornerRadius.Scale + self.CornerRadius.Offset) or nil
		if self.BorderWidth > 0 then
			love.graphics.setColor(self.BorderColor.r, self.BorderColor.g, self.BorderColor.b, self.BorderColor.a*self.Opacity)
			love.graphics.setLineWidth(self.BorderWidth)
			love.graphics.rectangle("line", -self.AbsoluteSize.x * self.Pivot.x + self.BorderWidth / 2, -self.AbsoluteSize.y * self.Pivot.y + self.BorderWidth / 2, self.AbsoluteSize.x - self.BorderWidth, self.AbsoluteSize.y - self.BorderWidth, cornerArg and cornerArg - self.BorderWidth / 2)
		end
		love.graphics.setColor(r, g, b, a*self.Opacity)
		--love.graphics.rectangle("fill", self.AbsolutePosition.x + self.BorderWidth, self.AbsolutePosition.y + self.BorderWidth, self.AbsoluteSize.x - self.BorderWidth*2, self.AbsoluteSize.y - self.BorderWidth*2)
		love.graphics.rectangle("fill", -self.AbsoluteSize.x * self.Pivot.x + self.BorderWidth, -self.AbsoluteSize.y * self.Pivot.y + self.BorderWidth, self.AbsoluteSize.x - self.BorderWidth*2, self.AbsoluteSize.y - self.BorderWidth*2, cornerArg and math.max(0, cornerArg - self.BorderWidth))
		-- draw text on top
		self:drawText()

		love.graphics.pop() -- revert to previous graphics coordinate state
	end

	for i = 1, #self.Children do
		self.Children[i]:draw()
	end
	love.graphics.setScissor(scissorX, scissorY, scissorW, scissorH)
end



----------------------------------------------------[[ == IMAGEFRAME METHODS == ]]----------------------------------------------------

function ImageFrame:setReference(img)
	self.ReferenceImage = img
	local wrapX, wrapY = img:getWrap()
	if wrapX == "repeat" and wrapY == "repeat" then
		self.Tiled = true
	else
		self.Tiled = false
	end
	--if self.Tiled then
	--	self.Quad:setViewport(0, 0, self.AbsoluteSize.x, self.AbsoluteSize.y, img:getPixelWidth(), img:getPixelHeight())
	--end
	self:setImageFit(self.ImageFit)
end

-- TODO: properly implement BorderWidth here!
function ImageFrame:setImageFit(mode)
	assert(mode == "stretch" or mode == "contain" or mode == "cover", "setImageFit(mode) does not support options " .. tostring(mode) .. ".")
	self.ImageFit = mode
	if mode == "stretch" then
		if self.Tiled then
			-- compute the number of tiles to display on the X-axis and Y-axis
			local tilesX = (self.AbsoluteSize.x - self.BorderWidth*2) / self.ReferenceImage:getPixelWidth()
			local tilesY = (self.AbsoluteSize.y - self.BorderWidth*2) / self.ReferenceImage:getPixelHeight()
			self.Quad:setViewport(0, 0, self.AbsoluteSize.x, self.AbsoluteSize.y, self.AbsoluteSize.x / tilesX, self.AbsoluteSize.y / tilesY)
		else
			self.Quad:setViewport(0, 0, self.AbsoluteSize.x, self.AbsoluteSize.y, self.AbsoluteSize.x, self.AbsoluteSize.y)
		end
	elseif mode == "cover" then
		local imageFillX, imageFillY = self.AbsoluteSize.x - self.BorderWidth*2, self.AbsoluteSize.y - self.BorderWidth*2
		local scaleX = imageFillX / self.ReferenceImage:getPixelWidth()
		local scaleY = imageFillY / self.ReferenceImage:getPixelHeight()
		if scaleX > scaleY then -- scaling on the Y-axis will overflow so the top and bottom of the image will be cut off
			local height = imageFillY * (scaleY / scaleX)
			self.Quad:setViewport(0, (imageFillY - height) / 2, imageFillX, height, imageFillX, imageFillY)
		else -- scaling on the X-axis will overflow so the left and right of the image will be cut off
			local width = imageFillX * (scaleX / scaleY)
			self.Quad:setViewport((imageFillX - width) / 2, 0, width, imageFillY, imageFillX, imageFillY)
		end
	elseif mode == "contain" then
		if self.Tiled then
			local imageFillX, imageFillY = self.AbsoluteSize.x - self.BorderWidth*2, self.AbsoluteSize.y - self.BorderWidth*2
			local scaleX = imageFillX / self.ReferenceImage:getPixelWidth()
			local scaleY = imageFillY / self.ReferenceImage:getPixelHeight()
			if scaleX < scaleY then
				self.Quad:setViewport(0, 0, imageFillX, imageFillY, imageFillX, imageFillY * (scaleX / scaleY))
			else
				self.Quad:setViewport(0, 0, imageFillX, imageFillY, imageFillX * (scaleY / scaleX), imageFillY)
			end
		else
			local imageFillX, imageFillY = self.AbsoluteSize.x - self.BorderWidth*2, self.AbsoluteSize.y - self.BorderWidth*2
			self.Quad:setViewport(0, 0, imageFillX, imageFillY, imageFillX, imageFillY)
		end
	end
end




function ImageFrame:draw()
	if self.Hidden then return end

	local _, _, imgWidth, imgHeight = self.Quad:getViewport()
	local scissorX, scissorY, scissorW, scissorH = love.graphics.getScissor()

	if self.ClipContent == true then
		love.graphics.intersectScissor(self.AbsolutePosition.x, self.AbsolutePosition.y, self.AbsoluteSize.x, self.AbsoluteSize.y)
	end


	local gw, gh = love.graphics.getDimensions()
	-- bounds check to reduce GPU load. Don't need to draw out of bounds!
	if not (self.AbsolutePosition.x > gw or self.AbsolutePosition.x + self.AbsoluteSize.x < 0 or self.AbsolutePosition.y > gh or self.AbsolutePosition.y + self.AbsoluteSize.y < 0) then
		local r, g, b, a = self.Color.r, self.Color.g, self.Color.b, self.Color.a
		if module.PressedElement == self then
			r, g, b, a = self.ColorHold.r, self.ColorHold.g, self.ColorHold.b, self.ColorHold.a
		elseif module.CursorFocus == self then
			r, g, b, a = self.ColorFocus.r, self.ColorFocus.g, self.ColorFocus.b, self.ColorFocus.a
		end

		love.graphics.push() -- push current graphics coordinate state
		love.graphics.translate(self.AbsolutePosition.x + self.AbsoluteSize.x * self.Pivot.x, self.AbsolutePosition.y + self.AbsoluteSize.y * self.Pivot.y)
		love.graphics.rotate(math.rad(self.Rotation))

		love.graphics.setColor(r, g, b, a*self.Opacity)
		
		-- draw image, using a stencil for rounded corners
		addCornerStencil(self)
		if self.ImageFit == "stretch" or (self.Tiled and (not self.ImageFit == "contain")) then
			love.graphics.draw(self.ReferenceImage, self.Quad, -self.AbsoluteSize.x * self.Pivot.x + self.BorderWidth, -self.AbsoluteSize.y * self.Pivot.y + self.BorderWidth, 0, (self.AbsoluteSize.x - self.BorderWidth*2) / self.AbsoluteSize.x, (self.AbsoluteSize.y - self.BorderWidth*2) / self.AbsoluteSize.y)
		elseif self.ImageFit == "cover" then
			love.graphics.draw(self.ReferenceImage, self.Quad, -self.AbsoluteSize.x * self.Pivot.x + self.BorderWidth, -self.AbsoluteSize.y * self.Pivot.y + self.BorderWidth, 0, (self.AbsoluteSize.x - self.BorderWidth * 2) / imgWidth, (self.AbsoluteSize.y - self.BorderWidth * 2) / imgHeight)
		elseif self.ImageFit == "contain" then
			imgWidth, imgHeight = self.ReferenceImage:getPixelWidth(), self.ReferenceImage:getPixelHeight()
			local imageFillX, imageFillY = self.AbsoluteSize.x - self.BorderWidth*2, self.AbsoluteSize.y - self.BorderWidth*2
			local scaleX = imageFillX / imgWidth
			local scaleY = imageFillY / imgHeight
			if scaleX > scaleY then -- keep open space at the top and bottom
				local height = (self.AbsoluteSize.y - self.BorderWidth*2) * (scaleY / scaleX)
				if self.Tiled then
					love.graphics.draw(self.ReferenceImage, self.Quad, -self.AbsoluteSize.x * self.Pivot.x + self.BorderWidth, -self.AbsoluteSize.y * self.Pivot.y + self.BorderWidth, 0, 1, 1)
				else
					love.graphics.draw(self.ReferenceImage, self.Quad, -self.AbsoluteSize.x * self.Pivot.x - (height / 2) * (imageFillX/imageFillY) + self.AbsoluteSize.x/2, -self.AbsoluteSize.y * self.Pivot.y + self.BorderWidth, 0, scaleY / scaleX, 1)
				end
			else -- keep open space to the left and right
				local width = (self.AbsoluteSize.x - self.BorderWidth*2) * (scaleX / scaleY)
				if self.Tiled then
					love.graphics.draw(self.ReferenceImage, self.Quad, -self.AbsoluteSize.x * self.Pivot.x + self.BorderWidth, -self.AbsoluteSize.y * self.Pivot.y + self.BorderWidth, 0, 1, 1)
				else
					love.graphics.draw(self.ReferenceImage, self.Quad, -self.AbsoluteSize.x * self.Pivot.x + self.BorderWidth, -self.AbsoluteSize.y * self.Pivot.y - (width / 2) * (imageFillY/imageFillX) + self.AbsoluteSize.y/2, 0, 1, scaleX / scaleY)
				end
			end
		else -- default: I don't actually know what the default is supposed to be
			love.graphics.draw(self.ReferenceImage, self.Quad, -self.AbsoluteSize.x * self.Pivot.x + self.BorderWidth, -self.AbsoluteSize.y * self.Pivot.y + self.BorderWidth, 0, (self.AbsoluteSize.x - self.BorderWidth * 2) / imgWidth, (self.AbsoluteSize.y - self.BorderWidth * 2) / imgHeight)
		end
		clearCornerStencil(self)

		-- draw border
		local cornerArg = (self.CornerRadius.Scale > 0 or self.CornerRadius.Offset > 0) and (math.min(self.AbsoluteSize.x, self.AbsoluteSize.y) * self.CornerRadius.Scale + self.CornerRadius.Offset) or nil
		if self.BorderWidth > 0 then
			love.graphics.setColor(self.BorderColor.r, self.BorderColor.g, self.BorderColor.b, self.BorderColor.a*self.Opacity)
			love.graphics.setLineWidth(self.BorderWidth)
			love.graphics.rectangle("line", -self.AbsoluteSize.x * self.Pivot.x + self.BorderWidth / 2, -self.AbsoluteSize.y * self.Pivot.y + self.BorderWidth / 2, self.AbsoluteSize.x - self.BorderWidth, self.AbsoluteSize.y - self.BorderWidth, cornerArg)-- and math.max(0, cornerArg - self.BorderWidth)
		end
		-- draw text on top
		self:drawText()

		love.graphics.pop() -- revert to previous graphics coordinate state
	end

	for i = 1, #self.Children do
		self.Children[i]:draw()
	end
	love.graphics.setScissor(scissorX, scissorY, scissorW, scissorH)
end



----------------------------------------------------[[ == SLICEDFRAME METHODS == ]]----------------------------------------------------

function SlicedFrame:setReference(img)
	local oldReference = self.ReferenceImage
	self.ReferenceImage = img

	local oldW, oldH = oldReference:getDimensions()
	local newW, newH = img:getDimensions()

	self:setSlice(vector(self.TopLeftSlice), self.BottomRightSlice + vector(newW - oldW, newH - oldH))
end


-- sets the top left and top right corner used to chop the image into 9 quads that are used for the drawing operation
function SlicedFrame:setSlice(topLeft, bottomRight)
	if bottomRight == nil then
		bottomRight = vector(self.ReferenceImage:getDimensions()) - topLeft
	end
	self.TopLeftSlice = topLeft
	self.BottomRightSlice = bottomRight
	-- top row
	self.ImageSlices[1]:setViewport(0, 0, topLeft.x, topLeft.y, self.ReferenceImage);
	self.ImageSlices[2]:setViewport(topLeft.x, 0, bottomRight.x - topLeft.x, topLeft.y, self.ReferenceImage);
	self.ImageSlices[3]:setViewport(bottomRight.x, 0, imgPixelWidth - bottomRight.x, topLeft.y, self.ReferenceImage);
	-- middle row
	self.ImageSlices[4]:setViewport(0, topLeft.y, topLeft.x, bottomRight.y - topLeft.y, self.ReferenceImage);
	self.ImageSlices[5]:setViewport(topLeft.x, topLeft.y, bottomRight.x - topLeft.x, bottomRight.y - topLeft.y, self.ReferenceImage);
	self.ImageSlices[6]:setViewport(bottomRight.x, topLeft.y, imgPixelWidth - bottomRight.x, bottomRight.y - topLeft.y, self.ReferenceImage);
	-- bottom row
	self.ImageSlices[7]:setViewport(0, bottomRight.y, topLeft.x, imgPixelHeight - bottomRight.y, self.ReferenceImage);
	self.ImageSlices[8]:setViewport(topLeft.x, bottomRight.y, bottomRight.x - topLeft.x, imgPixelHeight - bottomRight.y, self.ReferenceImage);
	self.ImageSlices[9]:setViewport(bottomRight.x, bottomRight.y, imgPixelWidth - bottomRight.x, imgPixelHeight - bottomRight.y, self.ReferenceImage);
end


-- draws the sliced image at its location in the UI
function SlicedFrame:draw()
	if self.Hidden then return end

	local imgWidth, imgHeight = self.ReferenceImage:getDimensions()
	local scissorX, scissorY, scissorW, scissorH = love.graphics.getScissor()

	if self.ClipContent == true then
		love.graphics.intersectScissor(self.AbsolutePosition.x, self.AbsolutePosition.y, self.AbsoluteSize.x, self.AbsoluteSize.y)
	end

	local gw, gh = love.graphics.getDimensions()
	-- bounds check to reduce GPU load. Don't need to draw out of bounds!
	if not (self.AbsolutePosition.x > gw or self.AbsolutePosition.x + self.AbsoluteSize.x < 0 or self.AbsolutePosition.y > gh or self.AbsolutePosition.y + self.AbsoluteSize.y < 0) then
		local r, g, b, a = self.Color.r, self.Color.g, self.Color.b, self.Color.a
		if module.PressedElement == self then
			r, g, b, a = self.ColorHold.r, self.ColorHold.g, self.ColorHold.b, self.ColorHold.a
		elseif module.CursorFocus == self then
			r, g, b, a = self.ColorFocus.r, self.ColorFocus.g, self.ColorFocus.b, self.ColorFocus.a
		end

		love.graphics.push() -- push current graphics coordinate state
		love.graphics.translate(self.AbsolutePosition.x + self.AbsoluteSize.x * self.Pivot.x, self.AbsolutePosition.y + self.AbsoluteSize.y * self.Pivot.y)
		love.graphics.rotate(math.rad(self.Rotation))

		love.graphics.setColor(r, g, b, a*self.Opacity)

		local x2 = self.TopLeftSlice.x * self.CornerScale
		local x3 = self.AbsoluteSize.x - (imgWidth - self.BottomRightSlice.x) * self.CornerScale
		local y2 = self.TopLeftSlice.y * self.CornerScale
		local y3 = self.AbsoluteSize.y - (imgHeight - self.BottomRightSlice.y) * self.CornerScale

		local stretchXMultiplier = (self.AbsoluteSize.x - self.BorderWidth * 2 - self.TopLeftSlice.x * self.CornerScale - (imgWidth - self.BottomRightSlice.x) * self.CornerScale) / (self.BottomRightSlice.x - self.TopLeftSlice.x)
		local stretchYMultiplier = (self.AbsoluteSize.y - self.BorderWidth * 2 - self.TopLeftSlice.y * self.CornerScale - (imgHeight - self.BottomRightSlice.y) * self.CornerScale) / (self.BottomRightSlice.y - self.TopLeftSlice.y)

		addCornerStencil(self)
		-- in reading order, top row
		love.graphics.draw(self.ReferenceImage, self.ImageSlices[1], -self.AbsoluteSize.x * self.Pivot.x + self.BorderWidth, -self.AbsoluteSize.y * self.Pivot.y + self.BorderWidth, 0, self.CornerScale, self.CornerScale)
		love.graphics.draw(self.ReferenceImage, self.ImageSlices[2], -self.AbsoluteSize.x * self.Pivot.x + self.BorderWidth + x2, -self.AbsoluteSize.y * self.Pivot.y + self.BorderWidth, 0, stretchXMultiplier, self.CornerScale)
		love.graphics.draw(self.ReferenceImage, self.ImageSlices[3], -self.AbsoluteSize.x * self.Pivot.x - self.BorderWidth + x3, -self.AbsoluteSize.y * self.Pivot.y + self.BorderWidth, 0, self.CornerScale, self.CornerScale)
		-- middle row
		love.graphics.draw(self.ReferenceImage, self.ImageSlices[4], -self.AbsoluteSize.x * self.Pivot.x + self.BorderWidth, -self.AbsoluteSize.y * self.Pivot.y + self.BorderWidth + y2, 0, self.CornerScale, stretchYMultiplier)
		love.graphics.draw(self.ReferenceImage, self.ImageSlices[5], -self.AbsoluteSize.x * self.Pivot.x + self.BorderWidth + x2, -self.AbsoluteSize.y * self.Pivot.y + self.BorderWidth + y2, 0, stretchXMultiplier, stretchYMultiplier)
		love.graphics.draw(self.ReferenceImage, self.ImageSlices[6], -self.AbsoluteSize.x * self.Pivot.x - self.BorderWidth + x3, -self.AbsoluteSize.y * self.Pivot.y + self.BorderWidth + y2, 0, self.CornerScale, stretchYMultiplier)
		-- bottom row
		love.graphics.draw(self.ReferenceImage, self.ImageSlices[7], -self.AbsoluteSize.x * self.Pivot.x + self.BorderWidth, -self.AbsoluteSize.y * self.Pivot.y - self.BorderWidth + y3, 0, self.CornerScale, self.CornerScale)
		love.graphics.draw(self.ReferenceImage, self.ImageSlices[8], -self.AbsoluteSize.x * self.Pivot.x + self.BorderWidth + x2, -self.AbsoluteSize.y * self.Pivot.y - self.BorderWidth + y3, 0, stretchXMultiplier, self.CornerScale)
		love.graphics.draw(self.ReferenceImage, self.ImageSlices[9], -self.AbsoluteSize.x * self.Pivot.x - self.BorderWidth + x3, -self.AbsoluteSize.y * self.Pivot.y - self.BorderWidth + y3, 0, self.CornerScale, self.CornerScale)
		
		clearCornerStencil(self)

		-- draw border
		local cornerArg = (self.CornerRadius.Scale > 0 or self.CornerRadius.Offset > 0) and (math.min(self.AbsoluteSize.x, self.AbsoluteSize.y) * self.CornerRadius.Scale + self.CornerRadius.Offset) or nil
		if self.BorderWidth > 0 then
			love.graphics.setColor(self.BorderColor.r, self.BorderColor.g, self.BorderColor.b, self.BorderColor.a*self.Opacity)
			love.graphics.setLineWidth(self.BorderWidth)
			--love.graphics.rectangle("line", self.AbsolutePosition.x + self.BorderWidth / 2, self.AbsolutePosition.y + self.BorderWidth / 2, self.AbsoluteSize.x - self.BorderWidth, self.AbsoluteSize.y - self.BorderWidth)
			love.graphics.rectangle("line", -self.AbsoluteSize.x * self.Pivot.x + self.BorderWidth / 2, -self.AbsoluteSize.y * self.Pivot.y + self.BorderWidth / 2, self.AbsoluteSize.x - self.BorderWidth, self.AbsoluteSize.y - self.BorderWidth, cornerArg and math.max(0, cornerArg - self.BorderWidth))
		end
		-- draw text on top
		self:drawText()

		love.graphics.pop() -- revert to previous graphics coordinate state
	end

	for i = 1, #self.Children do
		self.Children[i]:draw()
	end
	love.graphics.setScissor(scissorX, scissorY, scissorW, scissorH)
end



----------------------------------------------------[[ == IMAGEFRAME METHODS == ]]----------------------------------------------------

function AnimatedFrame:setReference(anim)
	self.ReferenceAnimation = anim -- is a pointer
end


--[[
	remove the object by:
	- removing its children
	- clearing its tags
	- removing its connected events
	- clearing its font from memory if that font is now unused
]]
function AnimatedFrame:remove()
	local children = {}
	for i = 1, #self.Children do
		children[i] = self.Children[i]
	end
	for i = 1, #children do
		children[i]:remove()
	end
	self.Children = {}
	-- first, remove focus (this is done before unlinking any events, so they can still trigger if there were do be unfocus-events support down the line)
	if self:hasKeyboardFocus() then
		ui:unfocusKeyboard(self)
	end
	-- clear all tags
	self:clearTags()
	-- clear any events (TODO: just setting the event list to nil should be good enough for the garbage collector)
	for eventName, eventList in pairs(self.Events) do
		for index, dataPair in pairs(eventList) do
			if dataPair[2] ~= nil and dataPair[2].Connected then
				dataPair[2]:disconnect()
			end
			eventList[index] = nil
		end
		self.Events[eventName] = nil
	end
	-- stop the referenced animation to remove it from the animation.Active array, so it can get dereferenced
	-- WARNING: IF ONE ANIMATION REFERENCE IS SHARED ACROSS ANIMATED FRAMES, REMOVING ONE OF THEM WILL STOP THE OTHER ANIMATED FRAMES!
	-- TODO: FIX THE ABOVE ISSUE
	self.ReferenceAnimation:stop()
	-- remove any fonts from memory
	if self.TextBlock ~= nil then
		self.TextBlock:clearFont()
		self.TextBlock.Text:release()
		self.TextBlock.Text = nil
	end
	if self.Parent ~= nil then
		local Par = self.Parent
		for i = 1, #Par.Children do
			if Par.Children[i] == self then
				table.remove(Par.Children, i)
				break
			end
		end
	end
	self.Parent = nil
	-- remove CursorFocus if object is focused
	module.Changed = true
end


-- TODO: implement BorderWidth correctly!
function AnimatedFrame:draw()
	if self.Hidden then return end

	local imgSize = self.ReferenceAnimation:getSize()
	local scissorX, scissorY, scissorW, scissorH = love.graphics.getScissor()
	local img, quad = self.ReferenceAnimation:getSprite()

	if self.ClipContent == true then
		love.graphics.intersectScissor(self.AbsolutePosition.x, self.AbsolutePosition.y, self.AbsoluteSize.x, self.AbsoluteSize.y)
	end


	local gw, gh = love.graphics.getDimensions()
	-- bounds check to reduce GPU load. Don't need to draw out of bounds!
	if not (self.AbsolutePosition.x > gw or self.AbsolutePosition.x + self.AbsoluteSize.x < 0 or self.AbsolutePosition.y > gh or self.AbsolutePosition.y + self.AbsoluteSize.y < 0) then
		local r, g, b, a = self.Color.r, self.Color.g, self.Color.b, self.Color.a
		if module.PressedElement == self then
			r, g, b, a = self.ColorHold.r, self.ColorHold.g, self.ColorHold.b, self.ColorHold.a
		elseif module.CursorFocus == self then
			r, g, b, a = self.ColorFocus.r, self.ColorFocus.g, self.ColorFocus.b, self.ColorFocus.a
		end

		love.graphics.push() -- push current graphics coordinate state
		love.graphics.translate(self.AbsolutePosition.x + self.AbsoluteSize.x * self.Pivot.x, self.AbsolutePosition.y + self.AbsoluteSize.y * self.Pivot.y)
		love.graphics.rotate(math.rad(self.Rotation))

		love.graphics.setColor(r, g, b, a*self.Opacity)
		addCornerStencil(self)
		love.graphics.draw(img, quad, -(self.AbsoluteSize.x - self.BorderWidth) * self.Pivot.x, -(self.AbsoluteSize.y - self.BorderWidth) * self.Pivot.y, 0, (self.AbsoluteSize.x - self.BorderWidth) / imgSize.x, (self.AbsoluteSize.y - self.BorderWidth) / imgSize.y)
		clearCornerStencil(self)
		
		-- draw border
		local cornerArg = (self.CornerRadius.Scale > 0 or self.CornerRadius.Offset > 0) and (math.min(self.AbsoluteSize.x, self.AbsoluteSize.y) * self.CornerRadius.Scale + self.CornerRadius.Offset) or nil
		if self.BorderWidth > 0 then
			love.graphics.setColor(self.BorderColor.r, self.BorderColor.g, self.BorderColor.b, self.BorderColor.a*self.Opacity)
			love.graphics.setLineWidth(self.BorderWidth)
			love.graphics.rectangle("line", -self.AbsoluteSize.x * self.Pivot.x + self.BorderWidth / 2, -self.AbsoluteSize.y * self.Pivot.y + self.BorderWidth / 2, self.AbsoluteSize.x - self.BorderWidth, self.AbsoluteSize.y - self.BorderWidth, cornerArg and math.max(0, cornerArg - self.BorderWidth))
		end
		-- draw text on top
		self:drawText()

		love.graphics.pop() -- revert to previous graphics coordinate state
	end

	for i = 1, #self.Children do
		self.Children[i]:draw()
	end
	love.graphics.setScissor(scissorX, scissorY, scissorW, scissorH)
end



----------------------------------------------------[[ == OBJECT CREATION == ]]----------------------------------------------------

-- the base properties of each UIBase
local function newBase(w, h, col)
	local sw, sh, ow, oh
	if vector.isVector(w) and vector.isVector(h) then
		sw = w.x
		sh = w.y
		ow = h.x
		oh = h.y
	else
		sw = 0
		sh = 0
		ow = w
		oh = h
	end
	--col = col == nil and color(1, 1, 1) or color(col)
	if col == nil then
		col = color(1, 1, 1)
	end
	module.TotalCreated = module.TotalCreated + 1
	local Obj = {
		-- properties
		["AbsolutePosition"] = vector(0, 0); -- position in absolute pixels
		["AbsoluteSize"] = vector(ow, oh);
		["BorderColor"] = color(col):darken(0.4); -- color of the inner border of the frame
		["BorderWidth"] = 0; -- border thickness in pixels
		["Center"] = vector(0, 0); -- AnchorPoint from Roblox
		["Children"] = {};
		["Class"] = "Frame";
		["ClipContent"] = true; -- children and text will be cut off if it falls outside of the frame
		["ContentOffset"] = vector();
		["Color"] = col; -- color of the frame. For images, this adjusts the image color
		["ColorFocus"] = col; -- color when the element is being hovered over by the cursor
		["ColorHold"] = col; -- color when the element is being held down
		["CornerRadius"] = {
			["Scale"] = 0; -- scale uses the min(AbsoluteSize.x, AbsoluteSize.y) multiplied by this number
			["Offset"] = 0; -- regular pixels
		};
		["FitTextOnResize"] = false;
		["Hidden"] = false;
		["Id"] = module.TotalCreated;
		["Name"] = "Object"; -- The name of the instance. Names are not unique. They can be used with the :child() method to find a child with a given name inside some parent instance.
		["Opacity"] = 1; -- if 0, this object is not drawn (but children are!)
		--["PaddingX"] = 0; -- an invisible border that creates a smaller inner-window to contain children and text.
		--["PaddingY"] = 0;
		["Padding"] = vector(0, 0); -- an invisible border that creates a smaller inner-window to contain children and text. If 0 < padding < 1, then it's interpreted as a percentage / ratio
		["Parent"] = nil;
		["Pivot"] = vector(0.5, 0.5); -- when working with rotations, pivot determines where rotation is applied, 0,0 = top left, 1,1 = bottom right
		["Position"] = { -- works similar to Roblox's UDim2
			["Scale"] = vector(0, 0);
			["Offset"] = vector(0, 0);
		};
		["Rotation"] = 0;
		--["Size"] = vector(w, h);
		["Size"] = { -- works similar to Roblox's UDim2
			["Scale"] = vector(sw, sh);
			["Offset"] = vector(ow, oh);
		};
		["Tags"] = {}; -- list of tags assigned to this object
		["TextBlock"] = nil;
		["VisualOnly"] = false; -- if true, no events are registered and the object can never be focused, so :at() will ignore the object

		-- events
		["Events"] = {}; -- dictionary where keys are event names, values are pairs of the form {function, connection object}
	}
	return Obj
end

-- create new Frame object
local function newFrame(w, h, col)
	local Obj = newBase(w, h, col)
	setmetatable(Obj, Frame)
	return Obj
end

-- create new ImageFrame object
local function newImageFrame(img, w, h, col) -- tiled: if true, tile the image, else, stretch it
	local Obj = newBase(w or (img == nil and 1 or img:getPixelWidth()), h or (img == nil and 1 or img:getPixelHeight()), col)
	Obj["Class"] = "ImageFrame"

	-- set wrap
	local wrapX, wrapY
	if img ~= nil then
		wrapX, wrapY = img:getWrap()
	end
	Obj["Tiled"] = (wrapX == "repeat" and wrapY == "repeat")

	-- set image
	if img ~= nil then
		Obj["ReferenceImage"] = img
	else
		local imgData = love.image.newImageData(1, 1)
		imgData:mapPixel(function() return 1, 1, 1, 1 end)
		Obj["ReferenceImage"] = love.graphics.newImage(imgData)
	end
	Obj["Quad"] = love.graphics.newQuad(0, 0, Obj.AbsoluteSize.x, Obj.AbsoluteSize.y, Obj.AbsoluteSize.x, Obj.AbsoluteSize.y)

	-- set fitting
	Obj["ImageFit"] = "stretch" -- stretch / cover / contain (stretch = proportions may be messed up, but exact width/height, cover = clipped, contain = open space)


	setmetatable(Obj, ImageFrame)
	return Obj
end

-- create new AnimatedFrame object
local function newAnimatedFrame(anim, w, h, col)
	local Obj = newBase(w or anim.FrameWidth, h or anim.FrameHeight, col)
	Obj["Class"] = "AnimatedFrame"
	Obj["ReferenceAnimation"] = anim
	setmetatable(Obj, AnimatedFrame)
	return Obj
end

-- create new SlicedFrame object
local function newSlicedFrame(img, topLeft, bottomRight, w, h, col, corScale)
	-- create and initialize main object
	local imgPixelWidth, imgPixelHeight = img:getDimensions()
	if bottomRight == nil then
		bottomRight = vector(imgPixelWidth, imgPixelHeight) - topLeft
	end
	local Obj = newBase(w or imgPixelWidth, h or imgPixelHeight, col)
	Obj["Class"] = "SlicedFrame"
	Obj["ReferenceImage"] = img
	Obj["CornerScale"] = corScale or 1
	Obj["TopLeftSlice"] = topLeft
	Obj["BottomRightSlice"] = bottomRight
	Obj["ImageSlices"] = { -- set slices, in reading order
		-- top row
		love.graphics.newQuad(0, 0, topLeft.x, topLeft.y, Obj.ReferenceImage);
		love.graphics.newQuad(topLeft.x, 0, bottomRight.x - topLeft.x, topLeft.y, Obj.ReferenceImage);
		love.graphics.newQuad(bottomRight.x, 0, imgPixelWidth - bottomRight.x, topLeft.y, Obj.ReferenceImage);
		-- middle row
		love.graphics.newQuad(0, topLeft.y, topLeft.x, bottomRight.y - topLeft.y, Obj.ReferenceImage);
		love.graphics.newQuad(topLeft.x, topLeft.y, bottomRight.x - topLeft.x, bottomRight.y - topLeft.y, Obj.ReferenceImage);
		love.graphics.newQuad(bottomRight.x, topLeft.y, imgPixelWidth - bottomRight.x, bottomRight.y - topLeft.y, Obj.ReferenceImage);
		-- bottom row
		love.graphics.newQuad(0, bottomRight.y, topLeft.x, imgPixelHeight - bottomRight.y, Obj.ReferenceImage);
		love.graphics.newQuad(topLeft.x, bottomRight.y, bottomRight.x - topLeft.x, imgPixelHeight - bottomRight.y, Obj.ReferenceImage);
		love.graphics.newQuad(bottomRight.x, bottomRight.y, imgPixelWidth - bottomRight.x, imgPixelHeight - bottomRight.y, Obj.ReferenceImage);
	}

	-- return
	setmetatable(Obj, SlicedFrame)
	return Obj
end



----------------------------------------------------[[ == RETURN == ]]----------------------------------------------------

-- pack up and return module
module.newFrame = newFrame
module.newImageFrame = newImageFrame
module.newSlicedFrame = newSlicedFrame
module.newAnimatedFrame = newAnimatedFrame
--return setmetatable(module, {__call = function(_, ...) return new(...) end})
return module



