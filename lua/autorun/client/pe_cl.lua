CreateClientConVar("pe_grabmode", "0", true, true, "0 = hold, 1 = tap to toggle", 0, 1)

hook.Add("HUDShouldDraw", "_peHideWeaponWheel", function(element)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
	
    local ent = ply:GetNWEntity("pe_heldEntity")
	if IsValid(ent) and element == "CHudWeaponSelection" then
		return false
	end
end) -- prevent weapon selection entirely when holding a prop


hook.Add("PopulateToolMenu", "_peAdminMenuSettings", function()
	spawnmenu.AddToolMenuOption("Utilities", "Admin", "CustomPickupAdminSettings", "Prop Pickup Enhanced", "", "", function(panel)
		panel:ClearControls()
		
		panel:NumSlider("Grab Mode", "pe_grabMode", 0, 2, 0)

		if not LocalPlayer():IsAdmin() then return end --don't display for non-admins

		panel:Help("Server settings for the prop pickup system. Pickup modes are Disabled/Enabled/SWEP only")
		
		panel:NumSlider("Pickup Mode", "sv_peEnabled", 0, 2, 0)
		panel:NumSlider("Max Grab Distance", "sv_peMaxGrabDistance", 50, 100, 0)
		panel:NumSlider("Max Carry Weight", "sv_peMaxWeight", 10, 50, 0)
	end)
end)