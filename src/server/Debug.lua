-- Debug.lua
-- Provides extended debug functionality
-- Weldify 22.07.2022

--!strict

local RunService = game:GetService("RunService")

local isDebug = RunService:IsStudio()

type Log = (...any) -> ()

type Debug = {
    IsDebug: boolean;
    Log: Log;
}

local Debug = {
    IsDebug = isDebug;
}

local function TupleToString(...: any): string
    local str = ""
    for _, v in ipairs({...}) do
        str = str..tostring(v)
    end

    return str
end

if isDebug then
    Debug.Log = function(...: any)
        print(TupleToString(...))
    end
else
    Debug.Log = function() end
end

return table.freeze(Debug) :: Debug