--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local partFolder = ReplicatedStorage:WaitForChild("Parts")
local classFolder = ReplicatedStorage:WaitForChild("Classes")

local byInstance: {[Instance]: Object} = {}
local toInstance: {[Object]: Instance} = {}
local toPublicFields: {[Object]: Object} = {}

setmetatable(toInstance, table.freeze({__mode="k"}))
setmetatable(toPublicFields, table.freeze({__mode="k"}))

-- Types
export type Object = {
	ClassName: string;
	Class: {[string]: any}?;
	[string]: any;
}

-- Private class
local Object = {
	__metatable = "The metatable is locked.";
}

function Object:GetPublicFields()
	return assert(toPublicFields[self], "Attempt to access a destroyed object.")
end
function Object:GetReference(): Instance
	return assert(toInstance[self], "Attempt to access a destroyed object.")
end

function Object:Clone()
	-- TODO: Clone
end

local configKeyFormat = "CFG_%s"

function Object:GetConfig(configIndex: string)
	local reference = self:GetReference()
	assert(type(configIndex) == "string", "Config index must be a string.")
	return reference:GetAttribute(string.format(configKeyFormat, configIndex))
end
function Object:SetConfig(configIndex: string, configValue: any)
	local reference = self:GetReference()
	assert(type(configIndex) == "string", "Config index must be a string.")
	reference:SetAttribute(string.format(configKeyFormat, configIndex), configValue)
end
function Object:GetConfigChangedSignal(configIndex: string)
	local reference = self:GetReference()
	assert(type(configIndex) == "string", "Config index must be a string.")
	return reference:GetAttributeChangedSignal(string.format(configKeyFormat, configIndex))
end

function Object:__invalidIndex(index: any)
	error(string.format("Property %s is not a valid member of %s.", tostring(index), self.ClassName), 0)
end
function Object:__index(index: string)
	local value: any
	assert(type(index) == "string", string.format("Attempt to index Part object with %s.", type(index)))

	local publicFields = Object.GetPublicFields(self)
	
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
		value = Object[index]
		if not rawequal(value, nil) then
			return value
		end
	end
	
	-- Check against public part metadata
	value = publicFields[index]
	if not rawequal(value, nil) then
		return value
	end

	local reference = Object.GetReference(self) :: any

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
function Object:__newindex(index: any, value: any)
	local reference = self:GetReference()
	reference[index] = value
end

function Object.__eq(a, b)
	return rawequal(a, b)
end
function Object:__tostring()
	return string.format("%s<X>", self.ClassName)
end

function Object.fromReference(reference: Instance): Object?
	return byInstance[reference]
end

function Object.fuzzySearch(query: string): string
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

function Object.findClass(partName: string)
	local class = classFolder:FindFirstChild(partName, true)
	if class and class:IsA("ModuleScript") then
		return require(class)
	end
	return nil
end

function Object.isPart(part: Object | any): boolean
	if toInstance[part] then
		return true
	end
	return false
end

function Object.partCount(partName: string): number
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

function Object.getModel(partName: string): PVInstance
	return assert(partFolder:FindFirstChild(partName), string.format("%s is not a valid part.", partName))
end

function Object.new(partName: string): Object
	local target = Object.getModel(partName)
	local reference = target:Clone()
	
	-- Find class
	local Class = Object.findClass(partName)
	
	-- Create public metadata
	local publicFields = {
		ClassName = partName;
		Class = Class;
		State = {};
	}
	
	-- Create proxy
	local part = newproxy(true) :: Object
	local partMetatable = getmetatable(part :: any)
	
	-- Copy metatable
	for index, value in pairs(Object) do
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

return table.freeze(Object)