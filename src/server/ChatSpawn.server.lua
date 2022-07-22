local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local CRAFT_RADIUS = 128

local Part = require(ServerScriptService:WaitForChild("Part"))
local Crafting = require(ServerScriptService:WaitForChild("Crafting"))

-- TODO: Cmdr
local commands = {
	["/s"] = function(player: Player, partName: string, amount: number)
		amount = if amount then tonumber(amount) or 1 else 1
		if amount ~= amount then
			amount = 1
		end
		
		local character = player.Character
		if not character then
			return
		end

		print("Spawn", partName, amount)
		partName = Part.fuzzySearch(partName)
		Crafting:Spawn({
			{
				Resource = partName;
				Amount = math.clamp(amount, 1, 10);
			}
		}, character:GetPivot() * CFrame.new(0, 0, -5))
	end;
	["/c"] = function(player: Player, recipeName: string, amount: number)
		amount = if amount then tonumber(amount) or 1 else 1
		if amount ~= amount then
			amount = 1
		end
		
		local character = player.Character
		if not character then
			return
		end
		local cframe = character:GetPivot()

		print("Craft", recipeName, amount)
		local recipe = Crafting.getRecipe(Crafting.fuzzySearch(recipeName))
		local cost = #recipe.Ingredients
		if cost == 0 then
			amount = math.clamp(amount, 1, 10)
		end
		
		local resultCount = 0
		while resultCount < amount do
			local results = assert(Crafting:CraftRecipe(cframe, recipe, CRAFT_RADIUS, player.UserId), "Not enough resources to craft.")
			resultCount += #results
		end
	end;
}

local function playerAdded(player)
	player.Chatted:Connect(function(message)
		for command, action in pairs(commands) do
			local arguments = string.split(string.gsub(message, "%s+", " "), " ")
			if arguments[1] == command then
				action(player, unpack(arguments, 2))
			end
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(playerAdded, player)
end
Players.PlayerAdded:Connect(playerAdded)