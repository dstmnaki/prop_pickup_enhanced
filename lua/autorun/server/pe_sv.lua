-- CSLua
AddCSLuaFile("autorun/client/pe_cl.lua")
AddCSLuaFile("weapons/weapon_prop_pickup_enhanced_hands.lua")

-- convar stuff
CreateConVar("sv_peEnabled", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Enable Prop Pickup Enhanced")
CreateConVar("sv_peMaxGrabDistance", "75", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "How far players should be able to grab props from")
CreateConVar("sv_peMaxWeight", "20", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "The heavier a prop is compared to this, the harder it is to move it")

-- some functions to return values
local function peIsEnabled()
	return GetConVar( "sv_peEnabled" ) and GetConVar("sv_peEnabled"):GetBool() or false
end
local function peGetGrabDistance()
	return GetConVar( "sv_peMaxGrabDistance" ) and tonumber(GetConVar( "sv_peMaxGrabDistance" ):GetString()) or 75
end
local function peGetMaxWeight()
	return GetConVar( "sv_peMaxWeight" ) and tonumber(GetConVar( "sv_peMaxWeight" ):GetString()) or 20
end

-- predefine variables
local _isEnabled = peIsEnabled()
local _maxGrabDistance = peGetGrabDistance()
local _maxWeight = peGetMaxWeight()

-- callbacks to update values, took way too long to figure this out... i had all of the checking and updating happening in the think loop...
cvars.AddChangeCallback( "sv_peEnabled", function()
	_isEnabled = peIsEnabled()
end, nil)
cvars.AddChangeCallback( "sv_peMaxGrabDistance", function()
	_maxGrabDistance = peGetGrabDistance()
end, nil)
cvars.AddChangeCallback( "sv_peMaxWeight", function()
	_maxWeight = peGetMaxWeight()
end, nil)

-- block default prop pickup if the system is enabled
hook.Add( "AllowPlayerPickup", "_peBlockPickup", function( ply, ent )
	if _isEnabled then return false end
end )

-- store picked up prop to prevent the current player from grabbing a prop while using physics gun on it
hook.Add("PhysgunPickup", "_peStorePickedUpProp", function(ply, ent)
    if IsValid(ply) then
        ply._peHeldPropEntity = ent
    end
end)
hook.Add("PhysgunDrop", "_peClearPickedUpProp", function(ply, ent)
    if IsValid(ply) then
        ply._peHeldPropEntity = nil
    end
end)


-- helper function
local function ClampToRange(vector,maxDistance)
	return vector:Length() > maxDistance and vector:GetNormalized()*maxDistance or vector
end

-- also helper function, thanks cheezus
local m_in_sq = 1 / 39.37 ^ 2 -- in^2 to m^2
local const = m_in_sq * 360 / (2 * 3.1416)
local function ApplyForceOffsetFixed(ent,force,pos)
	if not IsValid(ent) then return end
	ent:ApplyForceCenter(force)

	local off = pos - ent:LocalToWorld(ent:GetMassCenter())
	local angf = off:Cross(force) * const

	ent:ApplyTorqueCenter(angf)
end

local function HolsterActiveWeaponForPickup(ply)
    if not IsValid(ply) or not ply:Alive() then return end
	
    local activeWep = ply:GetActiveWeapon()
    if IsValid(activeWep) and activeWep:GetClass() ~= "weapon_prop_pickup_enhanced_hands" then
        ply._prevWeapon = activeWep:GetClass()
    end
	
    if not ply:HasWeapon("weapon_prop_pickup_enhanced_hands") then
        ply:Give("weapon_prop_pickup_enhanced_hands")
    end
	
    ply:SelectWeapon("weapon_prop_pickup_enhanced_hands")
end

local function RestoreWeaponAfterDrop(ply)
    if not IsValid(ply) or not ply:Alive() then return end
	
    if not ply:HasWeapon("weapon_prop_pickup_enhanced_hands") then return end
    local previousWepClass = ply._prevWeapon
	
    if previousWepClass and ply:HasWeapon(previousWepClass) then
        ply:SelectWeapon(previousWepClass)
    else
        local weapons = ply:GetWeapons()
        if #weapons > 0 then
            ply:SelectWeapon(weapons[1]:GetClass())
        end
    end
	
    timer.Simple(0.1, function()
        if IsValid(ply) and ply:HasWeapon("weapon_prop_pickup_enhanced_hands") then
            ply:StripWeapon("weapon_prop_pickup_enhanced_hands")
        end
    end)
end

local function CanPlayerGrabProp(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then
        return false
    end
	
    local allow = hook.Run("PE_CanPickupProp", ply, ent)

    if allow ~= nil then
        return allow
    end
	
    -- CPPI support
    if ent.CPPICanPhysgun then
        local allowed = ent:CPPICanPhysgun(ply)
        if allowed == false then
            return false
        end
    end

    return true
end

hook.Add("Think","_peServerMain",function()
	if not _isEnabled then return end
	local players = player.GetAll()
	if table.IsEmpty(players) then return end
	for k, ply in pairs(players) do
		if not IsValid(ply) then players[k] = nil continue end -- failsafe in case a player is invalid, remove it from the table and continue to next player
		if not ply:Alive() then continue end -- don't do shit if player is dead
		
		if ply._peHeldPropEntity != nil then continue end
		
		if ply._wasHolding and not ply._holdingProp then
			RestoreWeaponAfterDrop(ply)
			ply._wasHolding = false
		end -- restore weapon if not holding a prop
		
		if not ply:KeyDown(IN_USE) then
			ply._holdingProp = nil
			continue
		end -- if player is not holding +use/E skip to next person, also reset some values
		
		if ply._wasHolding == false or ply._holdingProp == nil or not IsValid(ply._holdingProp._ent) or not IsValid(ply._holdingProp._physObj) then
			-- if player wasn't holding a prop, the holding prop is invalid or table data is invalid run following
			local _tr = util.TraceLine({
				start = ply:EyePos(),
				endpos = ply:EyePos()+ply:GetAimVector()*_maxGrabDistance,
				filter = ply
			}) -- eye trace
			
			local _ent = _tr.Entity
			
			if not IsValid(_ent) then continue end
			local _physObj = _ent:GetPhysicsObject()
			
			if not CanPlayerGrabProp(ply, _ent) then
				continue
			end
			
			if not (IsValid(_physObj) and _physObj:IsMoveable()) then continue end
			-- if entity's physics object is valid and not frozen, run following
			
			local _aimPos = _tr.HitPos
			local _relativePos = _ent:WorldToLocal(_aimPos)
			local _distance = (ply:EyePos()-_aimPos):Length()
			
			local _obb = _ent:OBBMaxs()-_ent:OBBMins()
			local _volume = (_obb.x+_obb.y+_obb.z)/3
			
			ply._wasHolding = true
			
			HolsterActiveWeaponForPickup(ply)
			
			ply._holdingProp = {
				_ent = _ent,
				_physObj = _physObj,
				_relativePos = _relativePos,
				_distance = _distance,
				_volume = _volume
			} -- write prop carry info to player
		else
			-- if player is holding a prop
			local _ent = ply._holdingProp._ent
			if not IsValid(_ent) or _ent:IsMarkedForDeletion() then
				ply._holdingProp = nil
				continue -- if entity becomes invalid somehow, return early to look for next prop
			end
			local _physObj = ply._holdingProp._physObj
			if not IsValid(_physObj) then
				ply._holdingProp = nil
				continue -- also return early if the physics object is invalid
			end
			local _relativePos = ply._holdingProp._relativePos
			local _distance = ply._holdingProp._distance -- stores the distance the prop was at when it was picked up
			
			local _targetPos = ply:EyePos() + ply:GetAimVector() * _distance -- holding position should move towards where you aim + forward by stored distance
			local _holdPos = _ent:LocalToWorld(_relativePos)
			
			local _volume = ply._holdingProp._volume
			
			local _mass = _physObj:GetMass()
			
			local _carryForce = 1/(1+math.Clamp((-_maxWeight/2+_mass+_volume*1.5)/250,0,100)) -- some very random math to make sure heavy/large props are harder to carry/move, not perfect by any means
			
			local _diff = (_targetPos-_holdPos)
			local _diffClamped = ClampToRange(_diff, 300*_carryForce)
			local _damp = (_physObj:GetVelocityAtPoint(_holdPos)) * 0.1
			local _force = (_diffClamped - _damp) * (_carryForce * _carryForce)
			
			if _diff:Length() > _maxGrabDistance * 1.5 then
				ply._holdingProp = nil
				continue -- if the prop goes too far, stop holding
			end
			
			ApplyForceOffsetFixed(_physObj, _force * _mass * FrameTime() * 100, _holdPos)
		end
	end
end)
