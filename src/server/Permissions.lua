local Permissions = {}

-- TODO
function Permissions:CanDrag(userId: number, worldObject: Instance)
	return true
end
function Permissions:CanDelete(userId: number, worldObject: Instance)
	return true
end
function Permissions:CanModify(userId: number, worldObject: Instance)
	return true
end
function Permissions:CanInteract(userId: number, worldObject: Instance)
	return true
end

return table.freeze(Permissions)