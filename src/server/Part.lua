--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local partFolder = ReplicatedStorage:WaitForChild("Parts")
local classFolder = ReplicatedStorage:WaitForChild("Classes")

local byInstance: {[Instance]: PartObject} = {}
local toInstance: {[PartObject]: Instance} = {}
local toPublicFields: {[PartObject]: PartObject} = {}

setmetatable(toInstance, table.freeze({__mode="k"}))
setmetatable(toPublicFields, table.freeze({__mode="k"}))

-- Types
export type PartObject = {
	ClassName: string;
	Class: {[string]: any}?;
	[string]: any;
}

-- Private class
local Part = {
	__metatable = "The metatable is locked.";
}

function Part:GetPublicFields()
	return assert(toPublicFields[self], "Attempt to access a destroyed object.")
end
function Part:GetReference(): Instance
	return assert(toInstance[self], "Attempt to access a destroyed object.")
end
function Part:GetRecipe()
	return nil
end

function Part:Clone()
	-- TODO: Clone
end

local configKeyFormat = "CFG_%s"

function Part:GetConfig(configIndex: string)
	local reference = self:GetReference()
	assert(type(configIndex) == "string", "Config index must be a string.")
	return reference:GetAttribute(string.format(configKeyFormat, configIndex))
end
function Part:SetConfig(configIndex: string, configValue: any)
	local reference = self:GetReference()
	assert(type(configIndex) == "string", "Config index must be a string.")
	reference:SetAttribute(string.format(configKeyFormat, configIndex), configValue)
end
function Part:GetConfigChangedSignal(configIndex: string)
	local reference = self:GetReference()
	assert(type(configIndex) == "string", "Config index must be a string.")
	return reference:GetAttributeChangedSignal(string.format(configKeyFormat, configIndex))
end

function Part:__invalidIndex(index: any)
	error(string.format("Property %s is not a valid member of %s.", tostring(index), self.ClassName), 0)
end
function Part:__index(index: string)
	local value: any
	assert(type(index) == "string", string.format("Attempt to index Part object with %s.", type(index)))

	local publicFields = Part.GetPublicFields(self)
	
	-- Check against subclass
	local class = publicFields.Class
	if class then
		value = class[index]
		if not rawequal(value, nil) then
			return value
		end
	end

	-- Check against methods
	if not string.find(index, "^__") then
		value = Part[index]
		if not rawequal(value, nil) then
			return value
		end
	end
	
	-- Check against public part metadata
	value = publicFields[index]
	if not rawequal(value, nil) then
		return value
	end

	local reference = Part.GetReference(self) :: any

	-- Check against part properties
	value = reference[index]
	if not rawequal(value, nil) then
		if type(value) == "function" then
			return function(_, ...)
				return value(reference, ...)
			end
		end
		return value
	end
	return nil
end
function Part:__newindex(index: any, value: any)
	local reference = self:GetReference()
	reference[index] = value
end

function Part.__eq(a, b)
	return rawequal(a, b)
end;
function Part:__tostring()
	return string.format("%s<X>", self.ClassName)
end

function Part.fromReference(reference: Instance): PartObject?
	return byInstance[reference]
end

function Part.fuzzySearch(query: string): string
	local parts = partFolder:GetChildren()
	local results = {}
	for _, part in ipairs(parts) do
		local partName = part.Name
		local findIndex = string.find(string.lower(partName), string.lower(query), 1, true)
		if findIndex then
			table.insert(results, {
				Index = findIndex;
				PartName = partName;
			})
		end
	end
	
	table.sort(results, function(a, b)
		return a.Index < b.Index
	end)
	
	local result = results[1]
	if result then
		return result.PartName
	end
	error(string.format("%s is not a valid part.", query))
end

function Part.findClass(partName: string)
	local class = classFolder:FindFirstChild(partName, true)
	if class and class:IsA("ModuleScript") then
		return require(class)
	end
	return nil
end

function Part.isPart(part: PartObject | any): boolean
	if toInstance[part] then
		return true
	end
	return false
end

function Part.partCount(partName: string): number
	local target = partFolder:FindFirstChild(partName)
	assert(target, string.format("%s is not a valid part.", partName))
	
	local partCount = target:IsA("BasePart") and 1 or 0
	for _, descendant in ipairs(target:GetDescendants()) do
		if descendant:IsA("BasePart") then
			partCount += 1
		end
	end
	return partCount
end

function Part.getModel(partName: string): PVInstance
	return assert(partFolder:FindFirstChild(partName), string.format("%s is not a valid part.", partName))
end

function Part.new(partName: string): PartObject
	local target = Part.getModel(partName)
	local reference = target:Clone()
	
	-- Find class
	local Class = Part.findClass(partName)
	
	-- Create public metadata
	local publicFields = {
		ClassName = partName;
		Class = Class;
		State = {};
	}
	
	-- Create proxy
	local part = newproxy(true) :: PartObject
	local partMetatable = getmetatable(part :: any)
	
	-- Copy metatable
	for index, value in pairs(Part) do
		partMetatable[index] = value
	end
	
	-- Map object & metadata to part and vice versa
	byInstance[reference] = part
	toInstance[part] = reference
	toPublicFields[part] = publicFields
	
	-- When the physical part is destroyed, clean up data
	reference.Destroying:Connect(function()
		byInstance[reference] = nil
		toInstance[part] = nil
		toPublicFields[part] = nil
	end)
	
	CollectionService:AddTag(reference, "Object")
	
	if Class and Class.Init then
		Class.Init(part)
	end

	return part
end

return table.freeze(Part)