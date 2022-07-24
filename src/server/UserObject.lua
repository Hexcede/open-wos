--!strict
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Object = require(ServerScriptService:WaitForChild("Object"))

local DIRECT_GET_ALLOW_LIST = {
	ClassName = true;
	GetConfig = true;
	SetConfig = true;
	GetRecipe = true;
	GetConfigChangedSignal = true;
}

-- Types
export type UserObject = {
	ClassName: string; -- ClassName of the underlying object
	ContextId: number; -- UserId of the player who created this object
	[string]: any;
}
export type PlayerContext = {
	UserId: number;
	ObjectsToUserObjects: {[Object.Object]: UserObject};
	UserObjectsToObject: {[UserObject]: Object.Object}
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
			ObjectsToUserObjects = {};
			UserObjectsToObject = {};
		}
		assert(context)
		setmetatable(context.ObjectsToUserObjects, {__mode="kv"})
		setmetatable(context.UserObjectsToObject, {__mode="kv"})
		playerContexts[userId] = context
	end
	return context
end

local function getContextFromUserObject(userObject: UserObject): PlayerContext
	return assert(contextsByUserObject[userObject], "Invalid UserObject.")
end
UserObject.getContextFromUserObject = getContextFromUserObject;

local function getObjectFromUserObject(userObject: UserObject): Object.Object
	local userObjectsToObject = getContextFromUserObject(userObject).UserObjectsToObject
	return assert(userObjectsToObject[userObject], "Invalid UserObject.")
end
UserObject.getObjectFromUserObject = getObjectFromUserObject;

function UserObject.new(contextOwner: Player | number, object: Object.Object): UserObject
	local context = UserObject.getContext(contextOwner)
	
	local userObject = context.ObjectsToUserObjects[object]
	if not userObject then
		userObject = newproxy(true)
		assert(userObject)
		
		local metatable = getmetatable(userObject)
		
		contextsByUserObject[userObject] = context
		context.ObjectsToUserObjects[object] = userObject
		context.UserObjectsToObject[userObject] = object

		metatable.__index = function(self: UserObject, index: string)
			local value: any
			assert(type(index) == "string", string.format("%s is not a valid member of Object.", type(index)))
			
			-- Pick value (Mimicking a switch block)
			repeat
				if index == "ContextId" then
					return getContextFromUserObject(self).UserId
				end
				
				local object = getObjectFromUserObject(self)
				local class = object.Class
				local userClass = class and class.UserClass
				
				-- Only indices that do not begin with __ are allowed
				if not string.find(index, "^__") then
					-- UserClass index
					if userClass then
						local getter = userClass[string.format("__get_%s", index)]
						if getter then
							value = getter(object, index)
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
					
					-- Direct access to object fields & methods
					if DIRECT_GET_ALLOW_LIST[index] then
						value = object[index]
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
					-- Replace method self with real object instead of UserObject
					local method = value
					value = function(methodSelf, ...)
						if rawequal(methodSelf, self) then
							methodSelf = object
						end
						return method(methodSelf, ...)
					end
				end
			end
			return value
			--error(string.format("%s is not a valid member of Object.", index))
		end
		metatable.__newindex = function(self: UserObject, index: string, value: any)
			assert(type(index) == "string", string.format("%s is not a valid member of Object.", type(index)))
			
			local object = getObjectFromUserObject(self)
			local class = object.Class
			local userClass = class and class.UserClass

			-- Only indices that do not begin with __ are allowed
			if not string.find(index, "^__") then
				-- User class setters
				if userClass then
					local setter = userClass[string.format("__set_%s", index)]
					if setter then
						setter(object, self, index, value)
						return
					end
				end
			end
			error(string.format("%s is not a valid member of Object.", index))
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
		local objectsToUserObjects = context.ObjectsToUserObjects
		playerContexts[userId] = nil
	end
end)

return table.freeze(UserObject)