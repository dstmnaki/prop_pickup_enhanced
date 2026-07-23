-- template swep, except it has no visible model, animations or functionality

SWEP.PrintName          	= "Fancy Hands"
SWEP.Author             	= "Nakkitsunami"
SWEP.Instructions       	= "You should not see me..."
SWEP.Spawnable          	= true
SWEP.Slot					= 1

SWEP.ViewModel          	= "models/effects/introtear.mdl"
SWEP.WorldModel          	= ""

SWEP.Primary.ClipSize       = -1
SWEP.Primary.DefaultClip    = -1
SWEP.Primary.Automatic      = false
SWEP.Primary.Ammo           = "none"

SWEP.Secondary.ClipSize     = -1
SWEP.Secondary.DefaultClip  = -1
SWEP.Secondary.Automatic    = false
SWEP.Secondary.Ammo         = "none"

function SWEP:Initialize()
	self:SetHoldType("normal")
end

function SWEP:PrimaryAttack() 
	if CLIENT then return end 
	local ply = self:GetOwner()
	
	local drop = IsValid(ply:GetNWEntity("pe_heldEntity")) --drop holding entity
	PE_LookForEntity(self:GetOwner(), drop)
end
function SWEP:SecondaryAttack() end