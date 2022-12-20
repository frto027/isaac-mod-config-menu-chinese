------------------------------------------------------------------------------
--                   IMPORTANT:  DO NOT EDIT THIS FILE!!!                   --
------------------------------------------------------------------------------
-- This file relies on other versions of itself being the same.             --
-- If you need something in this file changed, please let the creator know! --
------------------------------------------------------------------------------

-- CODE STARTS BELOW --


-------------
-- version --
-------------
local fileVersion = 10001

local SaveHelper = SaveHelper or (ModConfigMenu and ModConfigMenu.PureMode and ModConfigMenu.PureMode.SaveHelper)

-- 一部分过时的mod会破坏dofile函数的功能，我们不会去修正这些mod，但至少保证不要被它们干扰
local dofile = dofile
if REPENTANCE and not debug then
	dofile = nil
end

--prevent older/same version versions of this script from loading
if SaveHelper and SaveHelper.Version >= fileVersion then

	return SaveHelper

end

if not SaveHelper then

	SaveHelper = {}
	SaveHelper.Version = fileVersion
	
	if ModConfigMenu.PureMode then
		ModConfigMenu.PureMode.SaveHelper = SaveHelper
	else
		_G.SaveHelper = SaveHelper
	end
elseif SaveHelper.Version < fileVersion then

	local oldVersion = SaveHelper.Version
	
	-- handle old versions
	if SaveHelper.Mod.RemoveCustomCallback then
	
		if SaveHelper.OnModsLoaded then
			SaveHelper.Mod:RemoveCustomCallback(CustomCallbacks.CCH_MODS_LOADED, SaveHelper.OnModsLoaded)
		end
	
		if SaveHelper.OnGameStarted then
			SaveHelper.Mod:RemoveCustomCallback(CustomCallbacks.CCH_GAME_STARTED, SaveHelper.OnGameStarted)
		end
		
	end
	
	if SaveHelper.PostNewLevel then
		SaveHelper.Mod:RemoveCallback(ModCallbacks.MC_POST_NEW_LEVEL, SaveHelper.PostNewLevel)
	end
	
	if SaveHelper.PostNewRoom then
		SaveHelper.Mod:RemoveCallback(ModCallbacks.MC_POST_NEW_ROOM, SaveHelper.PostNewRoom)
	end
	
	if SaveHelper.PreGameExit then
		SaveHelper.Mod:RemoveCallback(ModCallbacks.MC_PRE_GAME_EXIT, SaveHelper.PreGameExit)
	end

	SaveHelper.Version = fileVersion

end


--require some lua libraries
local json = require("json")

local CustomCallbackHelper = CustomCallbackHelper
local _
--load custom callback helper
if not CustomCallbackHelper then

	if FilepathHelper and dofile then
		_, CustomCallbackHelper = pcall(dofile, "scripts/customcallbacks")
	else
		_, CustomCallbackHelper = pcall(require, "scripts/customcallbacks")
	end
	
	if not _ then
		error("Save Helper requires Custom Callback Helper to function", 2)
	end
	
end


-----------
-- setup --
-----------
SaveHelper.Mod = SaveHelper.Mod or RegisterMod("Save Helper", 1)
CustomCallbackHelper.ExtendMod(SaveHelper.Mod)

----------
--TABLES--
----------
function SaveHelper.CopyTable(tableToCopy)

	local table2 = {}
	
	for i, value in pairs(tableToCopy) do
	
		if type(value) == "table" then
			table2[i] = SaveHelper.CopyTable(value)
		else
			table2[i] = value
		end
		
	end
	
	return table2
	
end

function SaveHelper.FillTable(tableToFill, tableToFillFrom)

	for i, value in pairs(tableToFillFrom) do
	
		if tableToFill[i] ~= nil then
		
			if type(value) == "table" then
				
				if type(tableToFill[i]) ~= "table" then
					tableToFill[i] = {}
				end
				
				tableToFill[i] = SaveHelper.FillTable(tableToFill[i], value)
				
			else
				tableToFill[i] = value
			end
			
		else
		
			if type(value) == "table" then
				
				if type(tableToFill[i]) ~= "table" then
					tableToFill[i] = {}
				end
				
				tableToFill[i] = SaveHelper.FillTable({}, value)
				
			else
				tableToFill[i] = value
			end
			
		end
		
	end
	
	return tableToFill
	
end


--------------------
--CUSTOM CALLBACKS--
--------------------

--triggered before a mod saves its data
--function(modref, savedata)
--extra variable is the desired mod reference to only run your code on
--return false to prevent the save from being saved
CustomCallbacks.SH_PRE_MOD_SAVE = 1200

--triggered after a mod saves its data
--function(modref, savedata)
--extra variable is the desired mod reference to only run your code on
CustomCallbacks.SH_POST_MOD_SAVE = 1201

--triggered before a mod loads its data
--function(modref, savedata)
--extra variable is the desired mod reference to only run your code on
--return false to prevent the save from being loaded
CustomCallbacks.SH_PRE_MOD_LOAD = 1202

--triggered after a mod loads its data
--function(modref, savedata)
--extra variable is the desired mod reference to only run your code on
CustomCallbacks.SH_POST_MOD_LOAD = 1202

--triggered before savehelper resets the game save of all mods
--function(modref, savedata)
--extra variable is the desired mod reference to only run your code on
--return false to prevent the save from being reset
CustomCallbacks.SH_PRE_RESET_GAME = 1203

--triggered before savehelper resets the run save of all mods
--function(modref, savedata)
--extra variable is the desired mod reference to only run your code on
--return false to prevent the save from being reset
CustomCallbacks.SH_PRE_RESET_RUN = 1204

--triggered before savehelper resets the level save of all mods
--function(modref, savedata)
--extra variable is the desired mod reference to only run your code on
--return false to prevent the save from being reset
CustomCallbacks.SH_PRE_RESET_LEVEL = 1205

--triggered before savehelper resets the room save of all mods
--function(modref, savedata)
--extra variable is the desired mod reference to only run your code on
--return false to prevent the save from being reset
CustomCallbacks.SH_PRE_RESET_ROOM = 1206

--triggered after savehelper resets the game save of all mods
--function(modref, originalsavedata)
--originalsavedata is the save data as it existed before it was cleared
--extra variable is the desired mod reference to only run your code on
CustomCallbacks.SH_POST_RESET_GAME = 1207

--triggered after savehelper resets the run save of all mods
--function(modref, originalsavedata)
--originalsavedata is the save data as it existed before it was cleared
--extra variable is the desired mod reference to only run your code on
CustomCallbacks.SH_POST_RESET_RUN = 1208

--triggered after savehelper resets the level save of all mods
--function(modref, originalsavedata)
--originalsavedata is the save data as it existed before it was cleared
--extra variable is the desired mod reference to only run your code on
CustomCallbacks.SH_POST_RESET_LEVEL = 1209

--triggered after savehelper resets the room save of all mods
--function(modref, originalsavedata)
--originalsavedata is the save data as it existed before it was cleared
--extra variable is the desired mod reference to only run your code on
CustomCallbacks.SH_POST_RESET_ROOM = 1210


--------------
--SET UP MOD--
--------------
SaveHelper.ModsToSave = {}
function SaveHelper.AddMod(modRef)

	modRef.SaveHelper_DefaultSaveData = modRef.SaveHelper_DefaultSaveData or {}
	modRef.SaveHelper_DefaultSaveData.Run = modRef.SaveHelper_DefaultSaveData.Run or {}
	modRef.SaveHelper_DefaultSaveData.Run.Level = modRef.SaveHelper_DefaultSaveData.Run.Level or {}
	modRef.SaveHelper_DefaultSaveData.Run.Level.Room = modRef.SaveHelper_DefaultSaveData.Run.Level.Room or {}

	modRef.SaveHelper_SaveData = modRef.SaveHelper_SaveData or {}
	modRef.SaveHelper_SaveData.Run = modRef.SaveHelper_SaveData.Run or {}
	modRef.SaveHelper_SaveData.Run.Level = modRef.SaveHelper_SaveData.Run.Level or {}
	modRef.SaveHelper_SaveData.Run.Level.Room = modRef.SaveHelper_SaveData.Run.Level.Room or {}
	
	SaveHelper.ModsToSave[#SaveHelper.ModsToSave+1] = modRef
	
end

-----------------------------
--SET/GET DEFAULT SAVE DATA--
-----------------------------
function SaveHelper.DefaultGameSave(modRef, saveTable)
	
	if type(saveTable) == "table" then
	
		modRef.SaveHelper_DefaultSaveData = modRef.SaveHelper_DefaultSaveData or saveTable
		
		modRef.SaveHelper_DefaultSaveData.Run = modRef.SaveHelper_DefaultSaveData.Run or {}
		modRef.SaveHelper_DefaultSaveData.Run.Level = modRef.SaveHelper_DefaultSaveData.Run.Level or {}
		modRef.SaveHelper_DefaultSaveData.Run.Level.Room = modRef.SaveHelper_DefaultSaveData.Run.Level.Room or {}
		
		SaveHelper.FillTable(modRef.SaveHelper_DefaultSaveData, saveTable)
		
	end
	
	return modRef.SaveHelper_DefaultSaveData
	
end

function SaveHelper.DefaultRunSave(modRef, saveTable)
	
	if type(saveTable) == "table" then
	
		modRef.SaveHelper_DefaultSaveData = modRef.SaveHelper_DefaultSaveData or {}
		
		modRef.SaveHelper_DefaultSaveData.Run = modRef.SaveHelper_DefaultSaveData.Run or saveTable
		
		modRef.SaveHelper_DefaultSaveData.Run.Level = modRef.SaveHelper_DefaultSaveData.Run.Level or {}
		modRef.SaveHelper_DefaultSaveData.Run.Level.Room = modRef.SaveHelper_DefaultSaveData.Run.Level.Room or {}
		
		SaveHelper.FillTable(modRef.SaveHelper_DefaultSaveData.Run, saveTable)
		
	end
	
	return modRef.SaveHelper_DefaultSaveData.Run
	
end

function SaveHelper.DefaultLevelSave(modRef, saveTable)
	
	if type(saveTable) == "table" then
	
		modRef.SaveHelper_DefaultSaveData = modRef.SaveHelper_DefaultSaveData or {}
		modRef.SaveHelper_DefaultSaveData.Run = modRef.SaveHelper_DefaultSaveData.Run or {}
		
		modRef.SaveHelper_DefaultSaveData.Run.Level = modRef.SaveHelper_DefaultSaveData.Run.Level or saveTable
		
		modRef.SaveHelper_DefaultSaveData.Run.Level.Room = modRef.SaveHelper_DefaultSaveData.Run.Level.Room or {}
		
		SaveHelper.FillTable(modRef.SaveHelper_DefaultSaveData.Run.Level, saveTable)
		
	end
	
	return modRef.SaveHelper_DefaultSaveData.Run.Level
	
end

function SaveHelper.DefaultRoomSave(modRef, saveTable)
	
	if type(saveTable) == "table" then
	
		modRef.SaveHelper_DefaultSaveData = modRef.SaveHelper_DefaultSaveData or {}
		modRef.SaveHelper_DefaultSaveData.Run = modRef.SaveHelper_DefaultSaveData.Run or {}
		modRef.SaveHelper_DefaultSaveData.Run.Level = modRef.SaveHelper_DefaultSaveData.Run.Level or {}
		
		modRef.SaveHelper_DefaultSaveData.Run.Level.Room = modRef.SaveHelper_DefaultSaveData.Run.Level.Room or saveTable
		
		SaveHelper.FillTable(modRef.SaveHelper_DefaultSaveData.Run.Level.Room, saveTable)
		
	end
	
	return modRef.SaveHelper_DefaultSaveData.Run.Level.Room
	
end


----------------------------
--SET/GET ACTIVE SAVE DATA--
----------------------------
function SaveHelper.GameSave(modRef, saveTable)
	
	if type(saveTable) == "table" then
	
		modRef.SaveHelper_SaveData = modRef.SaveHelper_SaveData or saveTable
		
		modRef.SaveHelper_SaveData.Run = modRef.SaveHelper_SaveData.Run or {}
		modRef.SaveHelper_SaveData.Run.Level = modRef.SaveHelper_SaveData.Run.Level or {}
		modRef.SaveHelper_SaveData.Run.Level.Room = modRef.SaveHelper_SaveData.Run.Level.Room or {}
		
		SaveHelper.FillTable(modRef.SaveHelper_SaveData, saveTable)
		
	end

	return modRef.SaveHelper_SaveData
	
end

function SaveHelper.RunSave(modRef, saveTable)
	
	if type(saveTable) == "table" then
		
		modRef.SaveHelper_SaveData = modRef.SaveHelper_SaveData or {}
		
		modRef.SaveHelper_SaveData.Run = modRef.SaveHelper_SaveData.Run or saveTable
		
		modRef.SaveHelper_SaveData.Run.Level = modRef.SaveHelper_SaveData.Run.Level or {}
		modRef.SaveHelper_SaveData.Run.Level.Room = modRef.SaveHelper_SaveData.Run.Level.Room or {}
		
		SaveHelper.FillTable(modRef.SaveHelper_SaveData.Run, saveTable)
		
	end
	
	return modRef.SaveHelper_SaveData.Run
	
end

function SaveHelper.LevelSave(modRef, saveTable)
	
	if type(saveTable) == "table" then
	
		modRef.SaveHelper_SaveData = modRef.SaveHelper_SaveData or {}
		modRef.SaveHelper_SaveData.Run = modRef.SaveHelper_SaveData.Run or {}
	
		modRef.SaveHelper_SaveData.Run.Level = modRef.SaveHelper_SaveData.Run.Level or saveTable
		
		modRef.SaveHelper_SaveData.Run.Level.Room = modRef.SaveHelper_SaveData.Run.Level.Room or {}
		
		SaveHelper.FillTable(modRef.SaveHelper_SaveData.Run.Level, saveTable)
		
	end
	
	return modRef.SaveHelper_SaveData.Run.Level
	
end

function SaveHelper.RoomSave(modRef, saveTable)
	
	if type(saveTable) == "table" then
	
		modRef.SaveHelper_SaveData = modRef.SaveHelper_SaveData or {}
		modRef.SaveHelper_SaveData.Run = modRef.SaveHelper_SaveData.Run or {}
		modRef.SaveHelper_SaveData.Run.Level = modRef.SaveHelper_SaveData.Run.Level or {}
		
		modRef.SaveHelper_SaveData.Run.Level.Room = modRef.SaveHelper_SaveData.Run.Level.Room or saveTable
		
		SaveHelper.FillTable(modRef.SaveHelper_SaveData.Run.Level.Room, saveTable)
		
	end
	
	return modRef.SaveHelper_SaveData.Run.Level.Room
	
end


----------------------------
--RESESET ACTIVE SAVE DATA--
----------------------------
function SaveHelper.ResetGameSave(modRef)

	local saveData = SaveHelper.CopyTable(SaveHelper.GameSave(modRef))
	
	--SH_PRE_RESET_GAME
	local doReset = true
	
	CustomCallbackHelper.CallCallbacks
	(
		CustomCallbacks.SH_PRE_RESET_GAME, --callback id
		function(returned) --function to handle it
		
			if returned == false then
				doReset = false
				return true
			end
		
		end,
		{modRef, saveData}, --args to send
		modRef.Name --extra variable
	)
	
	if doReset then
	
		SaveHelper.ResetRunSave(modRef)
		SaveHelper.ResetLevelSave(modRef)
		SaveHelper.ResetRoomSave(modRef)
	
		modRef.SaveHelper_SaveData = SaveHelper.CopyTable(SaveHelper.DefaultGameSave(modRef))
		
		--SH_POST_RESET_GAME
		CustomCallbackHelper.CallCallbacks
		(
			CustomCallbacks.SH_POST_RESET_GAME, --callback id
			nil, --function to handle it
			{modRef, saveData}, --args to send
			modRef.Name --extra variable
		)
		
		return modRef.SaveHelper_SaveData
		
	end
	
	return saveData

end

function SaveHelper.ResetRunSave(modRef)

	local saveData = SaveHelper.CopyTable(SaveHelper.RunSave(modRef))
	
	--SH_PRE_RESET_RUN
	local doReset = true
	
	CustomCallbackHelper.CallCallbacks
	(
		CustomCallbacks.SH_PRE_RESET_RUN, --callback id
		function(returned) --function to handle it
		
			if returned == false then
				doReset = false
				return true
			end
		
		end,
		{modRef, saveData}, --args to send
		modRef.Name --extra variable
	)
	
	if doReset then
	
		SaveHelper.ResetLevelSave(modRef)
		SaveHelper.ResetRoomSave(modRef)
	
		modRef.SaveHelper_SaveData.Run = SaveHelper.CopyTable(SaveHelper.DefaultRunSave(modRef))
		
		--SH_POST_RESET_RUN
		CustomCallbackHelper.CallCallbacks
		(
			CustomCallbacks.SH_POST_RESET_RUN, --callback id
			nil, --function to handle it
			{modRef, saveData}, --args to send
			modRef.Name --extra variable
		)
		
		return modRef.SaveHelper_SaveData.Run
		
	end
	
	return saveData
	
end

function SaveHelper.ResetLevelSave(modRef)

	local saveData = SaveHelper.CopyTable(SaveHelper.LevelSave(modRef))
	
	--SH_PRE_RESET_LEVEL
	local doReset = true
	
	CustomCallbackHelper.CallCallbacks
	(
		CustomCallbacks.SH_PRE_RESET_LEVEL, --callback id
		function(returned) --function to handle it
		
			if returned == false then
				doReset = false
				return true
			end
		
		end,
		{modRef, saveData}, --args to send
		modRef.Name --extra variable
	)
	
	if doReset then
	
		SaveHelper.ResetRoomSave(modRef)
	
		modRef.SaveHelper_SaveData.Run.Level = SaveHelper.CopyTable(SaveHelper.DefaultLevelSave(modRef))
		
		--SH_POST_RESET_LEVEL
		CustomCallbackHelper.CallCallbacks
		(
			CustomCallbacks.SH_POST_RESET_LEVEL, --callback id
			nil, --function to handle it
			{modRef, saveData}, --args to send
			modRef.Name --extra variable
		)
		
		return modRef.SaveHelper_SaveData.Run.Level
		
	end
	
	return saveData
	
end

function SaveHelper.ResetRoomSave(modRef)

	local saveData = SaveHelper.CopyTable(SaveHelper.RoomSave(modRef))
	
	--SH_PRE_RESET_ROOM
	local doReset = true
	
	CustomCallbackHelper.CallCallbacks
	(
		CustomCallbacks.SH_PRE_RESET_ROOM, --callback id
		function(returned) --function to handle it
		
			if returned == false then
				doReset = false
				return true
			end
		
		end,
		{modRef, saveData}, --args to send
		modRef.Name --extra variable
	)
	
	if doReset then
	
		modRef.SaveHelper_SaveData.Run.Level.Room = SaveHelper.CopyTable(SaveHelper.DefaultRoomSave(modRef))
		
		--SH_POST_RESET_ROOM
		CustomCallbackHelper.CallCallbacks
		(
			CustomCallbacks.SH_POST_RESET_ROOM, --callback id
			nil, --function to handle it
			{modRef, saveData}, --args to send
			modRef.Name --extra variable
		)
		
		return modRef.SaveHelper_SaveData.Run.Level.Room
		
	end
	
	return saveData
	
end


---------------------
--TRIGGER SAVE/LOAD--
---------------------

function SaveHelper.Save(modRef)
	
	local saveData = SaveHelper.CopyTable(SaveHelper.DefaultGameSave(modRef))
	saveData = SaveHelper.FillTable(saveData, SaveHelper.GameSave(modRef))
	
	--SH_PRE_MOD_SAVE
	local cancelSave = false
	
	CustomCallbackHelper.CallCallbacks
	(
		CustomCallbacks.SH_PRE_MOD_SAVE, --callback id
		function(returned) --function to handle it
		
			if returned == false then
				cancelSave = true
				return true
			end
		
		end,
		{modRef, saveData}, --args to send
		modRef.Name --extra variable
	)
	
	if cancelSave then
		return
	end
	
	modRef:SaveData(json.encode(saveData))
	
	--SH_POST_MOD_SAVE
	CustomCallbackHelper.CallCallbacks
	(
		CustomCallbacks.SH_POST_MOD_SAVE, --callback id
		nil, --function to handle it
		{modRef, saveData}, --args to send
		modRef.Name --extra variable
	)
	
	return saveData
	
end

function SaveHelper.Load(modRef)

	local saveData = SaveHelper.CopyTable(SaveHelper.DefaultGameSave(modRef))
	
	if modRef:HasData() then
		local loadData = json.decode(modRef:LoadData())
		saveData = SaveHelper.FillTable(saveData, loadData)
	end
	
	--SH_PRE_MOD_LOAD
	local cancelLoad = false
	
	CustomCallbackHelper.CallCallbacks
	(
		CustomCallbacks.SH_PRE_MOD_LOAD, --callback id
		function(returned) --function to handle it
		
			if returned == false then
				cancelLoad = true
				return true
			end
		
		end,
		{modRef, saveData}, --args to send
		modRef.Name --extra variable
	)
	
	if cancelLoad then
		return
	end
	
	SaveHelper.GameSave(modRef, SaveHelper.CopyTable(saveData))

	--SH_POST_MOD_LOAD
	CustomCallbackHelper.CallCallbacks
	(
		CustomCallbacks.SH_POST_MOD_LOAD, --callback id
		nil, --function to handle it
		{modRef, saveData}, --args to send
		modRef.Name --extra variable
	)
	
end


-------------
--CALLBACKS--
-------------

local skipNextLevelClear = false
local skipNextRoomClear = false
function SaveHelper.OnModsLoaded()
	
	for _, modRef in ipairs(SaveHelper.ModsToSave) do

		SaveHelper.Load(modRef)
	
	end

end
SaveHelper.Mod:AddCustomCallback(CustomCallbacks.CCH_MODS_LOADED, SaveHelper.OnModsLoaded)

function SaveHelper.OnGameStarted(_, player, isSaveGame)

	skipNextLevelClear = true
	skipNextRoomClear = true
	
	for _, modRef in ipairs(SaveHelper.ModsToSave) do
		
		SaveHelper.Load(modRef)
		
		if not isSaveGame then
		
			SaveHelper.ResetRunSave(modRef)
			SaveHelper.Save(modRef)
			
		end
	
	end

end
SaveHelper.Mod:AddCustomCallback(CustomCallbacks.CCH_GAME_STARTED, SaveHelper.OnGameStarted)

function SaveHelper.PostNewLevel()

	if not skipNextLevelClear then
	
		for _, modRef in ipairs(SaveHelper.ModsToSave) do
	
			SaveHelper.ResetLevelSave(modRef)
			SaveHelper.Save(modRef)
			
		end
		
	end
	
	skipNextLevelClear = false
	
end
SaveHelper.Mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, SaveHelper.PostNewLevel)

function SaveHelper.PostNewRoom()

	if not skipNextRoomClear then
	
		for _, modRef in ipairs(SaveHelper.ModsToSave) do
	
			SaveHelper.ResetRoomSave(modRef)
			
		end
		
	end
	
	skipNextRoomClear = false
	
end
SaveHelper.Mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, SaveHelper.PostNewRoom)

function SaveHelper.PreGameExit()
	
	for _, modRef in ipairs(SaveHelper.ModsToSave) do
		
		SaveHelper.Save(modRef)
		
	end
	
end
SaveHelper.Mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, SaveHelper.PreGameExit)

return SaveHelper
