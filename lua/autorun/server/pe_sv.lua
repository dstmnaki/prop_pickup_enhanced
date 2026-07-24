local blacklist = {}

if file.Exists("pe_blacklist.json", "DATA") then 
	local raw = file.Read("pe_blacklist.json", "DATA")
	for _, class in ipairs(util.JSONToTable(raw)) do 
		blacklist[class] = true
	end
end

-- CSLua
AddCSLuaFile("autorun/client/pe_cl.lua")
AddCSLuaFile("weapons/weapon_prop_pickup_enhanced_hands.lua")

-- helper functions, you can call these from your own addons if you wish to allow a class to be picked up
function peAllowClass(class)
	if blacklist[class] then return end 
	blacklist[class] = true
end

timer.Create("pe_fileSave", 1, 0, function()
	file.Write("pe_blacklist.json", util.TableToJSON(table.GetKeys(blacklist)))
end)

function peCheckBlacklist(class) -- added this just in case you wish to do some checking
	return blacklist[class] == true
end

-- convar stuff
local pickupMode = CreateConVar("sv_peEnabled", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "0/1/2 | Disabled/Enabled/SWEP only"):GetInt()
local isEnabled = pickupMode > 0
local swepOnly = pickupMode == 2
local maxGrabDistance = CreateConVar("sv_peMaxGrabDistance", "75", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "How far players should be able to grab props from"):GetFloat()
local maxWeight = CreateConVar("sv_peMaxWeight", "20", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "The heavier a prop is compared to this, the harder it is to move it"):GetFloat()
local blacklistIsAWhitelist = CreateConVar("sv_peBlacklistIsAWhitelist", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Makes the entity class blacklist a whitelist"):GetBool()

-- callbacks to update values, took way too long to figure this out... i had all of the checking and updating happening in the think loop...
cvars.AddChangeCallback("sv_peEnabled", function()
	pickupMode = GetConVar("sv_peEnabled"):GetInt()
	isEnabled = pickupMode > 0
	swepOnly = pickupMode == 2
end)
cvars.AddChangeCallback("sv_peMaxGrabDistance", function() maxGrabDistance = GetConVar("sv_peMaxGrabDistance"):GetFloat() end)
cvars.AddChangeCallback("sv_peMaxWeight", function() maxWeight = GetConVar("sv_peMaxWeight"):GetFloat() end)

local function setHeldEntity(ply, ent)
	ply:SetNWBool("pe_blockGrabbing", nil)
	ply:SetNWEntity("pe_heldEntity", ent == nil and NULL or ent) --do this so starfall peeps can access it
	ply:SetNWFloat("pe_lastGrabbed", CurTime())
	ply:SetNWBool("pe_holding", IsValid(ent) and true or nil)
	
	if not IsValid(ent) then ply:SetNWBool("pe_grabToggle", false); return end --if set to nil entity (aka clearing entity)

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
	if not IsValid(ply) or
	not IsValid(ent) or
	ent:IsMarkedForDeletion() or
	peAllowedClasses[ent:GetClass()] ~= true or
	ent.pe_blockgrabbing or
	not (IsValid(ent:GetPhysicsObject()) and ent:GetPhysicsObject():IsMoveable()) then
		return false
	end

	if blacklist[class] and not blacklistIsAWhitelist 
	or not blacklist[class] and blacklistIsAWhitelist then 
		return false 
	end
	
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
	local ent = tr.Entity
	if not CanPlayerGrabProp(ply, ent) then return end 
	setHeldEntity(ply, ent)
	return ent
end

--find entity to grab
local prevWeapon = {}
hook.Add("PlayerUse", "_pePlayerUse", function(ply, ent)
	if not IsValid(ply) or not IsValid(ent) or IsValid(ply:GetNWEntity("pe_heldEntity")) then return end 

	local activeWeapon = ply:GetActiveWeapon()
	if not isEnabled or swepOnly then return end
	
	--block +use for the swep
	if IsValid(activeWeapon) and activeWeapon:GetClass() == "weapon_prop_pickup_enhanced_hands" then 
		return 
	end
	
	if not IsValid(ply:GetNWEntity("pe_heldEntity")) then 
		local ent = PE_LookForEntity(ply)
		if not IsValid(ent) then return end
		if IsValid(activeWeapon) and activeWeapon ~= NULL then
			prevWeapon[ply] = activeWeapon:GetClass()
		end
		ply:SetActiveWeapon(NULL)
	end
end)

local function peReturnWeapon(ply)
	local class = prevWeapon[ply]
	if class ~= nil then
		if !ply:GetWeapon(class):IsValid() then
			ply:Give(prevWeaponClass)
		end
		
		ply:SelectWeapon(class)
		prevWeapon[ply] = nil
	end
end

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

local function isHolding(ply)
	if ply:KeyDown(IN_USE) or ply:KeyDown(IN_ATTACK) then 
		if ply:GetInfoNum("pe_grabMode", 0) == 1 and ply:GetNWBool("pe_grabToggle") then ply:SetNWBool("pe_grabToggle", false) end--disable toggle
		return true 
	end 
	
	--no longer pressing +use or +attack
	if ply:GetInfoNum("pe_grabMode", 0) == 1 then 
		if (ply:GetNWFloat("pe_lastGrabbed")+0.2) > CurTime() then --tapped key
			ply:SetNWBool("pe_grabToggle", true) 
		end
	end
	
	if ply:GetNWBool("pe_grabToggle") then return true end
	return false 
end

--main loop
hook.Add("Think","_peServerMain",function()
	for _, ply in ipairs(player.GetHumans()) do 
		if not IsValid(ply) or not ply:Alive() or ply:GetNWBool("pe_blockGrabbing") or not ply:GetNWBool("pe_holding") then continue end --dead or nil 

		local ent = ply:GetNWEntity("pe_heldEntity")
		if not IsValid(ent) or not (IsValid(ent:GetPhysicsObject()) and ent:GetPhysicsObject():IsMoveable()) or ent:IsMarkedForDeletion() or not isHolding(ply) then
			setHeldEntity(ply, nil)
			peReturnWeapon(ply)
			continue
		end --not holding anything, or unmovable object
		
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
			setHeldEntity(ply, nil)
			peReturnWeapon(ply)
			continue 
		end --got too far away
		
		ApplyForceOffsetFixed(physObj, force * mass * FrameTime() * 100, holdPos)
	end
end)
