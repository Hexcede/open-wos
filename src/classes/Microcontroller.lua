--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Object = require(ServerScriptService:FindFirstChild("Object"))
local UserObject = require(ServerScriptService:WaitForChild("UserObject"))

local H6x = require(Packages:WaitForChild("H6x"))

local RUN_DELAY = 0.5 -- How frequently the microcontroller can be re-ran
local MS_TIMEOUT = 20 -- How many milliseconds the sandbox may execute for

-- User class
local UMicrocontroller = {}

function UMicrocontroller.Execute(self: Object.Object, userObject: UserObject.UserObject)
	local runningSandbox = self.State.Sandbox
	if runningSandbox then
		-- Kill any old instance of the sandbox
		runningSandbox:Terminate()
	end
	
	local sandbox = H6x.Sandbox.new()
	self.State.Sandbox = sandbox
	
	-- Replace all objects with UserObjects by this controller's context
	sandbox:AddRule({
		Rule = "Inject";
		Mode = "ByTypeOf";
		Target = "userdata";
		Callback = function(target): any
			if Object.isPart(target) then
				return UserObject.new(userObject.ContextId, target :: any)
			end
			return target
		end
	})
	sandbox:SetScript(userObject)
	
	-- Execute the code
	local code = self:GetConfig("Code")
	if code then
		sandbox:SetTimeout(MS_TIMEOUT / 1000)
		return sandbox:ExecuteString(code)
	end
end

-- Main class
local Microcontroller = {
	UserClass = UMicrocontroller
}

function Microcontroller.Init(self: Object.Object)
	local userObject: UserObject.UserObject = UserObject.new(0, self)
	
	local part = self:GetReference()
	
	local function executeCode()
		if part:IsDescendantOf(workspace) then
			-- Do not allow the microcontroller to be re-ran too frequently
			if not self.State.RunTime or (os.clock() - self.State.RunTime) > RUN_DELAY then
				-- After spawning in the world
				task.defer(function()
					self.State.RunTime = os.clock()
					userObject:Execute()
				end)
			end
		end
	end
	
	self:GetConfigChangedSignal("Code"):Connect(executeCode)
	
	-- Defer until after creation
	task.defer(function()
		executeCode()
		part.AncestryChanged:Connect(executeCode)
	end)
end

return Microcontroller