-- CSLua
AddCSLuaFile("autorun/client/pe_cl.lua")
AddCSLuaFile("weapons/weapon_prop_pickup_enhanced_hands.lua")

-- convar stuff
local isEnabled = CreateConVar("sv_peEnabled", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Enable Prop Pickup Enhanced"):GetBool()
local maxGrabDistance = CreateConVar("sv_peMaxGrabDistance", "75", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "How far players should be able to grab props from"):GetFloat()
local maxWeight = CreateConVar("sv_peMaxWeight", "20", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "The heavier a prop is compared to this, the harder it is to move it"):GetFloat()
local swepOnly = CreateConVar("sv_peSwepOnly", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Should Prop Pickup Enhanced only work with the swep?"):GetBool()

-- callbacks to update values, took way too long to figure this out... i had all of the checking and updating happening in the think loop...
cvars.AddChangeCallback("sv_peEnabled", function() isEnabled = GetConVar("sv_peEnabled"):GetBool() end)
cvars.AddChangeCallback("sv_peMaxGrabDistance", function() maxGrabDistance = GetConVar("sv_peMaxGrabDistance"):GetFloat() end)
cvars.AddChangeCallback("sv_peMaxWeight", function() maxWeight = GetConVar("sv_peMaxWeight"):GetFloat() end)

-- block default prop pickup if the system is enabled
hook.Add("AllowPlayerPickup", "_peBlockPickup", function(ply, ent)
	--if swep is equipped
	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) then return end 
	if swepOnly and wep:GetClass() == "weapon_prop_pickup_enhanced_hands" then return false end 

	--otherwise, check if enabled
	if isEnabled then return false end
end )

local function setHeldEntity(ply, ent)
	ply:SetNWBool("pe_blockGrabbing", nil)
	ply:SetNWEntity("pe_heldEntity", ent) --do this so starfall peeps can access it
	if not IsValid(ent) then return end --if set to nil entity (aka clearing entity)
	
	ent.pe_heldProperties = ent.pe_heldProperties or {}

	local aimPos = ply:GetEyeTrace().HitPos
	local relativePos = ent:WorldToLocal(aimPos)

	local distance = (ply:EyePos()-aimPos):Length()
	ent.pe_heldProperties.physObj = ent:GetPhysicsObject()
	ent.pe_heldProperties.relativePos = ent:WorldToLocal(aimPos)
	ent.pe_heldProperties.distance = distance

	local obb = ent:OBBMaxs()-ent:OBBMins()
	local volume = (obb.x+obb.y+obb.z)/3
	ent.pe_heldProperties.volume = volume
end

-- deny grabbing entities if 
hook.Add("PhysgunPickup", "_peStorePickedUpProp", function(ply, ent)
	if IsValid(ply) then
		ent.pe_blockgrabbing = true
		ply:SetNWBool("pe_blockGrabbing", true) 
		setHeldEntity(ply, nil)
	end
end)

hook.Add("PhysgunDrop", "_peClearPickedUpProp", function(ply, ent)
	if IsValid(ply) then
		ent.pe_blockgrabbing = nil
		ply:SetNWBool("pe_blockGrabbing", nil)
	end
end)

hook.Add("PlayerSwitchWeapon", "_pePlayerSwitchWeapon", function(ply)
	local ent = ply:GetNWEntity("pe_heldEntity")
	if IsValid(ent) then 
		return true
	end
end)

local function CanPlayerGrabProp(ply, ent)
	if not IsValid(ply) or not IsValid(ent) or ent.pe_blockgrabbing then return false end
	
	local allow = hook.Run("PE_CanPickupProp", ply, ent)
	if allow ~= nil then
		return allow
	end
	
	if CPPI then return ent:CPPICanPickup(ply) end
	return true
end

function PE_LookForEntity(ply, drop)
	if drop == true then 
		setHeldEntity(ply, nil)
		return
	end
	
	local tr = util.TraceLine({
		start = ply:EyePos(),
		endpos = ply:EyePos() + ply:GetAimVector()*maxGrabDistance,
		filter = ply
	}) -- limited range eye trace

	if not tr.Hit then return end 
	if not CanPlayerGrabProp(ply, tr.Entity) then return end 
	setHeldEntity(ply, tr.Entity)
end

--find entity to grab
local prevWeapon = {}
hook.Add("PlayerUse", "_pePlayerUse", function(ply, ent)
	if not IsValid(ply) or not IsValid(ent) then return end 
	if not isEnabled then 
		if IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() ~= "weapon_prop_pickup_enhanced_hands" then 
			return 
		end
	end

	if not IsValid(ply:GetNWEntity("pe_heldEntity")) then 
		PE_LookForEntity(ply)
		prevWeapon[ply] = ply:GetActiveWeapon()
		ply:SetActiveWeapon(NULL)
	end
end)

--released entity
hook.Add("KeyRelease", "_peKeyUp", function(ply, key)
	if not IsValid(ply) or not key or not IsFirstTimePredicted() then return end 
	if key == IN_USE or key == IN_ATTACK then 
		setHeldEntity(ply, nil) 
		if prevWeapon[ply] then
			ply:SelectWeapon(prevWeapon[ply])
			prevWeapon[ply] = nil
		end
	end
end)

-- helper function
local function ClampToRange(vector, maxDistance)
	return vector:GetNormalized() * math.min(vector:Length(), maxDistance)
end

-- also helper function, thanks cheezus
local m_in_sq = 1 / 39.37 ^ 2 -- in^2 to m^2
local const = m_in_sq * 360 / (2 * math.pi)
local function ApplyForceOffsetFixed(ent, force, pos)
	if not IsValid(ent) then return end
	ent:ApplyForceCenter(force)

	local off = pos - ent:LocalToWorld(ent:GetMassCenter())
	local angf = off:Cross(force) * const

	ent:ApplyTorqueCenter(angf)
end

--main loop
hook.Add("Think","_peServerMain",function()
	for _, ply in ipairs(player.GetHumans()) do 
		if not IsValid(ply) or not ply:Alive() or ply:GetNWBool("pe_blockGrabbing") then continue end --dead or nil 

		local ent = ply:GetNWEntity("pe_heldEntity")
		if not IsValid(ent) or not ent:GetPhysicsObject():IsMoveable() then continue end --not holding anything, or unmovable object

		--move the shit 
		local properties = ent.pe_heldProperties
		if not properties or table.IsEmpty(properties) then continue end 

		local physObj, relativePos, distance, volume = properties.physObj, properties.relativePos, properties.distance, properties.volume
		if not IsValid(physObj) then continue end
		
		local targetPos = ply:EyePos() + ply:GetAimVector() * distance -- holding position should move towards where you aim + forward by stored distance
		local holdPos = ent:LocalToWorld(relativePos)
		
		local mass = physObj:GetMass()
		local carryForce = 1/(1+math.Clamp((-maxWeight/2+mass+volume*1.5)/250,0,100)) -- some very random math to make sure heavy/large props are harder to carry/move, not perfect by any means
		
		local diff = (targetPos-holdPos)
		local diffClamped = ClampToRange(diff, 300*carryForce)
		local damp = (physObj:GetVelocityAtPoint(holdPos)) * 0.1
		local force = (diffClamped - damp) * (carryForce * carryForce)
		
		if diff:Length() > maxGrabDistance then 
			setHeldEntity(ply, nil); 
			if prevWeapon[ply] then
				ply:SetActiveWeapon(prevWeapon[ply])
				prevWeapon[ply] = nil
			end
			continue 
		end --got too far away
		
		ApplyForceOffsetFixed(physObj, force * mass * FrameTime() * 100, holdPos)
	end
end)
