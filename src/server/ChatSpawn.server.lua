local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")

local CRAFT_RADIUS = 128

local Object = require(ServerScriptService:WaitForChild("Object"))
local Crafting = require(ServerScriptService:WaitForChild("Crafting"))

local function makeCommand(primaryAlias: string, secondaryAlias: string?, action: (player: Player, ...string) -> ())
	local command = Instance.new("TextChatCommand")
	command.PrimaryAlias = primaryAlias
	if secondaryAlias then
		command.SecondaryAlias = secondaryAlias
	end
	command.Triggered:Connect(function(originTextSource: TextSource, unfilteredText: string)
		local player = assert(Players:GetPlayerByUserId(originTextSource.UserId), string.format("Cannot execute command. No player for UserId: %d", originTextSource.UserId))
		local arguments = string.split(string.gsub(unfilteredText, "%s+", " "), " ")
		action(player, unpack(arguments, 2))
	end)
	command.Parent = TextChatService
end

-- TODO: Cmdr
makeCommand("/spawn", "/s", function(player: Player, objectName: string, _amount: string)
	local amount: number = if _amount then tonumber(_amount) or 1 else 1
	if amount ~= amount then
		amount = 1
	end

	local character = player.Character
	if not character then
		return
	end

	print("Spawn", objectName, amount)
	objectName = Object.fuzzySearch(objectName)
	Crafting:Spawn({
		{
			Resource = objectName;
			Amount = math.clamp(amount, 1, 10);
		}
	}, character:GetPivot() * CFrame.new(0, 0, -5))
end)

makeCommand("/craft", "/c", function(player: Player, recipeName: string, _amount: string)
	local amount: number = if _amount then tonumber(_amount) or 1 else 1
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
end)