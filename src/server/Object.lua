--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local objectFolder = ReplicatedStorage:WaitForChild("Objects")
local classFolder = ReplicatedStorage:WaitForChild("Classes")

local byInstance: {[Instance]: Object} = {}
local toInstance: {[Object]: Instance} = {}

-- Object class
local Object = {}

export type Object = {
	ClassName: string;
	Class: { [any]: any };
	[any]: any;
}

function Object:GetReference(): Instance
	return assert(toInstance[self], "Attempt to retrieve a destroyed object.")
end

function Object.from(reference: Instance): Object?
	return byInstance[reference]
end

function Object.fuzzySearch(query: string): string
	assert(typeof(query) == "string", string.format("Argument #1 to Object.fuzzySearch must be a string. Got '%s' instead", typeof(query)))

	local objects = objectFolder:GetChildren()
	local results = {}
	for _, object in ipairs(objects) do
		local objectName = object.Name
		local findIndex = string.find(string.lower(objectName), string.lower(query), 1, true)
		if findIndex then
			table.insert(results, {
				Index = findIndex;
				ObjectName = objectName;
			})
		end
	end

	table.sort(results, function(a, b)
		return a.Index < b.Index
	end)

	local result = results[1]
	if result then
		return result.ObjectName
	end
	error(string.format("%s is not a valid object.", query))
end

function Object.findClass(objectName: string)
	local class = classFolder:FindFirstChild(objectName, true)
	if class and class:IsA("ModuleScript") then
		return require(class)
	end
	return nil
end

function Object.isObject(object: Object | any): boolean
	return if toInstance[object] then true else false
end

function Object.countParts(objectName: string): number
	local target = objectFolder:FindFirstChild(objectName)
	assert(target, string.format("%s is not a valid object.", objectName))

	local partCount = target:IsA("BasePart") and 1 or 0
	for _, descendant in ipairs(target:GetDescendants()) do
		if descendant:IsA("BasePart") then
			partCount += 1
		end
	end
	return partCount
end

function Object.getModel(objectName: string): PVInstance
	return assert(objectFolder:FindFirstChild(objectName), string.format("%s is not a valid object.", objectName))
end

function Object.new(objectName: string): Object
	local target = Object.getModel(objectName)
	local reference = target:Clone()

	-- Find class & create proxy
	local Class = Object.findClass(objectName)
	local object = Class.new()

	-- Update ClassName & Class fields
	object.ClassName = objectName
	object.Class = Class

	-- Freeze the object
	table.freeze(object)

	-- Map object & metadata to world object and vice versa
	byInstance[reference] = object
	toInstance[object] = reference

	-- When the physical world object is destroyed, clean up data
	reference.Destroying:Connect(function()
		byInstance[reference] = nil
		toInstance[object] = nil
	end)

	CollectionService:AddTag(reference, "Object")
	return object
end

return table.freeze(Object)