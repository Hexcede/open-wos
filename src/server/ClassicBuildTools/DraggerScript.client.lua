---------------------------------------------------------------------------------------------------------------------------
-- @CloneTrooper1019, 2017 <3
-- DraggerScript.lua
-- This script emulates the behavior of Roblox's classic build tools.
---------------------------------------------------------------------------------------------------------------------------
-- Initial declarations
---------------------------------------------------------------------------------------------------------------------------

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Dragger = Instance.new("Dragger")

local updateDelay = 1/45 -- Delay between sending dragger updates to the server

local tool = script.Parent

local selection = Instance.new("SelectionBox")
selection.Parent = tool
selection.Transparency = 1

local mode = tool.Name
local draggerService = ReplicatedStorage:WaitForChild("DraggerService")
local gateway = draggerService:WaitForChild("DraggerGateway")
local submitUpdate = draggerService:WaitForChild("SubmitUpdate")

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Keys
----------------------------------------------------------------------------------------------------------------------------------------------------------------

local keyLocks = {}

local function onInputEnded(input)
	if keyLocks[input.KeyCode.Name] then
		keyLocks[input.KeyCode.Name] = nil
	end
end

local function isKeyDown(key)
	if UserInputService:IsKeyDown(key) and not keyLocks[key] then
		keyLocks[key] = true
		return true
	end
	return false
end

UserInputService.InputEnded:Connect(onInputEnded)

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tool Style
----------------------------------------------------------------------------------------------------------------------------------------------------------------

local style =
{
	GameTool = 
	{
		Icon = "rbxassetid://1048129653";
		HoverColor = Color3.fromRGB(25,153,255);
		Cursors = 
		{
			Idle = "rbxassetid://1000000";
			Hover = "rbxasset://textures/DragCursor.png";
			Grab = "rbxasset://textures/GrabRotateCursor.png";
		};
	};
	Clone = 
	{
		Icon = "rbxasset://textures/Clone.png";
		HoverColor = Color3.fromRGB(25,153,255);
		Cursors =
		{
			Idle = "rbxasset://textures/CloneCursor.png";
			Hover = "rbxassetid://1048136830";
			Grab = "rbxasset://textures/GrabRotateCursor.png";		
		}
	};
	Hammer =
	{
		Icon = "rbxasset://textures/Hammer.png";
		HoverColor = Color3.new(1,0.5,0);
		CanShowWithHover = true;
		Cursors = 
		{
			Idle = "rbxasset://textures/HammerCursor.png";
			Hover = "rbxasset://textures/HammerOverCursor.png";
		}
	}
}

if not style[mode] then
	error("Bad mode specification: " .. mode)
end

local function getIcon(iconType)
	return style[mode].Cursors[iconType]
end

tool.TextureId = style[mode].Icon
selection.Color3 = style[mode].HoverColor
if style[mode].CanShowWithHover then
	selection.Transparency = 0
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Dragger
----------------------------------------------------------------------------------------------------------------------------------------------------------------

local mouse
local currentKey
local down = false
local debounce = false

local function getObject(object)
	while object.Parent ~= workspace and object:IsA("PVInstance") do
		object = object.Parent
	end
	return object
end

local function getMainPart(object)
	if object:IsA("BasePart") then
		return object
	elseif object:IsA("Model") then
		local primaryPart = object.PrimaryPart
		if primaryPart then
			return primaryPart
		end
	end

	local rootPart = object:FindFirstChildWhichIsA("BasePart", true)
	if rootPart then
		return getMainPart(rootPart)
	end
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

local function onIdle()
	if (not down) and mouse then
		local mouseObject = mouse.Target
		if mouseObject then
			mouseObject = getObject(mouseObject)
			if CollectionService:HasTag(mouseObject, "Object") then
				selection.Adornee = mouseObject
				mouse.Icon = getIcon("Hover")
				return
			end
		end
		selection.Adornee = nil
		mouse.Icon = getIcon("Idle")
	end
end

local function startDraggerAction(mouseObject)
	local rootPart = getMainPart(mouseObject)
	if not rootPart or not (rootPart == mouseObject or rootPart:IsDescendantOf(mouseObject)) then
		return
	end
	
	if mode == "Hammer" then
		gateway:InvokeServer("RequestDelete", mouseObject)
		return
	end
	
	local pointOnMousePart = rootPart.CFrame:ToObjectSpace(mouse.Hit).Position
	local canDrag, dragKey, mouseObject = gateway:InvokeServer("GetKey", mouseObject, mode == "Clone")
	
	if canDrag then
		local parts = getPartsInObject(mouseObject)
		
		selection.Adornee = mouseObject
		selection.Transparency = 0
		down = true
		currentKey = dragKey
		mouse.Icon = getIcon("Grab")
		Dragger:MouseDown(rootPart, pointOnMousePart, parts)
		
		local parentThread = coroutine.running()
		
		local pivot = mouseObject:GetPivot()
		
		local lastSubmit = 0
		RunService:BindToRenderStep("Dragger", Enum.RenderPriority.Input.Value + 1, function()
			if not down then
				submitUpdate:FireServer(currentKey, pivot)
				RunService:UnbindFromRenderStep("Dragger")
				coroutine.resume(parentThread)
				return
			end

			local mouseObject = selection.Adornee
			if mouseObject and currentKey then
				mouseObject:PivotTo(pivot)
			end
			
			local now = os.clock()
			Dragger:MouseMove(mouse.UnitRay)

			if mouseObject and currentKey then
				if isKeyDown('R') then
					Dragger:AxisRotate('Z')
				elseif isKeyDown('T') then
					Dragger:AxisRotate('X')
				end

				pivot = mouseObject:GetPivot()
				
				local isColliding = doesCollide(parts)
				if not isColliding then
					if now - lastSubmit > updateDelay or not down then
						submitUpdate:FireServer(currentKey, pivot)
						lastSubmit = now
					end
				end
			end
		end)
		coroutine.yield()

		selection.Transparency = 1
		gateway:InvokeServer("ClearKey", dragKey, not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift))
		currentKey = nil
	end
end

local function onButton1Down()
	if not debounce then
		debounce = true
		local mouseObject = selection.Adornee
		if mouseObject and not down then
			startDraggerAction(mouseObject)
		end
		debounce = false
	end
end

local function onButton1Up()
	if down then
		down = false
		Dragger:MouseUp()
	end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Connections
----------------------------------------------------------------------------------------------------------------------------------------------------------------

local connections = {}

local function pushConnections(connectionData)
	for event,func in pairs(connectionData) do
		local connection = event:Connect(func)
		table.insert(connections,connection)
	end
end

local function popConnections()
	while #connections > 0 do
		local connection = table.remove(connections)
		connection:Disconnect()
	end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tool 
----------------------------------------------------------------------------------------------------------------------------------------------------------------

local function onEquipped(newMouse)
	mouse = newMouse
	pushConnections
	{
		[mouse.Button1Down] = onButton1Down;
		[mouse.Button1Up]   = onButton1Up;
		[mouse.Idle]        = onIdle;
	}
end

local function onUnequipped()
	onButton1Up()
	popConnections()
	selection.Adornee = nil
	if mouse then
		mouse.Icon = ""
		mouse = nil
	end
end

tool.Equipped:Connect(onEquipped)
tool.Unequipped:Connect(onUnequipped)

----------------------------------------------------------------------------------------------------------------------------------------------------------------