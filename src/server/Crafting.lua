--!strict
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Part = require(ServerScriptService:WaitForChild("Part"))
local Permissions = require(ServerScriptService:WaitForChild("Permissions"))

local recipeFolder = ReplicatedStorage:WaitForChild("Recipes")

export type Ingredient = {
	Resource: string;
	Amount: number?;
	Consume: boolean;
	ConsumeChance: number?;
}
export type Result = {
	Resource: string;
	Amount: number?;
	SuccessChance: number?;
} | string
export type Recipe = {
	Results: {Result};
	Ingredients: {Ingredient};
}

local Crafting = {}

local function filterByResource(parts: {Instance}, resourceType: string)
	local partCount = 0
	for _, reference in ipairs(parts) do
		local part = Part.fromReference(reference)
		if part then
			if part.ClassName == resourceType then
				partCount += 1
			end
		end
	end
	
	local filtered = table.create(partCount)
	for _, reference in ipairs(parts) do
		local part = Part.fromReference(reference)
		if part then
			if part.ClassName == resourceType then
				table.insert(filtered, reference)
			end
		end
	end
	return filtered
end

function Crafting:FindResourcesAround(resourceType: string, position: Vector3, radius: number, amount: number, ignoreObjects: {Part.PartObject}?, userId: number?): {Part.PartObject}
	assert(Part.getModel(resourceType), string.format("Invalid part class %s", resourceType))
	
	local resourcePartCount = Part.partCount(resourceType)

	local searchParams = OverlapParams.new()
	searchParams.FilterType = Enum.RaycastFilterType.Whitelist
	searchParams.FilterDescendantsInstances = filterByResource(CollectionService:GetTagged("Object"), resourceType)
	searchParams.MaxParts = amount * resourcePartCount
	
	local partObjects: {Part.PartObject} = table.create(amount)
	local parts = workspace:GetPartBoundsInRadius(position, radius, searchParams)
	for _, part in ipairs(parts) do
		while part and not Part.fromReference(part) do
			part = part.Parent
		end

		if part then
			if userId and not Permissions:CanDelete(userId, part) then
				continue
			end
			
			local partObject = Part.fromReference(part)
			if partObject then
				print("Find", resourceType, partObject)
				
				-- If ignored
				if ignoreObjects and table.find(ignoreObjects, partObject) then
					print("Ignore")
					continue
				end
				-- If already included
				if table.find(partObjects, partObject) then
					print("Skip existing")
					continue
				end
				
				-- Insert part
				table.insert(partObjects, partObject)
				if #partObjects >= amount then
					break
				end
			end
		end
	end
	print(resourceType, amount, #partObjects, partObjects)
	return partObjects
end

function Crafting:Consume(resources: {Part.PartObject})
	for _, resource in ipairs(resources) do
		resource:Destroy()
	end
end

function Crafting.countResults(results: {Result}): number
	local resultCount = 0
	for _, result in ipairs(results) do
		-- Determine resource & amount
		local amount: number
		local resource: string
		if type(result) == "string" then
			resource = result
			amount = 1
		else
			resource = result.Resource
			amount = result.Amount or 1
		end
		resultCount += amount
	end
	return resultCount
end

local craftRandom = Random.new()
function Crafting:Spawn(results: {Result}, cframe: CFrame): {Part.PartObject}
	local resultParts = table.create(Crafting.countResults(results))
	for _, result in ipairs(results) do
		-- Determine resource & amount
		local amount: number
		local resource: string
		local successChance: number
		if type(result) == "string" then
			resource = result
			amount = 1
			successChance = 1
		else
			resource = result.Resource
			amount = result.Amount or 1
			successChance = result.SuccessChance or 1
		end
		
		-- Create result parts
		for i=1, amount do
			if craftRandom:NextNumber() <= successChance then
				table.insert(resultParts, Part.new(resource))
			end
		end
	end

	-- Move parts to workspace
	for _, part in ipairs(resultParts) do
		part:PivotTo(cframe * CFrame.new(0, 0, -5))
		part.Parent = workspace
	end
	
	return resultParts
end

function Crafting:CraftRecipe(cframe: CFrame, recipe: Recipe, radius: number, userId: number?): ({Part.PartObject}?, {Ingredient}?)
	local ingredients = {}
	for _, ingredient in ipairs(recipe.Ingredients) do
		local amount = ingredient.Amount or 1
		local consumeChance = ingredient.ConsumeChance or 1
		
		-- Find resources
		local resources = self:FindResourcesAround(ingredient.Resource, cframe.Position, radius, amount, ingredients, userId)
		if #resources < amount then
			return nil, table.freeze({
				table.freeze({
					Resource = ingredient.Resource;
					Amount = (amount - #resources);
					Consume = ingredient.Consume;
					ConsumeChance = consumeChance;
				} :: Ingredient)
			})
		end
		
		-- Consume ingredients
		if ingredient.Consume then
			local removeCount = 0
			if consumeChance < 1 then
				for i=1, amount do
					if craftRandom:NextNumber() <= consumeChance then
						removeCount += 1
					end
				end
			else
				removeCount = amount
			end
			table.move(resources, 1, removeCount, #ingredients + 1, ingredients)
		end
	end
	
	Crafting:Consume(ingredients)
	return Crafting:Spawn(recipe.Results, cframe)
end

-- TODO
function Crafting:CraftBatch(player: Player, query: {Result}): {Part.PartObject}
	return {}
end

function Crafting.fuzzySearch(query: string): string
	local recipes = recipeFolder:GetDescendants()
	local results = {}
	for _, recipe in ipairs(recipes) do
		if recipe:IsA("ModuleScript") then
			local recipeName = recipe.Name
			local findIndex = string.find(string.lower(recipeName), string.lower(query), 1, true)
			if findIndex then
				table.insert(results, {
					Index = findIndex;
					RecipeName = recipeName;
				})
			end
		end
	end

	table.sort(results, function(a, b)
		return a.Index < b.Index
	end)

	local result = results[1]
	if result then
		return result.RecipeName
	end
	error(string.format("%s is not a valid recipe.", query))
end

function Crafting.getRecipe(recipeName: string): Recipe
	local recipeModule = recipeFolder:FindFirstChild(recipeName, true)
	assert(recipeModule, string.format("%s is not a valid recipe.", recipeName))
	
	local recipe = require(recipeModule) :: Recipe
	table.freeze(recipe.Results)
	table.freeze(recipe.Ingredients)
	return table.freeze(recipe)
end

return Crafting