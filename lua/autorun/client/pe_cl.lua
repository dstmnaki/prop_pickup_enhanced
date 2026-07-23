hook.Add("PopulateToolMenu", "_peAdminMenuSettings", function()
	spawnmenu.AddToolMenuOption("Utilities", "Admin", "CustomPickupAdminSettings", "Prop Pickup Enhanced", "", "", function(panel)
		panel:ClearControls()
		
		panel:Help("Server settings for the prop pickup system.")
		
		panel:CheckBox("Enable Pickup System", "sv_peEnabled")
		panel:NumSlider("Max Grab Distance", "sv_peMaxGrabDistance", 50, 100, 0)
		panel:NumSlider("Max Carry Weight", "sv_peMaxWeight", 10, 50, 0)
	end)
end)