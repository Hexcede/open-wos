local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local World = require(ServerScriptService.World)
local Matter = require(ReplicatedStorage.Packages.Matter)
local Chlorine = require(ReplicatedStorage.Packages.Chlorine)

local Microcontroller = World.component("Microcontroller", {
	source = [[print("Hello, World!")]];
})

local Sandbox = Chlorine.Sandbox
local Environment = Chlorine.Environment

World:spawn(Microcontroller())

local globals = setmetatable({}, { __index = getfenv(); })
local baseEnvironment = Environment.new()

return {
	system = function(world: Matter.World)
		for id, microcontrollerRecord in world:queryChanged(Microcontroller) do
			local microcontroller = microcontrollerRecord.new
			local microcontrollerOld = microcontrollerRecord.old

			local sandbox = microcontroller.sandbox
			local environment = microcontroller.environment

			-- Terminate the old sandbox if there is one
			local sandboxOld = microcontrollerOld and microcontrollerOld.sandbox
			if sandboxOld then
				sandboxOld:Terminate()
			end

			-- If the microcontroller was deleted, continue
			if not microcontroller or not world:contains(id) then
				continue
			end

			local body = microcontroller.body
			local bodyOld = microcontrollerOld and microcontrollerOld.body
			if not body then
				-- Try to compile the source code
				local compileError
				body, compileError = loadstring(microcontroller.source, string.format("microcontroller<$%d>", id))
				if not body then
					warn(compileError)
					continue
				end

				-- Create a fresh Sandbox and environment
				sandbox = Sandbox.new()
				environment = baseEnvironment:withFenv(table.clone(globals)):boundTo(sandbox)

				-- Insert the new sandbox, environment, and compiled body
				world:insert(id, microcontroller:patch({
					sandbox = sandbox;
					environment = environment;
					body = body
				}))
				continue
			end

			if body ~= bodyOld then
				-- Insert the new sandbox & environment & clear the current source code
				world:insert(id, microcontroller:patch({
					sandbox = sandbox;
					environment = environment;
				}))

				local success, runtimeError = sandbox:Spawn(environment:applyTo(body))
				if not success then
					warn(runtimeError)
					continue
				end
			end
		end

		if Matter.useThrottle(1) then
			for id, microcontroller in world:query(Microcontroller) do
				world:insert(id, microcontroller:patch({
					source = string.format("print(%q)", math.random());
				}))
			end
		end
	end;
	priority = 1;
}