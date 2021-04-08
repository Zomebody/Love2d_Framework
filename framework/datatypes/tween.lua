
--[[
tween.new(Target, tweenType, duration, valueTable)
object:play()
object:pause()
object:stop()
-- internal
object:update()

]]


----------------------------------------------------[[ == VARIABLES & IMPORTS == ]]----------------------------------------------------

local module = {}
module.Active = {}


local tween = {}
tween.__index = tween



----------------------------------------------------[[ == TWEENING FUNCTIONS == ]]----------------------------------------------------

local interpolations = {}

interpolations["bounce"] = function(x) return (x < 0.5) and (4 * x^2) or (4 * (x - 0.75)^2 + 0.75) end

interpolations["circle"] = function(x) return math.sqrt(1 - (1 - x)^2) end

interpolations["cubed"] = function(x) return x^4 end
interpolations["cube"] = interpolations["cubed"]

interpolations["back"] = function(x) return (1 - 5^(-3*x) * math.cos(1.5 * math.pi * x)) end
interpolations["dampen"] = interpolations["back"]

interpolations["linear"] = function(x) return x end

interpolations["recoil"] = function(x) return (x < math.sqrt(0.5)) and (2 * x^2) or (2 * (x - (1 - 0.5 * (1 - (1 / math.sqrt(2)))))^2 + 1 - 2 * (0.5 * (1 - (1 / math.sqrt(2))))^2) end

interpolations["shake"] = function(x) return (1 - 2^(-9*x) * math.cos(10.5 * math.pi * x)) end

interpolations["sine"] = function(x) return (math.sin(math.pi * (x - 0.5))/2 + 0.5) end

interpolations["sqrt"] = function(x) return math.sqrt(x) end
interpolations["root"] = interpolations["sqrt"]

interpolations["squared"] = function(x) return x^2 end
interpolations["quad"] = interpolations["squared"]
interpolations["quadratic"] = interpolations["squared"]



----------------------------------------------------[[ == TWEEN METHODS == ]]----------------------------------------------------

-- returns a value between 0 and 1 where 0 is 'just started' and 1 is 'completed'
function tween:getProgress()
	return self.Progress
end


-- return the value for the given key
function tween:getValue(key)
	return self.Values.Current[key]
end


-- if the tween is playing, cancel is and call its OnStop callback
function tween:cancel()
	self:stop(false)
end


-- if the tween is playing, stop the tween, but don't reset its properties
function tween:pause()
	if not self.Playing then
		return false
	end
	self.Playing = false
	return true
end


-- play the tween without resetting the properties
function tween:resume()
	if self.Playing then
		return false
	end
	self.Playing = true
	return true
end


-- tweenType = "sine", "circle", "linear", "quadratic"/"quad"/"squared, "cubed", "sqrt"/"root", "dampen"/"back", "recoil"
-- you can combine two tweens with a space in between to combine the two
function tween:play(reversed, inversed)
	if self.Playing then
		return false
	end
	self.Reversed = reversed == true and true or false
	self.Inversed = inversed == true and true or false
	self.Playing = true
	module.Active[#module.Active + 1] = self
	return true
end


-- fully stop the tween. Even if it's paused. Reset values and remove from the list.
function tween:stop(complete)
	if not (self.Playing or self.Progress > 0) then
		return false
	end
	self.Playing = false
	self.TimePlayed = 0

	-- call OnStop callback
	if self.OnStop ~= nil then
		self.OnStop(complete and "complete" or "cancelled")
	end

	return true
end


function tween:update(dt)
	if self.Playing then
		-- update time played
		self.TimePlayed = self.TimePlayed + dt
		if self.TimePlayed > self.Duration then
			self.TimePlayed = self.Duration
		end

		-- set new progress
		self.Progress = self.TimePlayed / self.Duration

		-- calculate x and set current values
		local x = nil
		if self.Reversed then
			x = interpolations[self.TweenType](1 - self.Progress)
		else
			x = interpolations[self.TweenType](self.Progress)
		end
		if self.Inversed then
			x = 1 - x
		end
		for k, v in pairs(self.Values.Current) do
			local newValue = self.Values.Start[k] + x * (self.Values.Goal[k] - self.Values.Start[k])
			self.Values.Current[k] = newValue
			self.Target[k] = newValue
		end

		-- call OnUpdate
		if self.OnUpdate ~= nil then
			self.OnUpdate(self.TimePlayed / self.Duration)
		end

		-- stop tween if at the end
		if self.TimePlayed == self.Duration then
			self:stop(true)
			return true
		end
	end
	return false
end



----------------------------------------------------[[ == MODULE METHODS == ]]----------------------------------------------------

function module:initialize()
	if not module.Initialized then
		module.Initialized = true
	else
		return
	end

	-- Monkey Patching love.update such that tweens are played at the start
	local update = love.update or function() end
	love.update = function()
		self:update()
		update()
	end
end

-- update all tweens
function module:update()
	local dt = love.timer.getDelta()
	local i = 1
	while i <= #module.Active do
		local stopped = module.Active[i]:update(dt)
		if not stopped then
			i = i + 1
		else
			table.remove(module.Active, i)
		end
	end
	--module:removeInactive()
end



----------------------------------------------------[[ == OBJECT CREATION == ]]----------------------------------------------------

-- create a new tween object and set its metatable and return it
-- valueTable is key/value dictionary. If the key is a method, the method is called with the tweened variable instead
function new(Target, tweenType, duration, valueTable)
	local t = {
		["Target"] = Target;
		["TimePlayed"] = 0;
		["Progress"] = 0;
		["Duration"] = duration;
		["TweenType"] = tweenType;
		["Reversed"] = false; -- play from end value to start value (mirror on x-axis)
		["Inversed"] = false; -- inverse the interpolation constant (mirror on y-axis)
		["Playing"] = false;
		["Values"] = {
			["Start"] = {};
			["Current"] = {};
			["Goal"] = {};
		};
		-- callbacks
		["OnStop"] = nil; -- called right when the tween ends
		["OnUpdate"] = nil; -- called at the end of each tween:update() call
	}

	for k, v in pairs(valueTable) do
		t.Values.Start[k] = Target[k]
		t.Values.Current[k] = Target[k]
		t.Values.Goal[k] = v
	end
	return setmetatable(t, tween)
end



----------------------------------------------------[[ == RETURN == ]]----------------------------------------------------

module.new = new
return setmetatable(module, {__call = function(_, ...) return new(...) end})


