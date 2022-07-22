local Permissions = {}

-- TODO
function Permissions:CanDrag(userId: number, part: Instance)
	return true
end
function Permissions:CanDelete(userId: number, part: Instance)
	return true
end
function Permissions:CanModify(userId: number, part: Instance)
	return true
end
function Permissions:CanInteract(userId: number, part: Instance)
	return true
end

return Permissions