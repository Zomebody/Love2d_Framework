

----------------------------------------------------[[ == BASE OBJECTS == ]]----------------------------------------------------

local module = {}


local Particles3 = {}
Particles3.__index = Particles3
Particles3.__tostring = function(tab) return "{Particles3 (" .. tostring(tab.MaxParticles) .. ")}" end



--[[


TODO FOR PERFORMANCE OPTIMIZATION

-- standard vertex attributes
vertex attributes
VertexPosition
VertexUVCoordinate
VertexColor
-- attributes related to moving the particle
ParticleLifetime number
ParticleVelocity vec3
ParticleDirection vec3
ParticleRotationSpeed number
ParticleStartRotation number
ParticleScaleOffset number
ParticleEmittedAt number

-- textures that are send to the shader each update
DataTexture: contains gradient, size curve, size offet curve (sizes must be clamped within some range)

-- the basic idea is to create a pool of X instances of a mesh upon creation of a particle.
Each vertex's direction, rotation, scale etc. is randomly initialized. When you call e.g. :emit(20),
the first 20 particles in the pool are emitted. If you call :emit(20) again, the next 20 particles
are emitted until you run out of 'pool' and wrap back round. This means emission patterns are not
super random, but if the pool is large enough and you will never notice. Plus, if your pool size
is exactly the size of how many particles you emit, you'll get consistent results!

So on each :emit() call, you update the vertex attributes of the correct indices. You'll need some
counter that keeps track of where in the pool you are currently. On a :draw() call you draw every
particle, but in the shader you discard any fragment that is too old (past its lifetime). On an
:update() call all you do is send a new 'time' uniform to the shader, that's all.


]]



----------------------------------------------------[[ == HELPER FUNCTIONS == ]]----------------------------------------------------

local function getVectorInCone(vec, maxAngle)
	local vecNormal = vector3(vec):setMag(1)


	-- generate random polar and azimuthal angles (whatever that may mean)
	local theta = math.acos(love.math.random() * (math.cos(maxAngle) - 1) + 1) -- constrain to cone
	local phi = math.random() * 2 * math.pi

	-- convert spherical coordinates to Cartesian coordinates
	local randomVector = vector3(
		math.sin(theta) * math.cos(phi),
		math.sin(theta) * math.sin(phi),
		math.cos(theta)
	)

	---------


	-- align the random vector with the base vector
	local up = vector3(0, 0, 1)
	if math.abs(vecNormal.z) > 0.999 then -- Handle near-vertical vectors
		up = vector3(1, 0, 0)
	end

	-- Compute a rotation matrix
	local right = vector3(
		up.y * vecNormal.z - up.z * vecNormal.y,
		up.z * vecNormal.x - up.x * vecNormal.z,
		up.x * vecNormal.y - up.y * vecNormal.x
	)
	right:setMag(1)
	local upAligned = vector3(
		vecNormal.y * right.z - vecNormal.z * right.y,
		vecNormal.z * right.x - vecNormal.x * right.z,
		vecNormal.x * right.y - vecNormal.y * right.x
	)

	-- apply rotation matrix to random vector
	local newRandomVector = vector3(
		randomVector.x * right.x + randomVector.y * upAligned.x + randomVector.z * vecNormal.x,
		randomVector.x * right.y + randomVector.y * upAligned.y + randomVector.z * vecNormal.y,
		randomVector.x * right.z + randomVector.y * upAligned.z + randomVector.z * vecNormal.z
	)
	newRandomVector:setMag(1)

	return newRandomVector
end



----------------------------------------------------[[ == FUNCTIONS == ]]----------------------------------------------------

-- check if an object is a particles3
local function isParticles3(t)
	return getmetatable(t) == Particles3
end



-- emit a certain number of particles at once from the source
--[[
function Particles3:emit(count)
	local t = love.timer.getTime()
	for i = 1, count do
		local randomVector = getVectorInCone(self.Direction, self.DirectionDeviation)
		table.insert(self.Spawned, {t, self.Lifetime:randomDecimal(), self.Rotation:randomDecimal(), self.RotationSpeed:randomDecimal(), randomVector, self.Speed:randomDecimal(), love.math.random() * 2 - 1})
	end
	if #self.Spawned > self.MaxParticles then
		local toRemove = #self.Spawned - self.MaxParticles
		for i = 1, toRemove do
			table.remove(self.Spawned, 1) -- remove the oldest particles
		end
	end
end
]]


-- update the position and size of each particle. TODO: probably rename this to :render() or something, since you'll only need to update the info when you're going to render the particles
-- and you won't be rendering the particle emitter multiple times per frame if you're smart
-- or maybe not. Maybe the play is to manually choose when to update particles so you can have them frozen in time or something
--[[
function Particles3:update()
	local time = love.timer.getTime()
	local index = 1
	while index <= #self.Spawned do

		-- remove any particles that are too old
		if time - self.Spawned[index][1] > self.Spawned[index][2] then
			self.Spawned[index] = self.Spawned[#self.Spawned]
			self.Spawned[#self.Spawned] = nil
			--table.remove(self.Spawned, index) -- remove the index from the table, shifting all indices after it 1 forwards
		else
			local vars = self.Spawned[index]

			-- if the particle wasn't removed, update its size, position and rotation
			local newPosition = self.Source + vars[5] * vars[6] * (time - vars[1]) + 0.5 * self.Gravity * (time - vars[1])^2
			local newRotation = vars[3] + vars[4] * (time - vars[1])
			local x = (time - vars[1]) / vars[2]
			local newSize = vars[7] * self.SizeDeviation:getNumber(x) + self.Size:getNumber(x)
			local newColor = self.Gradient:getColor(x)

			-- +10fps for doing this instead of setting each vertex attribute separately
			self.Instances:setVertex(index, newPosition.x, newPosition.y, newPosition.z, newRotation, newSize, newColor.r, newColor.g, newColor.b)

			index = index + 1 -- item was not removed, so move the index one further
		end
	end
end
]]

function Particles3:emit(count)
	local emittedAt = love.timer.getTime()
	local position = self.Source

	for i = 1, count do

		-- calculate new instance properties
		local lifetime = self.Lifetime:randomDecimal()
		local velocity = getVectorInCone(self.Direction, self.DirectionDeviation) * self.Speed:randomDecimal()
		local rotation = self.Rotation:randomDecimal()
		local rotationSpeed = self.RotationSpeed:randomDecimal()
		local scaleOffset = (love.math.random() - 0.5) * 2

		self.Instances:setVertex(self.SpawnIndex, position.x, position.y, position.z, emittedAt, lifetime, velocity.x, velocity.y, velocity.z, rotation, rotationSpeed, scaleOffset)

		self.SpawnIndex = (self.SpawnIndex % self.MaxParticles) + 1
	end
end


--[[
function Particles3:update()

end
]]


function Particles3:draw(shaderRef)
	shaderRef:send("dataTexture", self.DataTexture)
	shaderRef:send("gravity", {self.Gravity.x, self.Gravity.y, self.Gravity.z})
	shaderRef:send("currentTime", love.timer.getTime())
	love.graphics.drawInstanced(self.Mesh, self.MaxParticles) -- draw all the particles, but in practice most of them will be drawn at a scale of 0 because they're inactive
end



-- create a new particle emitter which uses the given image and can emit at most maxParticles at once
local function new(img, maxParticles, properties)

	-- create quad mesh with the texture on top of it, to be used when rendering the particle in 3d
	local mesh = love.graphics.newMesh(
		{
			{"VertexPosition", "float", 3},
			{"VertexTexCoord", "float", 2}
		},
		{
			{0.5, 0.5, 0, 0, 0},
			{-0.5, 0.5, 0, 1, 0},
			{0.5, -0.5, 0, 0, 1},
			{0.5, -0.5, 0, 0, 1},
			{-0.5, 0.5, 0, 1, 0},
			{-0.5, -0.5, 0, 1, 1}
		},
		"triangles",
		"static"
	)

	mesh:setTexture(img)

	-- dummy data, will be updated automatically when :emit() is called
	local instancesData = {}
	for i = 1, maxParticles do
		instancesData[i] = {0, 0, 0, -9999, 0, 0, 0, 0, 0, 0, 0}
	end

	-- create instance mesh
	local instanceMesh = love.graphics.newMesh(
		{
			{"instPosition", "float", 3},
			{"instEmittedAt", "float", 1},
			{"instLifetime", "float", 1},
			{"instVelocity", "float", 3},
			{"instRotation", "float", 1},
			{"instRotationSpeed", "float", 1},
			{"instScaleOffset", "float", 1}
		},
		instancesData,
		"triangles",
		"stream"
	)

	mesh:attachAttribute("instPosition", instanceMesh, "perinstance") -- first vertex attribute
	mesh:attachAttribute("instEmittedAt", instanceMesh, "perinstance") -- second vertex attribute
	mesh:attachAttribute("instLifetime", instanceMesh, "perinstance") -- third vertex attribute
	mesh:attachAttribute("instVelocity", instanceMesh, "perinstance") -- fourth vertex attribute
	mesh:attachAttribute("instRotation", instanceMesh, "perinstance") -- fifth vertex attribute
	mesh:attachAttribute("instRotationSpeed", instanceMesh, "perinstance") -- sixth vertex attribute
	mesh:attachAttribute("instScaleOffset", instanceMesh, "perinstance") -- seventh vertex attribute

	local gradient = properties.Gradient or gradient(0, color(1, 1, 1), 1, color(1, 1, 1))
	local source = properties.Source or vector3(0, 0, 0)
	local direction = properties.Direction or vector3(0, 1, 0)
	local directionDeviation = properties.DirectionDeviation or math.pi / 8
	local gravity = properties.Gravity or vector3(0, 0, 0)
	local speed = properties.Speed or range(1, 1)
	local rotation = properties.Rotation or range(0, math.pi * 2)
	local rotationSpeed = properties.RotationSpeed or range(-1, 1)
	local size = properties.Size or numbercurve(0, 1, 1, 1)
	local sizeDeviation = properties.SizeDeviation or numbercurve(0, 0, 1, 0)
	local lifetime = properties.Lifetime or range(1.5, 2)

	local data = love.image.newImageData(64, 2)
	data:mapPixel(
		function(x, y, r, g, b, a)
			if y == 0 then
				local c = gradient:getColor(x / 64)
				return c:components()
			else
				local s1 = size:getNumber(x / 64) / 10
				local s2 = sizeDeviation:getNumber(x / 64) / 10
				local high1 = math.floor(s1 * 256) / 256
				local low1 = s1 * 256 % 1
				local high2 = math.floor(s2 * 256) / 256
				local low2 = s2 * 256 % 1
				return high1, low1, high2, low2
			end
		end
	)
	local dataTexture = love.graphics.newImage(data)


	local Obj = {
		["Gradient"] = gradient; -- the color the particle has at a given moment in time
		["Source"] = source; -- location from which particles are emitted
		["Direction"] = direction; -- the direction the particles get emitted from
		["DirectionDeviation"] = directionDeviation; -- when the particle is emitted, it deviates from the direction with at most this angle (at random)
		["Gravity"] = gravity; -- direction into which the particles accelerate
		["Speed"] = speed; -- minimum and maximum speed at which the particle is emitted
		["Rotation"] = rotation; -- minimum and maximum rotation at which the particle is emitted
		["RotationSpeed"] = rotationSpeed; -- the minimum and maximum speed with which the particle rotates around its center (in radians per second)
		["Size"] = size; -- the size of the particle over time
		["SizeDeviation"] = sizeDeviation; -- the size of a particle can deviate by at most this much
		["Lifetime"] = lifetime; -- for how long the particle lives at minimum & maximum

		["DataTexture"] = dataTexture; -- contains curves encoded into an image for faster look-ups on the GPU

		--["Spawned"] = {}; -- array of particles that are currently alive. Contains info to computer the particle's position & size. Each index has the form {spawnTime, lifetime, startRot, rotSpeed, direction, speed, sizeDeviation}
		["SpawnIndex"] = 1; -- counter that keeps track of how many particles have spawned so it knows which particles are next up in the pool to emit

		["Mesh"] = mesh;
		["Instances"] = instanceMesh;

		["MaxParticles"] = maxParticles; -- maximum number of particles that can be emitted. Cannot be changed as it's tied to the mesh instancing logic
	}

	return setmetatable(Obj, Particles3)
end




----------------------------------------------------[[ == RETURN == ]]----------------------------------------------------

module.newParticles3 = newParticles3
module.isParticles3 = isParticles3
return setmetatable(module, {__call = function(_, ...) return new(...) end})


