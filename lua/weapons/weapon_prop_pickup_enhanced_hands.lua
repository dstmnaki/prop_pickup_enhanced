-- template swep, except it has no visible model, animations or functionality

SWEP.PrintName          = "Fancy Hands"
SWEP.Author             = "Nakkitsunami"
SWEP.Instructions       = "You should not see me..."
SWEP.Spawnable          = false
SWEP.AdminOnly          = false

SWEP.ViewModel          = "models/effects/introtear.mdl"
SWEP.WorldModel          = ""

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
function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end

function SWEP:Deploy()
    local owner = self:GetOwner()
    if IsValid(owner) then
        local vm = owner:GetViewModel()
        if IsValid(vm) then
			vm:SetNoDraw(true)
		end
    end
    return true
end

function SWEP:Holster()
    local owner = self:GetOwner()
    if IsValid(owner) then
        local vm = owner:GetViewModel()
        if IsValid(vm) then vm:SetNoDraw(false) end
    end
    return true
end