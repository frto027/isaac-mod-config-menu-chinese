--this script handles saving for the standalone version of mod config menu

--create the mod
local mod = RegisterMod("Mod Config Menu Standalone", 1)


ModConfigMenu = ModConfigMenu or {}
ModConfigMenu.StandaloneMod = mod
ModConfigMenu.PureMode = false

local preload_data = mod:LoadData()
if preload_data and #preload_data > 0 then
	local json = require("json")
	preload_data = json.decode(preload_data)["ModConfigSave"]
	if preload_data and #preload_data > 0 then
		preload_data = json.decode(preload_data)
		preload_data = preload_data and preload_data["Mod Config Menu"]
		preload_data = preload_data and preload_data["PureMode"]
		ModConfigMenu.PureMode = preload_data and {} -- save every thing to ModConfigMenu.PureMode, please don't touch it
	end
end

if not ModConfigMenu.PureMode then
	--load filepath helper
	require("scripts.filepathhelper")

	--load some scripts
	require("scripts.customcallbacks")

	require("scripts.savehelper")

end


local CustomCallbackHelper = CustomCallbackHelper or require("scripts.customcallbacks")
local SaveHelper = SaveHelper or require("scripts.savehelper")
CustomCallbackHelper.ExtendMod(mod)
--add MCM's save to savehelper
SaveHelper.AddMod(mod)
SaveHelper.DefaultGameSave(mod, {
	ModConfigSave = false
})

--load mod config menu

--we load it like this instead of using dofile because the game caches the require function
require("scripts.modconfig")

--get and apply the mcm save when savehelper saves and loads data
mod:AddCustomCallback(CustomCallbacks.SH_PRE_MOD_SAVE, function(_, modRef, saveData)

	local mcmSave = ModConfigMenu.GetSave()
	saveData.ModConfigSave = mcmSave
	
end, mod.Name)

mod:AddCustomCallback(CustomCallbacks.SH_POST_MOD_LOAD, function(_, modRef, saveData)

	local mcmSave = ModConfigMenu.LoadSave(saveData.ModConfigSave)
	
end, mod.Name)


if not ModConfigMenu.StandaloneSaveLoaded then
	SaveHelper.Load(ModConfigMenu.StandaloneMod)
	ModConfigMenu.StandaloneSaveLoaded = true
end

if not (ModConfigMenu.PureMode or ModConfigMenu.CompatibilityMode) then
	require("scripts.modconfigoldcompatibility")
end
