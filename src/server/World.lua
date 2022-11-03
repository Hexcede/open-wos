local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Plasma = require(ReplicatedStorage.Packages.Plasma)
local Matter = require(ReplicatedStorage.Packages.Matter)

local debugger = Matter.Debugger.new(Plasma)

local world = Matter.World.new()
local loop = Matter.Loop.new(world)

if debugger then
	debugger:autoInitialize(loop)
end

task.defer(function()
	local systems = {}
	for _, system in ipairs(ServerScriptService:WaitForChild("Systems"):GetChildren()) do
		table.insert(systems, require(system))
	end
	loop:scheduleSystems(systems)

	loop:begin({
		default = RunService.Heartbeat
	})
end)

function debugger.authorize(player: Player)
	return RunService:IsStudio() or player.UserId == game.CreatorId
end

local components = {}
function world.component(name: string, defaults: any?)
	local component = components[name]
	if not component then
		component = Matter.component(name, defaults)
		components[name] = component
	end
	return component
end

return world