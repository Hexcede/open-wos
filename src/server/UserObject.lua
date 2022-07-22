--!strict
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Part = require(ServerScriptService:WaitForChild("Part"))

local DIRECT_GET_ALLOW_LIST = {
	ClassName = true;
	GetConfig = true;
	SetConfig = true;
	GetRecipe = true;
	GetConfigChangedSignal = true;
}

-- Types
export type UserObject = {
	ClassName: string; -- ClassName of the underlying part
	ContextId: number; -- UserId of the player who created this object
	[string]: any;
}
export type PlayerContext = {
	UserId: number;
	PartsToUserObjects: {[Part.PartObject]: UserObject};
	UserObjectsToPart: {[UserObject]: Part.PartObject}
}

local UserObject = {}

local playerContexts: {[number]: PlayerContext} = {}
local contextsByUserObject: {[UserObject]: PlayerContext} = {}
setmetatable(contextsByUserObject, {__mode="k"})

function UserObject.getContext(contextOwner: Player | number)
	local userId = if typeof(contextOwner) == "Instance" then contextOwner.UserId else contextOwner
	local context = playerContexts[userId]
	if not context then
		context = {
			UserId = userId;
			PartsToUserObjects = {};
			UserObjectsToPart = {};
		}
		assert(context)
		setmetatable(context.PartsToUserObjects, {__mode="kv"})
		setmetatable(context.UserObjectsToPart, {__mode="kv"})
		playerContexts[userId] = context
	end
	return context
end

local function getContextFromUserObject(userObject: UserObject): PlayerContext
	return assert(contextsByUserObject[userObject], "Invalid UserObject.")
end
UserObject.getContextFromUserObject = getContextFromUserObject;

local function getPartFromUserObject(userObject: UserObject): Part.PartObject
	local userObjectsToPart = getContextFromUserObject(userObject).UserObjectsToPart
	return assert(userObjectsToPart[userObject], "Invalid UserObject.")
end
UserObject.getPartFromUserObject = getPartFromUserObject;

function UserObject.new(contextOwner: Player | number, part: Part.PartObject): UserObject
	local context = UserObject.getContext(contextOwner)
	
	local userObject = context.PartsToUserObjects[part]
	if not userObject then
		userObject = newproxy(true)
		assert(userObject)
		
		local metatable = getmetatable(userObject)
		
		contextsByUserObject[userObject] = context
		context.PartsToUserObjects[part] = userObject
		context.UserObjectsToPart[userObject] = part

		metatable.__index = function(self: UserObject, index: string)
			local value: any
			assert(type(index) == "string", string.format("Attempt to index Part object with %s.", type(index)))
			
			-- Pick value (Mimicking a switch block)
			repeat
				if index == "ContextId" then
					return getContextFromUserObject(self).UserId
				end
				
				local part = getPartFromUserObject(self)
				local class = part.Class
				local userClass = class and class.UserClass
				
				-- Only indices that do not begin with __ are allowed
				if not string.find(index, "^__") then
					-- UserClass index
					if userClass then
						local getter = userClass[string.format("__get_%s", index)]
						if getter then
							value = getter(part, index)
						end

						if rawequal(value, nil) then
							value = userClass[index]
						end
						
						if not rawequal(value, nil) then
							-- Wrap functions (user class)
							if type(value) == "function" then
								-- Inject user method arguments
								local method = value
								value = function(methodSelf, ...)
									return method(methodSelf, self, ...)
								end
							end
							break
						end
					end
					
					-- Direct access to part fields & methods
					if DIRECT_GET_ALLOW_LIST[index] then
						value = part[index]
						if not rawequal(value, nil) then
							break
						end
					end
				end
			until true
			
			-- If a value exists, we may need to wrap it
			if not rawequal(value, nil) then
				-- Wrap functions
				if type(value) == "function" then
					-- Replace method self with real part instead of UserObject
					local method = value
					value = function(methodSelf, ...)
						if rawequal(methodSelf, self) then
							methodSelf = part
						end
						return method(methodSelf, ...)
					end
				end
			end
			return value
			--error(string.format("%s is not a valid member of Part.", index))
		end
		metatable.__newindex = function(self: UserObject, index: string, value: any)
			assert(type(index) == "string", string.format("Attempt to index Part object with %s.", type(index)))
			
			local part = getPartFromUserObject(self)
			local class = part.Class
			local userClass = class and class.UserClass

			-- Only indices that do not begin with __ are allowed
			if not string.find(index, "^__") then
				-- User class setters
				if userClass then
					local setter = userClass[string.format("__set_%s", index)]
					if setter then
						setter(part, self, index, value)
						return
					end
				end
			end
			error(string.format("%s is not a valid member of Part.", index))
		end
		metatable.__tostring = function(self)
			return string.format("%s<%d>", self.ClassName, self.ContextId)
		end
		metatable.__metatable = "The metatable is locked."
		table.freeze(metatable)
	end
	return userObject
end

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	local context = playerContexts[userId]
	if context then
		local partsToUserObjects = context.PartsToUserObjects
		playerContexts[userId] = nil
	end
end)

return table.freeze(UserObject)