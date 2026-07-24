```
Really simple amnesia/repo style prop pickup that replaces the default +USE/E pickup system

Assuming i didn't screw things up, this also allows multiple people carry the same prop in multiplayer

Simply look at a prop, be close enough and hold E, now move your mouse
If you have a prop protection addon, this *should* support CPPI system
Permissions are behind CPPICanPickup, so anyone you have given +USE perms should be able to move your props

SWEP controls:
Mouse 1 (Hold) - Grab onto a prop

The swep can be found in "Other" category

More settings in Utilities -> User -> Prop Pickup Enhanced

Client Convars:
pe_grabMode 0/1					--- Change grab mode. 0 = press and hold, 1 = press and hold / tap to toggle

Convars:
sv_peEnabled 0/1/2              --- Prop Pickup Mode Disabled/Enabled/SWEP only (Default 1)
sv_peMaxGrabDistance 50-100     --- How far players should be able to grab props from (Default 75)
sv_peMaxWeight 10-50            --- The heavier a prop is compared to this, the harder it is to move it (Default 20)
sv_peBlacklistIsAWhitelist 0/1  --- Changes the blacklist to a whitelist

Feel free to fork this and make edits


For developers:

Functions:
peBlacklistClass(class)			--- Adds the entity class to the blacklist

peCheckBlacklist(class)        	--- Returns true if class is allowed, even if not defined to be allowed/disallowed prior (if the class does not return true, returns false)

PE_LookForEntity(ply, drop)    	--- Tries to grab a prop a player is looking at, if drop set to true, clears the entity

NW variables
"pe_heldEntity" 				- Returns the prop a player is holding
"pe_blockGrabbing" 				- If the player is currently blocked from grabbing anything (i.e player is holding something with the physgun)
"pe_lastGrabbed"				- Returns when the last time the player grabbed something
"pe_holding"					- If the player is currently holding anything
```

[Mini showcase on youtube](https://www.youtube.com/watch?v=SVSmuC1lYFo)

[Garry's Mod Workshop Version](https://steamcommunity.com/sharedfiles/filedetails/?id=3769668689) | Status: Up to Date
