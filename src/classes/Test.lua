--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Debug = require(ServerScriptService.Debug)
local Part = require(ServerScriptService.Part)

local Test = {}

function Test.Init(self: Part.PartObject)
    Debug.Log(self.ClassName)
end

return Test