local ServerScriptService = game:GetService("ServerScriptService")

local Object = require(ServerScriptService:WaitForChild("Object"))
local Permissions = require(ServerScriptService:WaitForChild("Permissions"))

-------------------------------------------------------------------------------------------------------------------------
-- @CloneTrooper1019, 2017-2018 <3
-- ClassicBuildTools.lua
-- A FilteringEnabled port of Roblox's classic build tools.
-------------------------------------------------------------------------------------------------------------------------
-- Initial Declarations
-------------------------------------------------------------------------------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local DraggerService = Instance.new("Folder")
DraggerService.Name = "DraggerService"
DraggerService.Parent = ReplicatedStorage

local DraggerGateway = Instance.new("RemoteFunction")
DraggerGateway.Name = "DraggerGateway"
DraggerGateway.Parent = DraggerService

local SubmitUpdate = Instance.new("RemoteEvent")
SubmitUpdate.Name = "SubmitUpdate"
SubmitUpdate.Parent = DraggerService

local DECLARED_BUILD_TOOLS =
{
	GameTool = true;
	Clone = true;
	Hammer = true;
}

-------------------------------------------------------------------------------------------------------------------------
-- Server Gateway Logic
-------------------------------------------------------------------------------------------------------------------------
--[[

~ HOW THIS WORKS ~

	* In order to drag an object, a player must request permission from the server to drag the object.
	* If any of the following conditions are true, the request will be rejected:
		* The object is Locked.
		* The player is dragging another object, and hasn't released it.
		* The object is being dragged by another player.
		* The player does not have a character.
		* The player does not have the tool corresponding to the action equipped.
	* If the player is granted permission...
		* A key is generated representing the current drag action, and this key is passed back to the player.
		* This key marks both the object being dragged, and the player.
		* The player can submit the key and a CFrame to the SubmitUpdate event to move the object.
		* The player MUST release the key in order to drag another object, or their request is rejected.
		* Key is automatically released if the object is destroyed, or the player leaves the game.
--]]

local activeKeys = {}
local deleteDebounce = {}

local objectToKey = {}
local playerToKey = {}

local collideParams = OverlapParams.new()
collideParams.MaxParts = 1
local function doesCollide(parts: {BasePart})
	for _, part in ipairs(parts) do
		local collisions = workspace:GetPartsInPart(part, collideParams)
		if collisions[1] then
			return true
		end
	end
	return false
end

local function canGiveKey(player: Player, object: Instance)
	if object:IsA("BasePart") and object.Locked then
		return false
	end

	-- Not a custom part object
	if not Object.fromReference(object) then
		return false
	end

	-- Player cannot drag object
	if not Permissions:CanDrag(player, object) then
		return false
	end

	if playerToKey[player] then
		print("Player already dragging.")
		return false
	end

	if objectToKey[object] then
		print("Object already being dragged.")
		return false
	end

	return true
end

local function canDelete(player: Player, object: Instance)
	if not canGiveKey(player, object) then
		return false
	end

	if not Permissions:CanDelete(player, object) then
		return false
	end

	return true
end

local function getObject(object)
	while object.Parent ~= workspace and object:IsA("PVInstance") do
		object = object.Parent
	end
	return object
end

local function getPartsInObject(object): {BasePart}
	if object:IsA("BasePart") then
		return {object}
	end

	local partCount = 0
	local descendants = object:GetDescendants()
	for _, descendant in ipairs(descendants) do
		if descendant:IsA("BasePart") then
			partCount += 1
		end
	end

	local parts = table.create(partCount)
	for _, descendant in ipairs(descendants) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

--local function claimAssembly(player: Player, part: BasePart)
--	if part:CanSetNetworkOwnership() then
--		part:SetNetworkOwner(player)
--	end
--end

local function removeObjectKey(key: string, joinSurfaces: boolean)
	local data = activeKeys[key]

	if data then
		local player = data.Player
		local object = data.Object

		if player then
			playerToKey[player] = nil
		end

		if data.AncestryListener then
			data.AncestryListener:Disconnect()
		end

		if object then

			local parts = data.PartData
			if parts then
				if joinSurfaces then
					-- Connect parts to nearby surfaces
					workspace:JoinToOutsiders(data.Parts, "Surface")
				end
				for _, data in ipairs(parts) do
					local part = data.Part
					part.Anchored = data.Anchored
					part.CanCollide = data.CanCollide
					part.CanTouch = data.CanTouch
					part.CanQuery = data.CanQuery
					part.CollisionGroupId = data.CollisionGroupId
					--claimAssembly(player, part)
				end
			end

			objectToKey[object] = nil
		end

		activeKeys[key] = nil
	end
end

local function playerIsUsingTool(player,toolName)
	local char = player.Character

	if char then
		local tool = char:FindFirstChildWhichIsA("Tool")
		if tool and CollectionService:HasTag(tool, toolName) then
			return true, tool
		end
	end

	return false
end

local function swingBuildTool(player)
	local char = player.Character
	if char then
		local tool = char:FindFirstChildWhichIsA("Tool")
		if tool and tool.RequiresHandle and CollectionService:HasTag(tool, "BuildTool") then
			local toolAnim = Instance.new("StringValue")
			toolAnim.Name = "toolanim"
			toolAnim.Value = "Slash"
			toolAnim.Parent = tool
		end
	end
end

function DraggerGateway.OnServerInvoke(player, request, ...)
	if request == "GetKey" then
		local worldObject, asClone = ...
		worldObject = getObject(worldObject)
		local object = Object.fromReference(worldObject)
		if not object then
			return false
		end

		if asClone then
			if playerIsUsingTool(player, "Clone") then
				local newObject = object:Clone()
				newObject:BreakJoints()
				newObject.Parent = workspace

				local copySound = Instance.new("Sound")
				copySound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
				copySound.Parent = worldObject
				copySound.Archivable = false
				copySound:Play()

				worldObject = newObject
				return false
			else
				return false
			end
		elseif not playerIsUsingTool(player, "GameTool") then
			return false
		end

		if canGiveKey(player, worldObject) then
			local char = player.Character
			if char then
				local key = HttpService:GenerateGUID(false)
				playerToKey[player] = key
				objectToKey[worldObject] = key

				local ancestryListener = worldObject.AncestryChanged:Connect(function()
					if not worldObject:IsDescendantOf(workspace) then
						removeObjectKey(key, false)
					end
				end)
				swingBuildTool(player)

				--claimAssembly(player, part)
				
				--part:BreakJoints()
				local parts = getPartsInObject(worldObject)
				workspace:UnjoinFromOutsiders(parts)

				local partData = table.create(#parts)
				for _, part in ipairs(parts) do
					local anchored = part.Anchored
					local canCollide = part.CanCollide
					local canTouch = part.CanTouch
					local canQuery = part.CanQuery
					local collisionGroupId = part.CollisionGroupId

					part.Anchored = true
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false
					PhysicsService:SetPartCollisionGroup(part, "DraggedObject")

					table.insert(partData, {
						Part = part;
						Anchored = anchored;
						AncestryListener = ancestryListener;
						CanCollide = canCollide;
						CanTouch = canTouch;
						CanQuery = canQuery;
						CollisionGroupId = collisionGroupId;
					})
				end

				activeKeys[key] =
				{
					Player = player;
					Object = worldObject;
					Parts = parts;
					PartData = partData;
				}

				return true, key, worldObject
			end
		end

		return false
	elseif request == "ClearKey" then
		local key, joinSurfaces = ...

		if not key then
			key = playerToKey[player]
		end

		if key then
			local data = activeKeys[key]
			if data then
				local owner = data.Player
				if player == owner then
					removeObjectKey(key, joinSurfaces)
				end
			end
		end
	elseif request == "RequestDelete" then
		if not deleteDebounce[player] and playerIsUsingTool(player, "Hammer") then
			local object = ...

			if canDelete(player, object) then
				local pivot = object:GetPivot()

				local e = Instance.new("Explosion")
				e.BlastPressure = 0
				e.Position = pivot.Position
				e.Parent = workspace

				local s = Instance.new("Sound")
				s.PlayOnRemove = true
				s.SoundId = "rbxasset://sounds/collide.wav"
				s.Volume = 1
				s.Parent = object

				swingBuildTool(player)
				--claimAssembly(player, object)
				
				object:Destroy()
			end

			task.wait(.1)
			deleteDebounce[player] = false
		end
	end
end


local function onSubmitUpdate(player, key, cframe)
	local keyData = activeKeys[key]
	if keyData then
		local owner = keyData.Player
		if owner == player then
			local object = keyData.Object
			if object and object:IsDescendantOf(workspace) then
				local oldPivot = object:GetPivot()
				object:PivotTo(cframe)

				local parts = keyData.Parts
				if doesCollide(parts) then
					object:PivotTo(oldPivot)
				end
			end
		end
	end
end

SubmitUpdate.OnServerEvent:Connect(onSubmitUpdate)

----------------------------------------------------------------------------------------------------------------------------
-- Tool Initialization
----------------------------------------------------------------------------------------------------------------------------

local draggerScript = script:WaitForChild("DraggerScript")

for toolName in pairs(DECLARED_BUILD_TOOLS) do
	local BuildToolAdded = CollectionService:GetInstanceAddedSignal(toolName)
	local BuildToolRemoved = CollectionService:GetInstanceRemovedSignal(toolName)

	local function onBuildToolAdded(tool)
		if tool:IsA("Tool") and not CollectionService:HasTag(tool, "BuildTool") then
			tool.Name = toolName
			tool.CanBeDropped = false

			local dragger = draggerScript:Clone()
			dragger.Parent = tool
			dragger.Disabled = false

			CollectionService:AddTag(tool, "BuildTool")
		end
	end

	local function onBuildToolRemoved(tool)
		if tool:IsA("Tool") and CollectionService:HasTag(tool, "BuildTool") then
			CollectionService:RemoveTag(tool, toolName)
			CollectionService:RemoveTag(tool, "BuildTool")

			local char = tool.Parent
			if char and char:IsA("Model") then
				local humanoid = char:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:UnequipTools()
				end
			end

			if tool:FindFirstChild("DraggerScript") then
				tool.DraggerScript:Destroy()
			end
		end
	end

	for _,buildTool in pairs(CollectionService:GetTagged(toolName)) do
		onBuildToolAdded(buildTool)
	end

	BuildToolAdded:Connect(onBuildToolAdded)
	BuildToolRemoved:Connect(onBuildToolRemoved)
end


----------------------------------------------------------------------------------------------------------------------------
-- Player/HopperBin tracking
----------------------------------------------------------------------------------------------------------------------------

local function onDescendantAdded(desc)
	if desc:IsA("HopperBin") then
		local toolName = desc.BinType.Name
		if DECLARED_BUILD_TOOLS[toolName] then
			local tool = Instance.new("Tool")
			tool.RequiresHandle = false
			tool.Parent = desc.Parent

			CollectionService:AddTag(tool, toolName)
			desc:Destroy()
		end
	end
end

local function onPlayerAdded(player)
	for _, desc in pairs(player:GetDescendants()) do
		onDescendantAdded(desc)
	end
	player.DescendantAdded:Connect(onDescendantAdded)
end

local function onPlayerRemoved(player)
	local key = playerToKey[player]
	if key then
		removeObjectKey(key, true)
	end
end

for _, player in pairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoved)