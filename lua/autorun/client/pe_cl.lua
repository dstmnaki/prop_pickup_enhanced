hook.Add("HUDWeaponPickedUp", "_peHidePickupNotification", function(weapon)
    if IsValid(weapon) and weapon:GetClass() == "weapon_prop_pickup_enhanced_hands" then
        return false
    end
end) -- hide the weapon pickup notification when holding a prop

hook.Add("HUDShouldDraw", "_peHideWeaponWheel", function(element)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
	
    local wep = ply:GetActiveWeapon()
    if IsValid(wep) and wep:GetClass() == "weapon_prop_pickup_enhanced_hands" and element == "CHudWeaponSelection" then
        return false
    end
end) -- prevent weapon selection entirely when holding a prop

hook.Add("PopulateToolMenu", "_peAdminMenuSettings", function()
    spawnmenu.AddToolMenuOption("Utilities", "Admin", "CustomPickupAdminSettings", "Prop Pickup Enhanced", "", "", function(panel)
        panel:ClearControls()
		
        panel:Help("Server settings for the prop pickup system.")
		
        panel:CheckBox("Enable Pickup System", "sv_peEnabled")
        panel:NumSlider("Max Grab Distance", "sv_peMaxGrabDistance", 50, 100, 0)
        panel:NumSlider("Max Carry Weight", "sv_peMaxWeight", 10, 50, 0)
    end)
end)