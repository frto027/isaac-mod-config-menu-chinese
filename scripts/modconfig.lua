-------------
-- version --
-------------
local fileVersion = 32

--prevent older/same version versions of this script from loading
if ModConfigMenu and ModConfigMenu.Version and ModConfigMenu.Version >= fileVersion then

	return ModConfigMenu

end

if not ModConfigMenu then

	ModConfigMenu = {}
	
elseif ModConfigMenu.Version and ModConfigMenu.Version < fileVersion then

	local oldVersion = ModConfigMenu.Version
	
	--handle old versions
	if ModConfigMenu.MenuData then
	
		for i=#ModConfigMenu.MenuData, 1, -1 do
		
			if ModConfigMenu.MenuData[i].Name == "General" or ModConfigMenu.MenuData[i].Name == "Mod Config Menu" then
				ModConfigMenu.MenuData[i] = nil
			end
			
		end
		
	end
	
	if ModConfigMenu.PostGameStarted then
		if ModConfigMenu.Mod.RemoveCustomCallback then
			ModConfigMenu.Mod:RemoveCustomCallback(CustomCallbacks.CCH_GAME_STARTED, ModConfigMenu.PostGameStarted)
		else
			ModConfigMenu.Mod.RemoveCallback(ModCallbacks.MC_POST_GAME_STARTED, ModConfigMenu.PostGameStarted)
		end
	end
	
	if ModConfigMenu.PostUpdate then
		ModConfigMenu.Mod:RemoveCallback(ModCallbacks.MC_POST_UPDATE, ModConfigMenu.PostUpdate)
	end
	
	if ModConfigMenu.PostRender then
		ModConfigMenu.Mod:RemoveCallback(ModCallbacks.MC_POST_RENDER, ModConfigMenu.PostRender)
	end
	
	if ModConfigMenu.InputAction then
		ModConfigMenu.Mod:RemoveCallback(ModCallbacks.MC_INPUT_ACTION, ModConfigMenu.InputAction)
	end
	
	if ModConfigMenu.ExecuteCmd then
		ModConfigMenu.Mod:RemoveCallback(ModCallbacks.MC_EXECUTE_CMD, ModConfigMenu.ExecuteCmd)
	end

end

ModConfigMenu.Version = fileVersion

-----------
-- setup --
-----------
Isaac.DebugString("Loading Mod Config Menu v" .. ModConfigMenu.Version)

local vecZero = Vector(0,0)

--load some lua scripts
local json = require("json")

--load filepath helper
if not FilepathHelper then

	pcall(require, "scripts.filepathhelper")
	
	if FilepathHelper then
		pcall(dofile, "scripts/filepathhelper")
	end
	
end

--load other scripts
if not CustomCallbackHelper then

	pcall(require, "scripts.customcallbacks")
	
	if FilepathHelper then
		pcall(dofile, "scripts/customcallbacks")
	end
	
end

if not InputHelper then

	pcall(require, "scripts.inputhelper")
	
	if FilepathHelper then
		pcall(dofile, "scripts/inputhelper")
	end
	
	if not InputHelper then
		error("Mod Config Menu requires Input Helper to function", 2)
	end
	
end

if not ScreenHelper then

	pcall(require, "scripts.screenhelper")
	
	if FilepathHelper then
		pcall(dofile, "scripts/screenhelper")
	end
	
	if not ScreenHelper then
		error("Mod Config Menu requires Screen Helper to function", 2)
	end
	
end

if not SaveHelper then

	pcall(require, "scripts.savehelper")
	
	if FilepathHelper then
		pcall(dofile, "scripts/savehelper")
	end
	
	if not SaveHelper then
		error("Mod Config Menu requires Save Helper to function", 2)
	end
	
end

local function GetCurrentModPath()
	if debug then
		return string.sub(debug.getinfo(GetCurrentModPath).source,2) .. "/../../"
	end
	--use some very hacky trickery to get the path to this mod
	local _, err = pcall(require, "")
	local _, basePathStart = string.find(err, "no file '", 1)
	local _, modPathStart = string.find(err, "no file '", basePathStart)
	local modPathEnd, _ = string.find(err, ".lua'", modPathStart)
	local modPath = string.sub(err, modPathStart+1, modPathEnd-1)
	modPath = string.gsub(modPath, "\\", "/")
	
	return modPath
end
local ReloadFont = nil

--create the mod
ModConfigMenu.Mod = ModConfigMenu.Mod or RegisterMod("Mod Config Menu", 1)


-------------------
--CUSTOM CALLBACK--
-------------------
--triggered after a setting is changed
--function(settingTable, currentSetting)
--extra variable 1 is the category of the setting, extra variable 2 is the attribute that gets saved to the config table. these are both optional
CustomCallbacks.MCM_POST_MODIFY_SETTING = 4200


----------
--SAVING--
----------

ModConfigMenu.SetConfigMetatables = ModConfigMenu.SetConfigMetatables or function() return end

ModConfigMenu.ConfigDefault = ModConfigMenu.ConfigDefault or {}
SaveHelper.FillTable(ModConfigMenu.ConfigDefault,{
	
	--last button pressed tracker
	LastBackPressed = Keyboard.KEY_ESCAPE,
	LastSelectPressed = Keyboard.KEY_ENTER
	
})
ModConfigMenu.Config = ModConfigMenu.Config or {}
SaveHelper.FillTable(ModConfigMenu.Config, ModConfigMenu.ConfigDefault)

ModConfigMenu.SetConfigMetatables()

function ModConfigMenu.GetSave()
	
	local saveData = SaveHelper.CopyTable(ModConfigMenu.ConfigDefault)
	saveData = SaveHelper.FillTable(saveData, ModConfigMenu.Config)
	
	saveData = json.encode(saveData)
	
	return saveData
	
end

function ModConfigMenu.LoadSave(fromData)

	if fromData and ((type(fromData) == "string" and json.decode(fromData)) or type(fromData) == "table") then
	
		local saveData = SaveHelper.CopyTable(ModConfigMenu.ConfigDefault)
		
		if type(fromData) == "string" then
			fromData = json.decode(fromData)
		end
		saveData = SaveHelper.FillTable(saveData, fromData)
		
		local currentData = SaveHelper.CopyTable(ModConfigMenu.Config)
		saveData = SaveHelper.FillTable(currentData, saveData)
		
		ModConfigMenu.Config = SaveHelper.CopyTable(saveData)
		ModConfigMenu.SetConfigMetatables()
		
		--make sure ScreenHelper's offset matches MCM's offset
		if ScreenHelper then
			ScreenHelper.SetOffset(ModConfigMenu.Config["General"].HudOffset)
		end
		
		--make Font match
		ReloadFont(ModConfigMenu.Config["Mod Config Menu"].UseGameFont)

		return saveData
		
	end
	
end


--------------
--game start--
--------------
local versionPrintFont

local versionPrintTimer = 0

--returns true if the room is clear and there are no active enemies and there are no projectiles
ModConfigMenu.IgnoreActiveEnemies = ModConfigMenu.IgnoreActiveEnemies or {}
function ModConfigMenu.RoomIsSafe()

	local roomHasDanger = false
	
	for _, entity in pairs(Isaac.GetRoomEntities()) do
		if entity:IsActiveEnemy() and not entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
		and (not ModConfigMenu.IgnoreActiveEnemies[entity.Type] or (ModConfigMenu.IgnoreActiveEnemies[entity.Type] and not ModConfigMenu.IgnoreActiveEnemies[entity.Type][-1] and not ModConfigMenu.IgnoreActiveEnemies[entity.Type][entity.Variant]))
		and (not (entity.Type == EntityType.ENTITY_DARK_ESAU and entity:ToNPC().State == 3)) then
			roomHasDanger = true
		elseif entity.Type == EntityType.ENTITY_PROJECTILE and entity:ToProjectile().ProjectileFlags & ProjectileFlags.CANT_HIT_PLAYER ~= 1 then
			roomHasDanger = true
		elseif entity.Type == EntityType.ENTITY_BOMBDROP then
			roomHasDanger = true
		end
	end
	
	local game = Game()
	local room = game:GetRoom()
	
	if room:IsClear() and not roomHasDanger then
		return true
	end
	
	return false
	
end

ModConfigMenu.IsVisible = false
function ModConfigMenu.PostGameStarted()

	rerunWarnMessage = nil

	if ModConfigMenu.Config["Mod Config Menu"].ShowControls then
	
		versionPrintTimer = 120
		
	end
	
	ModConfigMenu.IsVisible = false
	
	--add potato dummy to ignore list
	local potatoType = Isaac.GetEntityTypeByName("Potato Dummy")
	local potatoVariant = Isaac.GetEntityVariantByName("Potato Dummy")
	
	if potatoType and potatoType > 0 then
		ModConfigMenu.IgnoreActiveEnemies[potatoType] = ModConfigMenu.IgnoreActiveEnemies[potatoType] or {}
		ModConfigMenu.IgnoreActiveEnemies[potatoType][potatoVariant] = true
	end
	

	--sync game settings
	ModConfigMenu.SyncGameSettings()
end
if ModConfigMenu.Mod.AddCustomCallback then
	ModConfigMenu.Mod:AddCustomCallback(CustomCallbacks.CCH_GAME_STARTED, ModConfigMenu.PostGameStarted)
else
	ModConfigMenu.Mod.AddCallback(ModCallbacks.MC_POST_GAME_STARTED, ModConfigMenu.PostGameStarted)
end


---------------
--post update--
---------------
function ModConfigMenu.PostUpdate()

	if versionPrintTimer > 0 then
	
		versionPrintTimer = versionPrintTimer - 1
		
	end
	
end
ModConfigMenu.Mod:AddCallback(ModCallbacks.MC_POST_UPDATE, ModConfigMenu.PostUpdate)


------------------------------------
--set up the menu sprites and font--
------------------------------------
function ModConfigMenu.GetMenuAnm2Sprite(animation, frame, color)

	local sprite = Sprite()
	
	sprite:Load("gfx/ui/modconfig/menu.anm2", true)
	sprite:SetFrame(animation or "Idle", frame or 0)
	
	if color then
		sprite.Color = color
	end
	
	return sprite
	
end

--main menu sprites
local MenuSprite = ModConfigMenu.GetMenuAnm2Sprite("Idle", 0)
local MenuOverlaySprite = ModConfigMenu.GetMenuAnm2Sprite("IdleOverlay", 0)
local PopupSprite = ModConfigMenu.GetMenuAnm2Sprite("Popup", 0)

--main cursors
local CursorSpriteRight = ModConfigMenu.GetMenuAnm2Sprite("Cursor", 0)
local CursorSpriteUp = ModConfigMenu.GetMenuAnm2Sprite("Cursor", 1)
local CursorSpriteDown = ModConfigMenu.GetMenuAnm2Sprite("Cursor", 2)

--colors
local colorDefault = Color(1,1,1,1,0,0,0)
local colorHalf = Color(1,1,1,0.5,0,0,0)

--subcategory pane cursors
local SubcategoryCursorSpriteLeft = ModConfigMenu.GetMenuAnm2Sprite("Cursor", 3, colorHalf)
local SubcategoryCursorSpriteRight = ModConfigMenu.GetMenuAnm2Sprite("Cursor", 0, colorHalf)

--options pane cursors
local OptionsCursorSpriteUp = ModConfigMenu.GetMenuAnm2Sprite("Cursor", 1, colorHalf)
local OptionsCursorSpriteDown = ModConfigMenu.GetMenuAnm2Sprite("Cursor", 2, colorHalf)

--other options pane objects
local SubcategoryDividerSprite = ModConfigMenu.GetMenuAnm2Sprite("Divider", 0, colorHalf)
local SliderSprite = ModConfigMenu.GetMenuAnm2Sprite("Slider1", 0)

--strikeout
local StrikeOutSprite = ModConfigMenu.GetMenuAnm2Sprite("Strikeout", 0)

--back/select corner papers
local CornerSelect = ModConfigMenu.GetMenuAnm2Sprite("BackSelect", 0)
local CornerBack = ModConfigMenu.GetMenuAnm2Sprite("BackSelect", 1)
local CornerOpen = ModConfigMenu.GetMenuAnm2Sprite("BackSelect", 2)
local CornerExit = ModConfigMenu.GetMenuAnm2Sprite("BackSelect", 3)

--fonts
local Font10

local Font12

local Font16Bold

local versionPrintFont_mcm, Font10_mcm, Font12_mcm, Font16Bold_mcm = Font(), Font(), Font(), Font()
local versionPrintFont_official, Font10_official, Font12_official, Font16Bold_official = Font(), Font(), Font(), Font()
-- load fonts
versionPrintFont_mcm:Load(GetCurrentModPath() .. "resources/mcm_cn_font/pftempestasevencondensed.fnt")
Font10_mcm:Load(GetCurrentModPath() .. "resources/mcm_cn_font/teammeatfont10.fnt")
Font12_mcm:Load(GetCurrentModPath() .. "resources/mcm_cn_font/teammeatfont12.fnt")
Font16Bold_mcm:Load(GetCurrentModPath() .. "resources/mcm_cn_font/teammeatfont16bold.fnt")
versionPrintFont_official:Load("font/upheavalextended.fnt")
Font10_official:Load("font/teammeatfontextended10.fnt")
Font12_official:Load("font/teammeatfontextended12.fnt")
Font16Bold_official:Load("font/teammeatfontextended16bold.fnt")


ReloadFont = function (isGameOfficialFont)
	if isGameOfficialFont and Options and Options.Language == "zh" then
		versionPrintFont, Font10, Font12, Font16Bold = versionPrintFont_official, Font10_official, Font12_official, Font16Bold_official
	else
		versionPrintFont, Font10, Font12, Font16Bold = versionPrintFont_mcm, Font10_mcm, Font12_mcm, Font16Bold_mcm
	end
end


--popups
ModConfigMenu.PopupGfx = ModConfigMenu.PopupGfx or {}
ModConfigMenu.PopupGfx.THIN_SMALL = "gfx/ui/modconfig/popup_thin_small.png"
ModConfigMenu.PopupGfx.THIN_MEDIUM = "gfx/ui/modconfig/popup_thin_medium.png"
ModConfigMenu.PopupGfx.THIN_LARGE = "gfx/ui/modconfig/popup_thin_large.png"
ModConfigMenu.PopupGfx.WIDE_SMALL = "gfx/ui/modconfig/popup_wide_small.png"
ModConfigMenu.PopupGfx.WIDE_MEDIUM = "gfx/ui/modconfig/popup_wide_medium.png"
ModConfigMenu.PopupGfx.WIDE_LARGE = "gfx/ui/modconfig/popup_wide_large.png"


-------------------------
--add setting functions--
-------------------------
ModConfigMenu.OptionType = ModConfigMenu.OptionType or {}
ModConfigMenu.OptionType.TEXT = 1
ModConfigMenu.OptionType.SPACE = 2
ModConfigMenu.OptionType.SCROLL = 3
ModConfigMenu.OptionType.BOOLEAN = 4
ModConfigMenu.OptionType.NUMBER = 5
ModConfigMenu.OptionType.KEYBIND_KEYBOARD = 6
ModConfigMenu.OptionType.KEYBIND_CONTROLLER = 7
ModConfigMenu.OptionType.TITLE = 8

ModConfigMenu.MenuData = ModConfigMenu.MenuData or {}

--CATEGORY FUNCTIONS
function ModConfigMenu.GetCategoryIDByName(categoryName)

	if type(categoryName) ~= "string" then
		return categoryName
	end
	
	local categoryID = nil
	
	for i=1, #ModConfigMenu.MenuData do
		if categoryName == ModConfigMenu.MenuData[i].Name then
			categoryID = i
			break
		end
	end
	
	return categoryID
	
end

function ModConfigMenu.UpdateCategory(categoryName, dataTable)

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("ModConfigMenu.UpdateCategory - No valid category name provided", 2)
	end
	
	local categoryID = ModConfigMenu.GetCategoryIDByName(categoryName)
	if categoryID == nil then
		categoryID = #ModConfigMenu.MenuData+1
		ModConfigMenu.MenuData[categoryID] = {}
		ModConfigMenu.MenuData[categoryID].Subcategories = {}
	end
	
	if type(categoryName) == "string" or dataTable.Name then
		ModConfigMenu.MenuData[categoryID].Name = dataTable.Name or categoryName
	end
	
	if dataTable.Info then
		ModConfigMenu.MenuData[categoryID].Info = dataTable.Info
	end
	
	if dataTable.IsOld then
		ModConfigMenu.MenuData[categoryID].IsOld = dataTable.IsOld
	end
	
	if dataTable.NameTranslate then
		ModConfigMenu.MenuData[categoryID].NameTranslate = dataTable.NameTranslate
	end

	if dataTable.InfoTranslate then
		ModConfigMenu.MenuData[categoryID].InfoTranslate = dataTable.InfoTranslate
	end
end

function ModConfigMenu.SetCategoryInfo(categoryName, info)

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("ModConfigMenu.SetCategoryInfo - No valid category name provided", 2)
	end

	ModConfigMenu.UpdateCategory(categoryName, {
		Info = info
	})
	
end

function ModConfigMenu.RemoveCategory(categoryName)

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("ModConfigMenu.RemoveCategory - No valid category name provided", 2)
	end
	
	local categoryID = ModConfigMenu.GetCategoryIDByName(categoryName)
	if categoryID then
	
		table.remove(ModConfigMenu.MenuData, categoryID)
		return true
		
	end
	
	return false

end

--SUBCATEGORY FUNCTIONS
function ModConfigMenu.GetSubcategoryIDByName(categoryName, subcategoryName)

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("ModConfigMenu.GetSubcategoryIDByName - No valid category name provided", 2)
	end
	
	local categoryID = ModConfigMenu.GetCategoryIDByName(categoryName)

	if type(subcategoryName) ~= "string" then
		return subcategoryName
	end
	
	local subcategoryID = nil
	
	for i=1, #ModConfigMenu.MenuData[categoryID].Subcategories do
		if subcategoryName == ModConfigMenu.MenuData[categoryID].Subcategories[i].Name then
			subcategoryID = i
			break
		end
	end
	
	return subcategoryID
	
end

function ModConfigMenu.UpdateSubcategory(categoryName, subcategoryName, dataTable)

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("ModConfigMenu.UpdateSubcategory - No valid category name provided", 2)
	end

	if type(subcategoryName) ~= "string" and type(subcategoryName) ~= "number" then
		error("ModConfigMenu.UpdateSubcategory - No valid subcategory name provided", 2)
	end
	
	local categoryID = ModConfigMenu.GetCategoryIDByName(categoryName)
	if categoryID == nil then
		categoryID = #ModConfigMenu.MenuData+1
		ModConfigMenu.MenuData[categoryID] = {}
		ModConfigMenu.MenuData[categoryID].Name = tostring(categoryName)
		ModConfigMenu.MenuData[categoryID].Subcategories = {}
	end
	
	local subcategoryID = ModConfigMenu.GetSubcategoryIDByName(categoryID, subcategoryName)
	if subcategoryID == nil then
		subcategoryID = #ModConfigMenu.MenuData[categoryID].Subcategories+1
		ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID] = {}
		ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Options = {}
	end
	
	if type(subcategoryName) == "string" or dataTable.Name then
		ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Name = dataTable.Name or subcategoryName
	end
	
	if dataTable.Info then
		ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Info = dataTable.Info
	end
	
	if dataTable.NameTranslate then
		ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].NameTranslate = dataTable.NameTranslate
	end

	if dataTable.InfoTranslate then
		ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].InfoTranslate = dataTable.InfoTranslate
	end
end

function ModConfigMenu.RemoveSubcategory(categoryName, subcategoryName)

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("ModConfigMenu.RemoveSubcategory - No valid category name provided", 2)
	end

	if type(subcategoryName) ~= "string" and type(subcategoryName) ~= "number" then
		error("ModConfigMenu.RemoveSubcategory - No valid subcategory name provided", 2)
	end
	
	local categoryID = ModConfigMenu.GetCategoryIDByName(categoryName)
	if categoryID then
	
		local subcategoryID = ModConfigMenu.GetSubcategoryIDByName(categoryID, subcategoryName)
		if subcategoryID then
		
			table.remove(ModConfigMenu.MenuData[categoryID].Subcategories, subcategoryID)
			return true
			
		end
		
	end
	
	return false

end

--SETTING FUNCTIONS
function ModConfigMenu.AddSetting(categoryName, subcategoryName, settingTable)

	if settingTable == nil then
		settingTable = subcategoryName
		subcategoryName = nil
	end

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("ModConfigMenu.AddSetting - No valid category name provided", 2)
	end
	
	subcategoryName = subcategoryName or "Uncategorized"
	if type(subcategoryName) ~= "string" and type(subcategoryName) ~= "number" then
		error("ModConfigMenu.AddSetting - No valid subcategory name provided", 2)
	end
	
	local categoryID = ModConfigMenu.GetCategoryIDByName(categoryName)
	if categoryID == nil then
		categoryID = #ModConfigMenu.MenuData+1
		ModConfigMenu.MenuData[categoryID] = {}
		ModConfigMenu.MenuData[categoryID].Name = tostring(categoryName)
		ModConfigMenu.MenuData[categoryID].Subcategories = {}
	end
	
	local subcategoryID = ModConfigMenu.GetSubcategoryIDByName(categoryID, subcategoryName)
	if subcategoryID == nil then
		subcategoryID = #ModConfigMenu.MenuData[categoryID].Subcategories+1
		ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID] = {}
		ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Name = tostring(subcategoryName)
		ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Options = {}
	end
	
	ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Options[#ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Options+1] = settingTable
	
	return settingTable
	
end

function ModConfigMenu.AddText(categoryName, subcategoryName, text, color)

	if color == nil and type(text) ~= "string" and type(text) ~= "function" then
		color = text
		text = subcategoryName
		subcategoryName = nil
	end

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("ModConfigMenu.AddText - No valid category name provided", 2)
	end
	
	subcategoryName = subcategoryName or "Uncategorized"
	if type(subcategoryName) ~= "string" and type(subcategoryName) ~= "number" then
		error("ModConfigMenu.AddText - No valid subcategory name provided", 2)
	end
	
	local settingTable = {
		Type = ModConfigMenu.OptionType.TEXT,
		Display = text,
		Color = color,
		NoCursorHere = true
	}
	
	return ModConfigMenu.AddSetting(categoryName, subcategoryName, settingTable)
	
end

function ModConfigMenu.AddTitle(categoryName, subcategoryName, text, color)

	if color == nil and type(text) ~= "string" and type(text) ~= "function" then
		color = text
		text = subcategoryName
		subcategoryName = nil
	end
	
	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("ModConfigMenu.AddTitle - No valid category name provided", 2)
	end
	
	subcategoryName = subcategoryName or "Uncategorized"
	if type(subcategoryName) ~= "string" and type(subcategoryName) ~= "number" then
		error("ModConfigMenu.AddTitle - No valid subcategory name provided", 2)
	end
	
	local settingTable = {
		Type = ModConfigMenu.OptionType.TITLE,
		Display = text,
		Color = color,
		NoCursorHere = true
	}
	
	return ModConfigMenu.AddSetting(categoryName, subcategoryName, settingTable)
	
end

function ModConfigMenu.AddSpace(categoryName, subcategoryName)
	
	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("ModConfigMenu.AddSpace - No valid category name provided", 2)
	end
	
	subcategoryName = subcategoryName or "Uncategorized"
	if type(subcategoryName) ~= "string" and type(subcategoryName) ~= "number" then
		error("ModConfigMenu.AddSpace - No valid subcategory name provided", 2)
	end

	local settingTable = {
		Type = ModConfigMenu.OptionType.SPACE
	}
	
	return ModConfigMenu.AddSetting(categoryName, subcategoryName, settingTable)
	
end

local altSlider = false
function ModConfigMenu.SimpleAddSetting(settingType, categoryName, subcategoryName, configTableAttribute, minValue, maxValue, modifyBy, defaultValue, displayText, displayValueProxies, displayDevice, info, color, functionName)
	
	--set default values
	if defaultValue == nil then
		if settingType == ModConfigMenu.OptionType.BOOLEAN then
			defaultValue = false
		else
			defaultValue = 0
		end
	end
	
	if settingType == ModConfigMenu.OptionType.NUMBER then
		minValue = minValue or 0
		maxValue = maxValue or 10
		modifyBy = modifyBy or 1
	else
		minValue = nil
		maxValue = nil
		modifyBy = nil
	end
	
	functionName = functionName or "SimpleAddSetting"
	
	--erroring
	if categoryName == nil then
		error("ModConfigMenu." .. tostring(functionName) .. " - No valid category name provided", 2)
	end
	if configTableAttribute == nil then
		error("ModConfigMenu." .. tostring(functionName) .. " - No valid config table attribute provided", 2)
	end
	
	--create config value
	ModConfigMenu.Config[categoryName] = ModConfigMenu.Config[categoryName] or {}
	if ModConfigMenu.Config[categoryName][configTableAttribute] == nil then
		ModConfigMenu.Config[categoryName][configTableAttribute] = defaultValue
	end
	
	ModConfigMenu.ConfigDefault[categoryName] = ModConfigMenu.ConfigDefault[categoryName] or {}
	if ModConfigMenu.ConfigDefault[categoryName][configTableAttribute] == nil then
		ModConfigMenu.ConfigDefault[categoryName][configTableAttribute] = defaultValue
	end
	
	--setting
	local settingTable = {
		Type = settingType,
		Attribute = configTableAttribute,
		CurrentSetting = function()
			return ModConfigMenu.Config[categoryName][configTableAttribute]
		end,
		Default = defaultValue,
		Display = function(cursorIsAtThisOption, configMenuInOptions, lastOptionPos)
		
			local currentValue = ModConfigMenu.Config[categoryName][configTableAttribute]
		
			local displayString = ""
			
			if displayText then
				displayString = displayText .. ": "
			end
			
			if settingType == ModConfigMenu.OptionType.SCROLL then
			
				displayString = displayString .. "$scroll" .. tostring(math.floor(currentValue))
				
			elseif settingType == ModConfigMenu.OptionType.KEYBIND_KEYBOARD then
				
				local key = "无"
				
				if currentValue > -1 then
				
					key = "未知按键"
					
					if InputHelper.KeyboardToString[currentValue] then
						key = InputHelper.KeyboardToString[currentValue]
					end
					
				end
				
				displayString = displayString .. key
				
				if displayDevice then
					
					displayString = displayString .. " (键盘)"
					
				end
				
			elseif settingType == ModConfigMenu.OptionType.KEYBIND_CONTROLLER then
				
				local key = "无"
				
				if currentValue > -1 then
				
					key = "未知按钮"
					
					if InputHelper.ControllerToString[currentValue] then
						key = InputHelper.ControllerToString[currentValue]
					end
					
				end
				
				displayString = displayString .. key
				
				if displayDevice then
					
					displayString = displayString .. " (控制器)"
					
				end
				
			elseif displayValueProxies and displayValueProxies[currentValue] then
			
				displayString = displayString .. tostring(displayValueProxies[currentValue])
				
			else
			
				displayString = displayString .. tostring(currentValue)
				
			end
			
			return displayString
			
		end,
		OnChange = function(currentValue)
		
			if not currentValue then
			
				if settingType == ModConfigMenu.OptionType.KEYBIND_KEYBOARD or settingType == ModConfigMenu.OptionType.KEYBIND_CONTROLLER then
					currentValue = -1
				end
				
			end
			
			ModConfigMenu.Config[categoryName][configTableAttribute] = currentValue
			
		end,
		Info = info,
		Color = color
	}
	
	if settingType == ModConfigMenu.OptionType.NUMBER then
	
		settingTable.Minimum = minValue
		settingTable.Maximum = maxValue
		settingTable.ModifyBy = modifyBy
		
	elseif settingType == ModConfigMenu.OptionType.SCROLL then

		settingTable.AltSlider = altSlider
		altSlider = not altSlider
		
	elseif settingType == ModConfigMenu.OptionType.KEYBIND_KEYBOARD or settingType == ModConfigMenu.OptionType.KEYBIND_CONTROLLER then
		
		settingTable.PopupGfx = ModConfigMenu.PopupGfx.WIDE_SMALL
		settingTable.PopupWidth = 280
		settingTable.Popup = function()
		
			local currentValue = ModConfigMenu.Config[categoryName][configTableAttribute]
		
			local goBackString = "返回"
			if ModConfigMenu.Config.LastBackPressed then
			
				if InputHelper.KeyboardToString[ModConfigMenu.Config.LastBackPressed] then
					goBackString = InputHelper.KeyboardToString[ModConfigMenu.Config.LastBackPressed]
				elseif InputHelper.ControllerToString[ModConfigMenu.Config.LastBackPressed] then
					goBackString = InputHelper.ControllerToString[ModConfigMenu.Config.LastBackPressed]
				end
				
			end
			
			local keepSettingString = ""
			if currentValue > -1 then
			
				local currentSettingString = nil
				if (settingType == ModConfigMenu.OptionType.KEYBIND_KEYBOARD and InputHelper.KeyboardToString[currentValue]) then
					currentSettingString = InputHelper.KeyboardToString[currentValue]
				elseif (settingType == ModConfigMenu.OptionType.KEYBIND_CONTROLLER and InputHelper.ControllerToString[currentValue]) then
					currentSettingString = InputHelper.ControllerToString[currentValue]
				end
				
				keepSettingString = "当前设置为 \"" .. currentSettingString .. "\".$newline按此键保持设置不变。$newline"
				
			end
			
			local deviceString = ""
			if settingType == ModConfigMenu.OptionType.KEYBIND_KEYBOARD then
				deviceString = "键盘"
			elseif settingType == ModConfigMenu.OptionType.KEYBIND_CONTROLLER then
				deviceString = "控制器"
			end
			
			return "在" .. deviceString .. "上按任意键改变设置$newline" .. keepSettingString .. "按\"" .. goBackString .. "\"返回并清除设置"
			
		end
		
	end
	
	return ModConfigMenu.AddSetting(categoryName, subcategoryName, settingTable)
	
end

function ModConfigMenu.AddBooleanSetting(categoryName, subcategoryName, configTableAttribute, defaultValue, displayText, displayValueProxies, info, color)

	--move args around
	if type(configTableAttribute) ~= "string" then
		color = info
		info = displayValueProxies
		displayValueProxies = displayText
		displayText = defaultValue
		defaultValue = configTableAttribute
		configTableAttribute = subcategoryName
		subcategoryName = nil
	end
	
	if type(defaultValue) ~= "boolean" then
		color = info
		info = displayValueProxies
		displayValueProxies = displayText
		displayText = defaultValue
		defaultValue = false
	end

	if type(displayValueProxies) ~= "table" or type(info) == "userdata" or type(info) == "nil" then
		color = info
		info = displayValueProxies
		displayValueProxies = nil
	end
	
	return ModConfigMenu.SimpleAddSetting(ModConfigMenu.OptionType.BOOLEAN, categoryName, subcategoryName, configTableAttribute, nil, nil, nil, defaultValue, displayText, displayValueProxies, nil, info, color, "AddBooleanSetting")
	
end

function ModConfigMenu.AddNumberSetting(categoryName, subcategoryName, configTableAttribute, minValue, maxValue, modifyBy, defaultValue, displayText, displayValueProxies, info, color)

	--move args around
	if type(configTableAttribute) ~= "string" then
		color = info
		info = displayValueProxies
		displayValueProxies = displayText
		displayText = defaultValue
		defaultValue = modifyBy
		modifyBy = maxValue
		maxValue = minValue
		minValue = configTableAttribute
		configTableAttribute = subcategoryName
		subcategoryName = nil
	end
	
	if type(defaultValue) == "string" then
		color = info
		info = displayValueProxies
		displayValueProxies = displayText
		displayText = defaultValue
		defaultValue = modifyBy
		modifyBy = nil
	end

	if type(displayValueProxies) ~= "table" or type(info) == "userdata" or type(info) == "nil" then
		color = info
		info = displayValueProxies
		displayValueProxies = nil
	end
	
	--set default values
	defaultValue = defaultValue or 0
	minValue = minValue or 0
	maxValue = maxValue or 10
	modifyBy = modifyBy or 1
	
	return ModConfigMenu.SimpleAddSetting(ModConfigMenu.OptionType.NUMBER, categoryName, subcategoryName, configTableAttribute, minValue, maxValue, modifyBy, defaultValue, displayText, displayValueProxies, nil, info, color, "AddNumberSetting")
	
end

function ModConfigMenu.AddScrollSetting(categoryName, subcategoryName, configTableAttribute, defaultValue, displayText, info, color)

	--move args around
	if type(configTableAttribute) ~= "string" then
		color = info
		info = displayText
		displayText = defaultValue
		defaultValue = configTableAttribute
		configTableAttribute = subcategoryName
		subcategoryName = nil
	end
	
	if type(defaultValue) ~= "number" then
		color = info
		info = displayText
		displayText = defaultValue
		defaultValue = nil
	end
	
	--set default values
	defaultValue = defaultValue or 0

	return ModConfigMenu.SimpleAddSetting(ModConfigMenu.OptionType.SCROLL, categoryName, subcategoryName, configTableAttribute, nil, nil, nil, defaultValue, displayText, nil, nil, info, color, "AddScrollSetting")
	
end

function ModConfigMenu.AddKeyboardSetting(categoryName, subcategoryName, configTableAttribute, defaultValue, displayText, displayDevice, info, color)

	--move args around
	if type(configTableAttribute) ~= "string" then
		color = info
		info = displayDevice
		displayDevice = displayText
		displayText = defaultValue
		defaultValue = configTableAttribute
		configTableAttribute = subcategoryName
		subcategoryName = nil
	end
	
	if type(defaultValue) ~= "number" then
		color = info
		info = displayText
		displayText = defaultValue
		defaultValue = nil
	end
	
	if type(displayDevice) ~= "boolean" then
		color = info
		info = displayDevice
		displayDevice = false
	end
	
	--set default values
	defaultValue = defaultValue or -1

	return ModConfigMenu.SimpleAddSetting(ModConfigMenu.OptionType.KEYBIND_KEYBOARD, categoryName, subcategoryName, configTableAttribute, nil, nil, nil, defaultValue, displayText, nil, displayDevice, info, color, "AddKeyboardSetting")
	
end

function ModConfigMenu.AddControllerSetting(categoryName, subcategoryName, configTableAttribute, defaultValue, displayText, displayDevice, info, color)

	--move args around
	if type(configTableAttribute) ~= "string" then
		color = info
		info = displayDevice
		displayDevice = displayText
		displayText = defaultValue
		defaultValue = configTableAttribute
		configTableAttribute = subcategoryName
		subcategoryName = nil
	end
	
	if type(defaultValue) ~= "number" then
		color = info
		info = displayText
		displayText = defaultValue
		defaultValue = nil
	end
	
	if type(displayDevice) ~= "boolean" then
		color = info
		info = displayDevice
		displayDevice = false
	end
	
	--set default values
	defaultValue = defaultValue or -1

	return ModConfigMenu.SimpleAddSetting(ModConfigMenu.OptionType.KEYBIND_CONTROLLER, categoryName, subcategoryName, configTableAttribute, nil, nil, nil, defaultValue, displayText, nil, displayDevice, info, color, "AddControllerSetting")
	
end

function ModConfigMenu.RemoveSetting(categoryName, subcategoryName, settingAttribute)

	if settingAttribute == nil then
		settingAttribute = subcategoryName
		subcategoryName = nil
	end

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("ModConfigMenu.RemoveSetting - No valid category name provided", 2)
	end

	subcategoryName = subcategoryName or "Uncategorized"
	if type(subcategoryName) ~= "string" and type(subcategoryName) ~= "number" then
		error("ModConfigMenu.RemoveSetting - No valid subcategory name provided", 2)
	end
	
	local categoryID = ModConfigMenu.GetCategoryIDByName(categoryName)
	if categoryID then
	
		local subcategoryID = ModConfigMenu.GetSubcategoryIDByName(categoryID, subcategoryName)
		if subcategoryID then
		
			--loop to find matching attribute
			for i=#ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Options, 1, -1 do
			
				if ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Options[i]
				and ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Options[i].Attribute
				and ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Options[i].Attribute == settingAttribute then
				
					table.remove(ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Options, i)
					return true
					
				end
				
			end
		
			--loop to find matching display
			for i=#ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Options, 1, -1 do
			
				if ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Options[i]
				and ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Options[i].Display
				and ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Options[i].Display == settingAttribute then
				
					table.remove(ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Options, i)
					return true
					
				end
				
			end
			
		end
		
	end
	
	return false

end

--------------------------
--GENERAL SETTINGS SETUP--
--------------------------
ModConfigMenu.SetCategoryInfo("General", "Settings that affect the majority of mods")

local useGameSetting = ModConfigMenu.AddBooleanSetting(
	"General", --category
	"SyncGameSettings", --attribute in table
	true, --default value,
	"Sync Game Setting", --display text
	{ --value display text
		[true] = "Yes",
		[false] = "No"
	},
	"Synchornize settings from game Options menu when game start."
)

function ModConfigMenu.SyncGameSettings()
	if REPENTANCE and ModConfigMenu.Config["General"].UseGameSetting then
		local HUDOffset = math.floor(Options.HUDOffset * 10 + 0.5)
		if HUDOffset ~= ModConfigMenu.Config["General"].HudOffset then
			ModConfigMenu.Config["General"].HudOffset = HUDOffset
			local category = ModConfigMenu.GetSubcategoryIDByName("General","HudOffset")
			local change = category and category.OnChange
			if change then
				change(HUDOffset)
			end
		end
		local ChargeBars = Options.ChargeBars
		if ChargeBars ~= ModConfigMenu.Config["General"].ChargeBars then
			ModConfigMenu.Config["General"].ChargeBars = ChargeBars
			local category = ModConfigMenu.GetSubcategoryIDByName("General","ChargeBars")
			local change = category and category.OnChange
			if change then
				change(ChargeBars)
			end
		end

	end
end

----------------------
--HUD OFFSET SETTING--
----------------------
local hudOffsetSetting = ModConfigMenu.AddScrollSetting(
	"General", --category
	"HudOffset", --attribute in table
	10, --default value
	"Hud Offset", --display text
	"How far from the corners of the screen custom hud elements will be.$newlineTry to make this match your base-game setting."
)

hudOffsetSetting.HideControls = true -- hide controls so the screen corner graphics are easier to see
hudOffsetSetting.ShowOffset = true -- shows screen offset

--set up callback
local oldHudOffsetOnChange = hudOffsetSetting.OnChange
hudOffsetSetting.OnChange = function(currentValue)

	--update screenhelper's offset
	if ScreenHelper then
		ScreenHelper.SetOffset(currentValue)
	end

	return oldHudOffsetOnChange(currentValue)
	
end

--------------------
--OVERLAYS SETTING--
--------------------
ModConfigMenu.AddBooleanSetting(
	"General", --category
	"Overlays", --attribute in table
	true, --default value
	"Overlays", --display text
	{ --value display text
		[true] = "On",
		[false] = "Off"
	},
	"Enable or disable custom visual overlays, like screen-wide fog."
)


-----------------------
--CHARGE BARS SETTING--
-----------------------
local ChargeBarsSettings = ModConfigMenu.AddBooleanSetting(
	"General", --category
	"ChargeBars", --attribute in table
	false, --default value
	"Charge Bars", --display text
	{ --value display text
		[true] = "On",
		[false] = "Off"
	},
	"Enable or disable custom charge bar visuals for mod effects, like those from chargable items."
)

---------------------
--BIG BOOKS SETTING--
---------------------
ModConfigMenu.AddBooleanSetting(
	"General", --category
	"BigBooks", --attribute in table
	true, --default value
	"Bigbooks", --display text
	{ --value display text
		[true] = "On",
		[false] = "Off"
	},
	"Enable or disable custom bigbook overlays which can appear when an active item is used."
)


---------------------
--ANNOUNCER SETTING--
---------------------
ModConfigMenu.AddNumberSetting(
	"General", --category
	"Announcer", --attribute in table
	0, --minimum value
	2, --max value
	0, --default value,
	"Announcer", --display text
	{ --value display text
		[0] = "Sometimes",
		[1] = "Never",
		[2] = "Always"
	},
	"Choose how often a voice-over will play when a pocket item (pill or card) is used."
)

--------------------------
--GENERAL SETTINGS CLOSE--
--------------------------

ModConfigMenu.AddSpace("General") --SPACE

ModConfigMenu.AddText("General", "These settings apply to")
ModConfigMenu.AddText("General", "all mods which support them")


----------------------------------
--MOD CONFIG MENU SETTINGS SETUP--
----------------------------------

ModConfigMenu.SetCategoryInfo("Mod Config Menu", "Settings specific to Mod Config Menu.$newlineChange keybindings for the menu here.")

ModConfigMenu.AddTitle("Mod Config Menu", "版本 " .. tostring(ModConfigMenu.Version) .. " (集成汉化)!") --VERSION INDICATOR

ModConfigMenu.AddSpace("Mod Config Menu") --SPACE


----------------------
--OPEN MENU KEYBOARD--
----------------------
local openMenuKeyboardSetting = ModConfigMenu.AddKeyboardSetting(
	"Mod Config Menu", --category
	"OpenMenuKeyboard", --attribute in table
	Keyboard.KEY_L, --default value
	"Open Menu", --display text
	true, --if (keyboard) is displayed after the key text
	"Choose what button on your keyboard will open Mod Config Menu."
)

openMenuKeyboardSetting.IsOpenMenuKeybind = true


------------------------
--OPEN MENU CONTROLLER--
------------------------
local openMenuControllerSetting = ModConfigMenu.AddControllerSetting(
	"Mod Config Menu", --category
	"OpenMenuController", --attribute in table
	Controller.STICK_RIGHT, --default value
	"Open Menu", --display text
	true, --if (controller) is displayed after the key text
	"Choose what button on your controller will open Mod Config Menu."
)

openMenuControllerSetting.IsOpenMenuKeybind = true

--f10 note
ModConfigMenu.AddText("Mod Config Menu", "F10 will always open this menu.")

ModConfigMenu.AddSpace("Mod Config Menu") --SPACE


------------
--HIDE HUD--
------------
local hideHudSetting = ModConfigMenu.AddBooleanSetting(
	"Mod Config Menu", --category
	"HideHudInMenu", --attribute in table
	true, --default value
	"Hide HUD", --display text
	{ --value display text
		[true] = "Yes",
		[false] = "No"
	},
	"Enable or disable the hud when this menu is open."
)

--actively modify the hud visibility as this setting changes
local oldHideHudOnChange = hideHudSetting.OnChange
hideHudSetting.OnChange = function(currentValue)

	oldHideHudOnChange(currentValue)
	
	local game = Game()
	local seeds = game:GetSeeds()
	
	if currentValue then
		if not seeds:HasSeedEffect(SeedEffect.SEED_NO_HUD) then
			seeds:AddSeedEffect(SeedEffect.SEED_NO_HUD)
		end
	else
		if seeds:HasSeedEffect(SeedEffect.SEED_NO_HUD) then
			seeds:RemoveSeedEffect(SeedEffect.SEED_NO_HUD)
		end
	end

end


----------------------------
--RESET TO DEFAULT KEYBIND--
----------------------------
local resetKeybindSetting = ModConfigMenu.AddKeyboardSetting(
	"Mod Config Menu", --category
	"ResetToDefault", --attribute in table
	Keyboard.KEY_R, --default value
	"Reset To Default Keybind", --display text
	"Press this button on your keyboard to reset a setting to its default value."
)

resetKeybindSetting.IsResetKeybind = true

-----------------
--USE GAME FONT--
-----------------
local officialFontAvaliable = true
useGameFont = ModConfigMenu.AddBooleanSetting(
	"Mod Config Menu", --category
	"UseGameFont", --attribute in table
	false, --default value
	"Use Game Font(Chinese Needed)", --display text
	{ --value display text
		[true] = "Yes",
		[false] = "No"
	},
	"Use the Chinese font that comes with the game instead of the font in MCM."
)
local oldUseGameFontOnChange = useGameFont.OnChange
useGameFont.OnChange = function(currentValue)
	oldUseGameFontOnChange(currentValue)
	ReloadFont(currentValue)
end

ReloadFont(false)

-----------------
--SHOW CONTROLS--
-----------------
ModConfigMenu.AddBooleanSetting(
	"Mod Config Menu", --category
	"ShowControls", --attribute in table
	true, --default value
	"Show Controls", --display text
	{ --value display text
		[true] = "Yes",
		[false] = "No"
	},
	"Disable this to remove the back and select widgets at the lower corners of the screen and remove the bottom start-up message."
)

ModConfigMenu.AddSpace("Mod Config Menu") --SPACE


-----------------
--COMPATIBILITY--
-----------------
local compatibilitySetting = ModConfigMenu.AddBooleanSetting(
	"Mod Config Menu", --category
	"CompatibilityLayer", --attribute in table
	false, --default value
	"Disable Legacy Warnings", --display text
	{ --value display text
		[true] = "Yes",
		[false] = "No"
	},
	"Use this setting to prevent warnings from being printed to the console for mods that use outdated features of Mod Config Menu."
)
-- compatibilitySetting.Restart = true

local configMenuSubcategoriesCanShow = 3

local configMenuInSubcategory = false
local configMenuInOptions = false
local configMenuInPopup = false

local holdingCounterDown = 0
local holdingCounterUp = 0
local holdingCounterRight = 0
local holdingCounterLeft = 0

local configMenuPositionCursorCategory = 1
local configMenuPositionCursorSubcategory = 1
local configMenuPositionCursorOption = 1

local configMenuPositionFirstSubcategory = 1

--valid action presses
local actionsDown = {ButtonAction.ACTION_DOWN, ButtonAction.ACTION_SHOOTDOWN, ButtonAction.ACTION_MENUDOWN}
local actionsUp = {ButtonAction.ACTION_UP, ButtonAction.ACTION_SHOOTUP, ButtonAction.ACTION_MENUUP}
local actionsRight = {ButtonAction.ACTION_RIGHT, ButtonAction.ACTION_SHOOTRIGHT, ButtonAction.ACTION_MENURIGHT}
local actionsLeft = {ButtonAction.ACTION_LEFT, ButtonAction.ACTION_SHOOTLEFT, ButtonAction.ACTION_MENULEFT}
local actionsBack = {ButtonAction.ACTION_PILLCARD, ButtonAction.ACTION_MAP, ButtonAction.ACTION_MENUBACK}
local actionsSelect = {ButtonAction.ACTION_ITEM, ButtonAction.ACTION_PAUSE, ButtonAction.ACTION_MENUCONFIRM, ButtonAction.ACTION_BOMB}

--ignore these buttons for the above actions
local ignoreActionButtons = {Controller.BUTTON_A, Controller.BUTTON_B, Controller.BUTTON_X, Controller.BUTTON_Y, Controller.DPAD_LEFT, Controller.DPAD_RIGHT, Controller.DPAD_UP, Controller.DPAD_DOWN}

local currentMenuCategory = nil
local currentMenuSubcategory = nil
local currentMenuOption = nil
local function updateCurrentMenuVars()
	if ModConfigMenu.MenuData[configMenuPositionCursorCategory] then
		currentMenuCategory = ModConfigMenu.MenuData[configMenuPositionCursorCategory]
		if currentMenuCategory.Subcategories and currentMenuCategory.Subcategories[configMenuPositionCursorSubcategory] then
			currentMenuSubcategory = currentMenuCategory.Subcategories[configMenuPositionCursorSubcategory]
			if currentMenuSubcategory.Options and currentMenuSubcategory.Options[configMenuPositionCursorOption] then
				currentMenuOption = currentMenuSubcategory.Options[configMenuPositionCursorOption]
			end
		end
	end
end

--leaving/entering menu sections
function ModConfigMenu.EnterPopup()
	if configMenuInSubcategory and configMenuInOptions and not configMenuInPopup then
		local foundValidPopup = false
		if currentMenuOption
		and currentMenuOption.Type
		and currentMenuOption.Type ~= ModConfigMenu.OptionType.SPACE
		and (currentMenuOption.Popup or currentMenuOption.Restart or currentMenuOption.Rerun) then
			foundValidPopup = true
		end
		if foundValidPopup then
			local popupSpritesheet = ModConfigMenu.PopupGfx.THIN_SMALL
			if currentMenuOption.PopupGfx and type(currentMenuOption.PopupGfx) == "string" then
				popupSpritesheet = currentMenuOption.PopupGfx
			end
			PopupSprite:ReplaceSpritesheet(5, popupSpritesheet)
			PopupSprite:LoadGraphics()
			configMenuInPopup = true
		end
	end
end

function ModConfigMenu.EnterOptions()
	if configMenuInSubcategory and not configMenuInOptions then
		if currentMenuSubcategory
		and currentMenuSubcategory.Options
		and #currentMenuSubcategory.Options > 0 then
		
			for optionIndex=1, #currentMenuSubcategory.Options do
				
				local thisOption = currentMenuSubcategory.Options[optionIndex]
				
				if thisOption.Type
				and thisOption.Type ~= ModConfigMenu.OptionType.SPACE
				and (not thisOption.NoCursorHere or (type(thisOption.NoCursorHere) == "function" and not thisOption.NoCursorHere()))
				and thisOption.Display then
				
					configMenuPositionCursorOption = optionIndex
					configMenuInOptions = true
					OptionsCursorSpriteUp.Color = colorDefault
					OptionsCursorSpriteDown.Color = colorDefault
					
					break
				end
			end
		end
	end
end

function ModConfigMenu.EnterSubcategory()
	if not configMenuInSubcategory then
		configMenuInSubcategory = true
		SubcategoryCursorSpriteLeft.Color = colorDefault
		SubcategoryCursorSpriteRight.Color = colorDefault
		SubcategoryDividerSprite.Color = colorDefault
		
		local hasUsableCategories = false
		if currentMenuCategory.Subcategories then
			for j=1, #currentMenuCategory.Subcategories do
				if currentMenuCategory.Subcategories[j].Name ~= "Uncategorized" then
					hasUsableCategories = true
				end
			end
		end
		
		if not hasUsableCategories then
			ModConfigMenu.EnterOptions()
		end
	end
end

local restartWarnMessage = nil
local rerunWarnMessage = nil
function ModConfigMenu.LeavePopup()
	if configMenuInSubcategory and configMenuInOptions and configMenuInPopup then
		
		if currentMenuOption then
		
			if currentMenuOption.Restart then
			
				restartWarnMessage = "One or more settings require you to restart the game"
			
			elseif currentMenuOption.Rerun then
			
				rerunWarnMessage = "One or more settings require you to start a new run"
				
			end
			
		end
	
		configMenuInPopup = false
		
	end
end

function ModConfigMenu.LeaveOptions()
	if configMenuInSubcategory and configMenuInOptions then
		configMenuInOptions = false
		OptionsCursorSpriteUp.Color = colorHalf
		OptionsCursorSpriteDown.Color = colorHalf
		
		local hasUsableCategories = false
		if currentMenuCategory.Subcategories then
			for j=1, #currentMenuCategory.Subcategories do
				if currentMenuCategory.Subcategories[j].Name ~= "Uncategorized" then
					hasUsableCategories = true
				end
			end
		end
		
		if not hasUsableCategories then
			ModConfigMenu.LeaveSubcategory()
		end
	end
end

function ModConfigMenu.LeaveSubcategory()
	if configMenuInSubcategory then
		configMenuInSubcategory = false
		SubcategoryCursorSpriteLeft.Color = colorHalf
		SubcategoryCursorSpriteRight.Color = colorHalf
		SubcategoryDividerSprite.Color = colorHalf
	end
end

local mainSpriteColor = colorDefault
local optionsSpriteColor = colorDefault
local optionsSpriteColorAlpha = colorHalf
local mainFontColor = KColor(34/255,32/255,30/255,1)
local leftFontColor = KColor(35/255,31/255,30/255,1)
local leftFontColorSelected = KColor(35/255,50/255,70/255,1)

local optionsFontColor = KColor(34/255,32/255,30/255,1)
local optionsFontColorAlpha = KColor(34/255,32/255,30/255,0.5)
local optionsFontColorNoCursor = KColor(34/255,32/255,30/255,0.8)
local optionsFontColorNoCursorAlpha = KColor(34/255,32/255,30/255,0.4)
local optionsFontColorTitle = KColor(50/255,0,0,1)
local optionsFontColorTitleAlpha = KColor(50/255,0,0,0.5)

local subcategoryFontColor = KColor(34/255,32/255,30/255,1)
local subcategoryFontColorSelected = KColor(34/255,50/255,70/255,1)
local subcategoryFontColorAlpha = KColor(34/255,32/255,30/255,0.5)
local subcategoryFontColorSelectedAlpha = KColor(34/255,50/255,70/255,0.5)

function ModConfigMenu.ConvertDisplayToTextTable(displayValue, lineWidth, font)

	lineWidth = lineWidth or 340

	local textTableDisplay = {}
	if type(displayValue) == "function" then
		displayValue = displayValue()
	end
	
	if type(displayValue) == "string" then
		textTableDisplay = {displayValue}
	elseif type(displayValue) == "table" then
		textTableDisplay = SaveHelper.CopyTable(displayValue)
	else
		textTableDisplay = {tostring(displayValue)}
	end
	
	if type(textTableDisplay) == "string" then
		textTableDisplay = {textTableDisplay}
	end
	
	--create new lines based on $newline modifier
	local textTableDisplayAfterNewlines = {}
	for lineIndex=1, #textTableDisplay do
	
		local line = textTableDisplay[lineIndex]
		local startIdx, endIdx = string.find(line,"$newline")
		while startIdx do

			local newline = string.sub(line, 0, startIdx-1)
			table.insert(textTableDisplayAfterNewlines, newline)
			
			line = string.sub(line, endIdx+1)
			
			startIdx, endIdx = string.find(line,"$newline")
			
		end
		table.insert(textTableDisplayAfterNewlines, line)
		
	end

	--dynamic string new line creation, based on code by wofsauge
	local textTableDisplayAfterWordLength = {}
	for lineIndex=1, #textTableDisplayAfterNewlines do
	
		local line = textTableDisplayAfterNewlines[lineIndex]
		local curLength = 0
		local text = ""
		for word in string.gmatch(tostring(line), "([^%s]+)") do
		
			local wordLength = font:GetStringWidthUTF8(word)

			if curLength + wordLength <= lineWidth or curLength < 12 then
			
				text = text .. word .. " "
				curLength = curLength + wordLength
				
			else
			
				table.insert(textTableDisplayAfterWordLength, text)
				text = word .. " "
				curLength = wordLength
				
			end
			
		end
		table.insert(textTableDisplayAfterWordLength, text)
		
	end
	
	return textTableDisplayAfterWordLength
	
end

--set up screen corner display for hud offset
local HudOffsetVisualTopLeft = ModConfigMenu.GetMenuAnm2Sprite("Offset", 0)
local HudOffsetVisualTopRight = ModConfigMenu.GetMenuAnm2Sprite("Offset", 1)
local HudOffsetVisualBottomRight = ModConfigMenu.GetMenuAnm2Sprite("Offset", 2)
local HudOffsetVisualBottomLeft = ModConfigMenu.GetMenuAnm2Sprite("Offset", 3)

--render the menu
local leftCurrentOffset = 0
local optionsCurrentOffset = 0
ModConfigMenu.ControlsEnabled = true
function ModConfigMenu.PostRender()

	local game = Game()
	local isPaused = game:IsPaused()
	
	local sfx = SFXManager()

	local pressingButton = ""

	local pressingNonRebindableKey = false
	local pressedToggleMenu = false

	local openMenuGlobal = Keyboard.KEY_F10
	local openMenuKeyboard = ModConfigMenu.Config["Mod Config Menu"].OpenMenuKeyboard
	local openMenuController = ModConfigMenu.Config["Mod Config Menu"].OpenMenuController
	
	local takeScreenshot = Keyboard.KEY_F12

	--handle version display on game start
	if versionPrintTimer > 0 then
	
		local bottomRight = ScreenHelper.GetScreenBottomRight(0)

		local openMenuButton = Keyboard.KEY_F10
		if type(ModConfigMenu.Config["Mod Config Menu"].OpenMenuKeyboard) == "number" and ModConfigMenu.Config["Mod Config Menu"].OpenMenuKeyboard > -1 then
			openMenuButton = ModConfigMenu.Config["Mod Config Menu"].OpenMenuKeyboard
		end

		local openMenuButtonString = "Unknown Key"
		if InputHelper.KeyboardToString[openMenuButton] then
			openMenuButtonString = InputHelper.KeyboardToString[openMenuButton]
		end
		
		local text = "按" .. openMenuButtonString .. "打开Mod配置菜单"
		local versionPrintColor = KColor(1, 1, 0, (math.min(versionPrintTimer, 60)/60) * 0.5)
		versionPrintFont:DrawStringUTF8(text, 0, bottomRight.Y - 28, versionPrintColor, bottomRight.X, true)
		
	end
	
	--on-screen warnings
	if restartWarnMessage or rerunWarnMessage then
	
		local bottomRight = ScreenHelper.GetScreenBottomRight(0)
	
		local text = restartWarnMessage or rerunWarnMessage
		local warningPrintColor = KColor(1, 0, 0, 1)
		versionPrintFont:DrawStringUTF8(text, 0, bottomRight.Y - 28, warningPrintColor, bottomRight.X, true)
		
	end

	--handle toggling the menu
	if ModConfigMenu.ControlsEnabled and not isPaused then
	
		for i=0, 4 do
		
			if InputHelper.KeyboardTriggered(openMenuGlobal, i)
			or (openMenuKeyboard > -1 and InputHelper.KeyboardTriggered(openMenuKeyboard, i))
			or (openMenuController > -1 and Input.IsButtonTriggered(openMenuController, i)) then
				pressingNonRebindableKey = true
				pressedToggleMenu = true
				if not configMenuInPopup then
					ModConfigMenu.ToggleConfigMenu()
				end
			end
			
			if InputHelper.KeyboardTriggered(takeScreenshot, i) then
				pressingNonRebindableKey = true
			end
			
		end
		
	end
	
	--force close the menu in some situations
	if ModConfigMenu.IsVisible then
	
		if isPaused then
		
			ModConfigMenu.CloseConfigMenu()
			
		end
		
		if not ModConfigMenu.RoomIsSafe() then
		
			ModConfigMenu.CloseConfigMenu()
			
			sfx:Play(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.75, 0, false, 1)
			
		end
		
	end

	--replace dead sea scrolls' controller setting to not conflict with mcm's
	if DeadSeaScrollsMenu and DeadSeaScrollsMenu.GetGamepadToggleSetting then
	
		local dssControllerToggle = DeadSeaScrollsMenu.GetGamepadToggleSetting()
	
		if DeadSeaScrollsMenu.SaveGamepadToggleSetting then
		
			if openMenuController == Controller.STICK_RIGHT and (dssControllerToggle == 1 or dssControllerToggle == 3 or dssControllerToggle == 4) then
			
				DeadSeaScrollsMenu.SaveGamepadToggleSetting(2) --force revelations' menu to only use the left stick
				
			elseif openMenuController == Controller.STICK_LEFT and (dssControllerToggle == 1 or dssControllerToggle == 2 or dssControllerToggle == 4) then
			
				DeadSeaScrollsMenu.SaveGamepadToggleSetting(3) --force revelations' menu to only use the right stick
				
			end
			
		end
		
	end
	
	if ModConfigMenu.IsVisible then
	
		if ModConfigMenu.ControlsEnabled and not isPaused then
		
			for i=0, game:GetNumPlayers()-1 do
		
				local player = Isaac.GetPlayer(i)
				local data = player:GetData()
				
				--freeze players and disable their controls
				player.Velocity = vecZero
				
				if not data.ConfigMenuPlayerPosition then
					data.ConfigMenuPlayerPosition = player.Position
				end
				player.Position = data.ConfigMenuPlayerPosition
				if not data.ConfigMenuPlayerControlsDisabled then
					player.ControlsEnabled = false
					data.ConfigMenuPlayerControlsDisabled = true
				end
				
				--disable toggling revelations menu
				if data.input and data.input.menu and data.input.menu.toggle then
					data.input.menu.toggle = false
				end
				
			end
			
			if not InputHelper.MultipleButtonTriggered(ignoreActionButtons) then
				--pressing buttons
				local downButtonPressed = InputHelper.MultipleActionTriggered(actionsDown)
				if downButtonPressed then
					pressingButton = "DOWN"
				end
				local upButtonPressed = InputHelper.MultipleActionTriggered(actionsUp)
				if upButtonPressed then
					pressingButton = "UP"
				end
				local rightButtonPressed = InputHelper.MultipleActionTriggered(actionsRight)
				if rightButtonPressed then
					pressingButton = "RIGHT"
				end
				local leftButtonPressed = InputHelper.MultipleActionTriggered(actionsLeft)
				if leftButtonPressed then
					pressingButton = "LEFT"
				end
				local backButtonPressed = InputHelper.MultipleActionTriggered(actionsBack) or InputHelper.MultipleKeyboardTriggered({Keyboard.KEY_BACKSPACE})
				if backButtonPressed then
					pressingButton = "BACK"
					local possiblyPressedButton = InputHelper.MultipleKeyboardTriggered(Keyboard)
					if possiblyPressedButton then
						ModConfigMenu.Config.LastBackPressed = possiblyPressedButton
					end
				end
				local selectButtonPressed = InputHelper.MultipleActionTriggered(actionsSelect)
				if selectButtonPressed then
					pressingButton = "SELECT"
					local possiblyPressedButton = InputHelper.MultipleKeyboardTriggered(Keyboard)
					if possiblyPressedButton then
						ModConfigMenu.Config.LastSelectPressed = possiblyPressedButton
					end
				end
				if ModConfigMenu.Config["Mod Config Menu"].ResetToDefault > -1 and InputHelper.MultipleKeyboardTriggered({ModConfigMenu.Config["Mod Config Menu"].ResetToDefault}) then
					pressingButton = "RESET"
				end
				
				--holding buttons
				if InputHelper.MultipleActionPressed(actionsDown) then
					holdingCounterDown = holdingCounterDown + 1
				else
					holdingCounterDown = 0
				end
				if holdingCounterDown > 20 and holdingCounterDown%5 == 0 then
					pressingButton = "DOWN"
				end
				if InputHelper.MultipleActionPressed(actionsUp) then
					holdingCounterUp = holdingCounterUp + 1
				else
					holdingCounterUp = 0
				end
				if holdingCounterUp > 20 and holdingCounterUp%5 == 0 then
					pressingButton = "UP"
				end
				if InputHelper.MultipleActionPressed(actionsRight) then
					holdingCounterRight = holdingCounterRight + 1
				else
					holdingCounterRight = 0
				end
				if holdingCounterRight > 20 and holdingCounterRight%5 == 0 then
					pressingButton = "RIGHT"
				end
				if InputHelper.MultipleActionPressed(actionsLeft) then
					holdingCounterLeft = holdingCounterLeft + 1
				else
					holdingCounterLeft = 0
				end
				if holdingCounterLeft > 20 and holdingCounterLeft%5 == 0 then
					pressingButton = "LEFT"
				end
			else
				if InputHelper.MultipleButtonTriggered({Controller.BUTTON_B}) then
					pressingButton = "BACK"
					pressingNonRebindableKey = true
				end
				if InputHelper.MultipleButtonTriggered({Controller.BUTTON_A}) then
					pressingButton = "SELECT"
					pressingNonRebindableKey = true
				end
			end
			
			if pressingButton ~= "" then
				pressingNonRebindableKey = true
			end
			
		end
		
		updateCurrentMenuVars()
		
		local lastCursorCategoryPosition = configMenuPositionCursorCategory
		local lastCursorSubcategoryPosition = configMenuPositionCursorSubcategory
		local lastCursorOptionsPosition = configMenuPositionCursorOption
		
		local enterPopup = false
		local leavePopup = false
		
		local optionChanged = false
		
		local enterOptions = false
		local leaveOptions = false
		
		local enterSubcategory = false
		local leaveSubcategory = false
		
		if configMenuInPopup then
		
			if currentMenuOption then
				local optionType = currentMenuOption.Type
				local optionCurrent = currentMenuOption.CurrentSetting
				local optionOnChange = currentMenuOption.OnChange

				if optionType == ModConfigMenu.OptionType.KEYBIND_KEYBOARD
				or optionType == ModConfigMenu.OptionType.KEYBIND_CONTROLLER
				or currentMenuOption.OnSelect then

					if not isPaused then

						if pressingNonRebindableKey
						and not (pressingButton == "BACK"
						or pressingButton == "LEFT"
						or (currentMenuOption.OnSelect and (pressingButton == "SELECT" or pressingButton == "RIGHT"))
						or (currentMenuOption.IsResetKeybind and pressingButton == "RESET")
						or (currentMenuOption.IsOpenMenuKeybind and pressedToggleMenu)) then
							sfx:Play(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.75, 0, false, 1)
						else
							local numberToChange = nil
							local recievedInput = false
							if optionType == ModConfigMenu.OptionType.KEYBIND_KEYBOARD or optionType == ModConfigMenu.OptionType.KEYBIND_CONTROLLER then
								numberToChange = optionCurrent
								
								if type(optionCurrent) == "function" then
									numberToChange = optionCurrent()
								end
								
								if pressingButton == "BACK" or pressingButton == "LEFT" then
									numberToChange = nil
									recievedInput = true
								else
									for i=0, 4 do
										if optionType == ModConfigMenu.OptionType.KEYBIND_KEYBOARD then
											for j=32, 400 do
												if InputHelper.KeyboardTriggered(j, i) then
													numberToChange = j
													recievedInput = true
													break
												end
											end
										else
											for j=0, 31 do
												if Input.IsButtonTriggered(j, i) then
													numberToChange = j
													recievedInput = true
													break
												end
											end
										end
									end
								end
							elseif currentMenuOption.OnSelect then
								if pressingButton == "BACK" or pressingButton == "LEFT" then
									recievedInput = true
								end
								if pressingButton == "SELECT" or pressingButton == "RIGHT" then
									numberToChange = true
									recievedInput = true
								end
							end
							
							if recievedInput then
								if optionType == ModConfigMenu.OptionType.KEYBIND_KEYBOARD or optionType == ModConfigMenu.OptionType.KEYBIND_CONTROLLER then
								
									if type(optionCurrent) == "function" then
										if optionOnChange then
											optionOnChange(numberToChange)
										end
									elseif type(optionCurrent) == "number" then
										currentMenuOption.CurrentSetting = numberToChange
									end
				
									--callback
									CustomCallbackHelper.CallCallbacks
									(
										CustomCallbacks.MCM_POST_MODIFY_SETTING, --callback id
										nil,
										{currentMenuOption.CurrentSetting, numberToChange}, --args to send
										{currentMenuCategory.Name, currentMenuOption.Attribute} --extra variables
									)
									
								elseif currentMenuOption.OnSelect and numberToChange then
									currentMenuOption.OnSelect()
								end
								
								leavePopup = true
								
								local sound = currentMenuOption.Sound
								if not sound then
									sound = SoundEffect.SOUND_PLOP
								end
								if sound >= 0 then
									sfx:Play(sound, 1, 0, false, 1)
								end
							end
						end
					end
				end
			end
			
			if currentMenuOption.Restart or currentMenuOption.Rerun then
			
				--confirmed left press
				if pressingButton == "RIGHT" then
					leavePopup = true
				end
				
				--confirmed back press
				if pressingButton == "SELECT" then
					leavePopup = true
				end
				
			end
			
			--confirmed left press
			if pressingButton == "LEFT" then
				leavePopup = true
			end
			
			--confirmed back press
			if pressingButton == "BACK" then
				leavePopup = true
			end
		elseif configMenuInOptions then
			--confirmed down press
			if pressingButton == "DOWN" then
				configMenuPositionCursorOption = configMenuPositionCursorOption + 1 --move options cursor down
			end
			
			--confirmed up press
			if pressingButton == "UP" then
				configMenuPositionCursorOption = configMenuPositionCursorOption - 1 --move options cursor up
			end
			
			if pressingButton == "SELECT" or pressingButton == "RIGHT" or pressingButton == "LEFT" or (pressingButton == "RESET" and currentMenuOption and currentMenuOption.Default ~= nil) then
				if pressingButton == "LEFT" then
					leaveOptions = true
				end
				
				if currentMenuOption then
					local optionType = currentMenuOption.Type
					local optionCurrent = currentMenuOption.CurrentSetting
					local optionOnChange = currentMenuOption.OnChange
					
					if optionType == ModConfigMenu.OptionType.SCROLL or optionType == ModConfigMenu.OptionType.NUMBER then
						leaveOptions = false
						
						local numberToChange = optionCurrent
						
						if type(optionCurrent) == "function" then
							numberToChange = optionCurrent()
						end
						
						local modifyBy = currentMenuOption.ModifyBy or 1
						modifyBy = math.max(modifyBy,0.001)
						if math.floor(modifyBy) == modifyBy then --force modify by into being an integer instead of a float if it should be
							modifyBy = math.floor(modifyBy)
						end
						
						if pressingButton == "RIGHT" or pressingButton == "SELECT" then
							numberToChange = numberToChange + modifyBy
						elseif pressingButton == "LEFT" then
							numberToChange = numberToChange - modifyBy
						elseif pressingButton == "RESET" and currentMenuOption.Default ~= nil then
							numberToChange = currentMenuOption.Default
							if type(currentMenuOption.Default) == "function" then
								numberToChange = currentMenuOption.Default()
							end
						end
						
						if optionType == ModConfigMenu.OptionType.SCROLL then
							numberToChange = math.max(math.min(math.floor(numberToChange), 10), 0)
						else
							if currentMenuOption.Maximum and numberToChange > currentMenuOption.Maximum then
								if not currentMenuOption.NoLoopFromMaxMin and currentMenuOption.Minimum then
									numberToChange = currentMenuOption.Minimum
								else
									numberToChange = currentMenuOption.Maximum
								end
							end
							if currentMenuOption.Minimum and numberToChange < currentMenuOption.Minimum then
								if not currentMenuOption.NoLoopFromMaxMin and currentMenuOption.Maximum then
									numberToChange = currentMenuOption.Maximum
								else
									numberToChange = currentMenuOption.Minimum
								end
							end
						end
						
						if math.floor(modifyBy) ~= modifyBy then --check if modify by is a float
							numberToChange = math.floor((numberToChange*1000)+0.5)*0.001
						else
							numberToChange = math.floor(numberToChange)
						end
						
						if type(optionCurrent) == "function" then
							if optionOnChange then
								optionOnChange(numberToChange)
							end
							optionChanged = true
						elseif type(optionCurrent) == "number" then
							currentMenuOption.CurrentSetting = numberToChange
							optionChanged = true
						end
	
						--callback
						CustomCallbackHelper.CallCallbacks
						(
							CustomCallbacks.MCM_POST_MODIFY_SETTING, --callback id
							nil,
							{currentMenuOption.CurrentSetting, numberToChange}, --args to send
							{currentMenuCategory.Name, currentMenuOption.Attribute} --extra variables
						)
						
						local sound = currentMenuOption.Sound
						if not sound then
							sound = SoundEffect.SOUND_PLOP
						end
						if sound >= 0 then
							sfx:Play(sound, 1, 0, false, 1)
						end
					elseif optionType == ModConfigMenu.OptionType.BOOLEAN then
						leaveOptions = false
						
						local boolToChange = optionCurrent
						
						if type(optionCurrent) == "function" then
							boolToChange = optionCurrent()
						end
						
						if pressingButton == "RESET" and currentMenuOption.Default ~= nil then
							boolToChange = currentMenuOption.Default
							if type(currentMenuOption.Default) == "function" then
								boolToChange = currentMenuOption.Default()
							end
						else
							boolToChange = (not boolToChange)
						end
						
						if type(optionCurrent) == "function" then
							if optionOnChange then
								optionOnChange(boolToChange)
							end
							optionChanged = true
						elseif type(optionCurrent) == "boolean" then
							currentMenuOption.CurrentSetting = boolToChange
							optionChanged = true
						end
	
						--callback
						CustomCallbackHelper.CallCallbacks
						(
							CustomCallbacks.MCM_POST_MODIFY_SETTING, --callback id
							nil,
							{currentMenuOption.CurrentSetting, boolToChange}, --args to send
							{currentMenuCategory.Name, currentMenuOption.Attribute} --extra variables
						)
						
						local sound = currentMenuOption.Sound
						if not sound then
							sound = SoundEffect.SOUND_PLOP
						end
						if sound >= 0 then
							sfx:Play(sound, 1, 0, false, 1)
						end
					elseif (optionType == ModConfigMenu.OptionType.KEYBIND_KEYBOARD or optionType == ModConfigMenu.OptionType.KEYBIND_CONTROLLER) and pressingButton == "RESET" and currentMenuOption.Default ~= nil then
						local numberToChange = optionCurrent
						
						if type(optionCurrent) == "function" then
							numberToChange = optionCurrent()
						end
						
						numberToChange = currentMenuOption.Default
						if type(currentMenuOption.Default) == "function" then
							numberToChange = currentMenuOption.Default()
						end
						
						if type(optionCurrent) == "function" then
							if optionOnChange then
								optionOnChange(numberToChange)
							end
							optionChanged = true
						elseif type(optionCurrent) == "number" then
							currentMenuOption.CurrentSetting = numberToChange
							optionChanged = true
						end
	
						--callback
						CustomCallbackHelper.CallCallbacks
						(
							CustomCallbacks.MCM_POST_MODIFY_SETTING, --callback id
							nil,
							{currentMenuOption.CurrentSetting, numberToChange}, --args to send
							{currentMenuCategory.Name, currentMenuOption.Attribute} --extra variables
						)
						
						local sound = currentMenuOption.Sound
						if not sound then
							sound = SoundEffect.SOUND_PLOP
						end
						if sound >= 0 then
							sfx:Play(sound, 1, 0, false, 1)
						end
					elseif optionType ~= ModConfigMenu.OptionType.SPACE and pressingButton == "RIGHT" then
						if currentMenuOption.Popup then
							enterPopup = true
						elseif currentMenuOption.OnSelect then
							currentMenuOption.OnSelect()
						end
					end
				end
			end
			
			--confirmed back press
			if pressingButton == "BACK" then
				leaveOptions = true
			end
			
			--confirmed select press
			if pressingButton == "SELECT" then
				if currentMenuOption then
					if currentMenuOption.Popup then
						enterPopup = true
					elseif currentMenuOption.OnSelect then
						currentMenuOption.OnSelect()
					end
				end
			end
			
			--reset command
			if optionChanged then
				if currentMenuOption.Restart or currentMenuOption.Rerun then
					enterPopup = true
				end
			end
		elseif configMenuInSubcategory then
			local hasUsableCategories = false
			if currentMenuCategory.Subcategories then
				for j=1, #currentMenuCategory.Subcategories do
					if currentMenuCategory.Subcategories[j].Name ~= "Uncategorized" then
						hasUsableCategories = true
					end
				end
			end
			if hasUsableCategories then
				--confirmed down press
				if pressingButton == "DOWN" then
					enterOptions = true
				end
				
				--confirmed up press
				if pressingButton == "UP" then
					leaveSubcategory = true
				end
				
				--confirmed right press
				if pressingButton == "RIGHT" then
					configMenuPositionCursorSubcategory = configMenuPositionCursorSubcategory + 1 --move right down
				end
				
				--confirmed left press
				if pressingButton == "LEFT" then
					configMenuPositionCursorSubcategory = configMenuPositionCursorSubcategory - 1 --move cursor left
				end
				
				--confirmed back press
				if pressingButton == "BACK" then
					leaveSubcategory = true
				end
				
				--confirmed select press
				if pressingButton == "SELECT" then
					enterOptions = true
				end
			end
		else
			--confirmed down press
			if pressingButton == "DOWN" then
				configMenuPositionCursorCategory = configMenuPositionCursorCategory + 1 --move left cursor down
			end
			
			--confirmed up press
			if pressingButton == "UP" then
				configMenuPositionCursorCategory = configMenuPositionCursorCategory - 1 --move left cursor up
			end
			
			--confirmed right press
			if pressingButton == "RIGHT" then
				enterSubcategory = true
			end
			
			--confirmed back press
			if pressingButton == "BACK" then
				ModConfigMenu.CloseConfigMenu()
			end
			
			--confirmed select press
			if pressingButton == "SELECT" then
				enterSubcategory = true
			end
		end
		
		--entering popup
		if enterPopup then
			ModConfigMenu.EnterPopup()
		end
		
		--leaving popup
		if leavePopup then
			ModConfigMenu.LeavePopup()
		end
		
		--entering subcategory
		if enterSubcategory then
			ModConfigMenu.EnterSubcategory()
		end
		
		--entering options
		if enterOptions then
			ModConfigMenu.EnterOptions()
		end
		
		--leaving options
		if leaveOptions then
			ModConfigMenu.LeaveOptions()
		end
		
		--leaving subcategory
		if leaveSubcategory then
			ModConfigMenu.LeaveSubcategory()
		end
		
		--category cursor position was changed
		if lastCursorCategoryPosition ~= configMenuPositionCursorCategory then
			if not configMenuInSubcategory then
			
				--cursor position
				if configMenuPositionCursorCategory < 1 then --move from the top of the list to the bottom
					configMenuPositionCursorCategory = #ModConfigMenu.MenuData
				end
				if configMenuPositionCursorCategory > #ModConfigMenu.MenuData then --move from the bottom of the list to the top
					configMenuPositionCursorCategory = 1
				end
				
				--make sure subcategory and option positions are 1
				configMenuPositionCursorSubcategory = 1
				configMenuPositionFirstSubcategory = 1
				configMenuPositionCursorOption = 1
				optionsCurrentOffset = 0
				
			end
		end
		
		--subcategory cursor position was changed
		if lastCursorSubcategoryPosition ~= configMenuPositionCursorSubcategory then
			if not configMenuInOptions then
			
				--cursor position
				if configMenuPositionCursorSubcategory < 1 then --move from the top of the list to the bottom
					configMenuPositionCursorSubcategory = #currentMenuCategory.Subcategories
				end
				if configMenuPositionCursorSubcategory > #currentMenuCategory.Subcategories then --move from the bottom of the list to the top
					configMenuPositionCursorSubcategory = 1
				end
				
				--first category selection to render
				if configMenuPositionFirstSubcategory > 1 and configMenuPositionCursorSubcategory <= configMenuPositionFirstSubcategory+1 then
					configMenuPositionFirstSubcategory = configMenuPositionCursorSubcategory-1
				end
				if configMenuPositionFirstSubcategory+(configMenuSubcategoriesCanShow-1) < #currentMenuCategory.Subcategories and configMenuPositionCursorSubcategory >= 1+(configMenuSubcategoriesCanShow-2) then
					configMenuPositionFirstSubcategory = configMenuPositionCursorSubcategory-(configMenuSubcategoriesCanShow-2)
				end
				configMenuPositionFirstSubcategory = math.min(math.max(configMenuPositionFirstSubcategory, 1), #currentMenuCategory.Subcategories-(configMenuSubcategoriesCanShow-1))
				
				--make sure option positions are 1
				configMenuPositionCursorOption = 1
				optionsCurrentOffset = 0
				
			end
		end
		
		--options cursor position was changed
		if lastCursorOptionsPosition ~= configMenuPositionCursorOption then
			if configMenuInOptions
			and currentMenuSubcategory
			and currentMenuSubcategory.Options
			and #currentMenuSubcategory.Options > 0 then
				
				--find next valid option that isn't a space
				local nextValidOptionSelection = configMenuPositionCursorOption
				local optionIndex = configMenuPositionCursorOption
				for i=1, #currentMenuSubcategory.Options*2 do
				
					local thisOption = currentMenuSubcategory.Options[optionIndex]
					
					if thisOption
					and thisOption.Type
					and thisOption.Type ~= ModConfigMenu.OptionType.SPACE
					and (not thisOption.NoCursorHere or (type(thisOption.NoCursorHere) == "function" and not thisOption.NoCursorHere()))
					and thisOption.Display then
						
						nextValidOptionSelection = optionIndex
						
						break
					end
					
					if configMenuPositionCursorOption > lastCursorOptionsPosition then
						optionIndex = optionIndex + 1
					elseif configMenuPositionCursorOption < lastCursorOptionsPosition then
						optionIndex = optionIndex - 1
					end
					if optionIndex < 1 then
						optionIndex = #currentMenuSubcategory.Options
					end
					if optionIndex > #currentMenuSubcategory.Options then
						optionIndex = 1
					end
				end
				
				configMenuPositionCursorOption = nextValidOptionSelection
				
				updateCurrentMenuVars()
				
				--first options selection to render
				local hasSubcategories = false
				for j=1, #currentMenuCategory.Subcategories do
					if currentMenuCategory.Subcategories[j].Name ~= "Uncategorized" then
						hasSubcategories = true
					end
				end
				if hasSubcategories then
					--todo
				end
				
			end
		end
		
		local centerPos = ScreenHelper.GetScreenCenter()
		
		--title pos handling
		local titlePos = centerPos + Vector(68,-118)
		
		--left pos handling
		
		local leftDesiredOffset = 0
		local leftCanScrollUp = false
		local leftCanScrollDown = false
		
		local numLeft = #ModConfigMenu.MenuData
		
		local leftPos = centerPos + Vector(-142,-102)
		local leftPosTopmost = centerPos.Y - 116
		local leftPosBottommost = centerPos.Y + 90
		
		if numLeft > 7 then
		
			if configMenuPositionCursorCategory > 6 then
			
				leftCanScrollUp = true
				
				local cursorScroll = configMenuPositionCursorCategory - 6
				local maxLeftScroll = numLeft - 8
				leftDesiredOffset = math.min(cursorScroll, maxLeftScroll) * -14
				
				if cursorScroll < maxLeftScroll then
					leftCanScrollDown = true
				end
			
			else
		
				leftCanScrollDown = true
			
			end
			
		end

		if leftDesiredOffset ~= leftCurrentOffset then
		
			local modifyOffset = math.floor(leftDesiredOffset - leftCurrentOffset)/10
			if modifyOffset > -0.1 and modifyOffset < 0 then
				modifyOffset = -0.1
			end
			if modifyOffset < 0.1 and modifyOffset > 0 then
				modifyOffset = 0.1
			end
			
			leftCurrentOffset = leftCurrentOffset + modifyOffset
			if (leftDesiredOffset - leftCurrentOffset) < 0.25 and (leftDesiredOffset - leftCurrentOffset) > -0.25 then
				leftCurrentOffset = leftDesiredOffset
			end
			
		end
		
		if leftCurrentOffset ~= 0 then
			leftPos = leftPos + Vector(0, leftCurrentOffset)
		end
		
		--options pos handling
		local optionsDesiredOffset = 0
		local optionsCanScrollUp = false
		local optionsCanScrollDown = false
		
		local numOptions = 0
		
		local optionPos = centerPos + Vector(68,-18)
		local optionPosTopmost = centerPos.Y - 108
		local optionPosBottommost = centerPos.Y + 86
		
		if currentMenuSubcategory
		and currentMenuSubcategory.Options
		and #currentMenuSubcategory.Options > 0 then
			
			numOptions = #currentMenuSubcategory.Options
		
			local hasSubcategories = false
			if currentMenuCategory.Subcategories then
				for j=1, #currentMenuCategory.Subcategories do
					if currentMenuCategory.Subcategories[j].Name ~= "Uncategorized" then
						numOptions = numOptions + 2
						hasSubcategories = true
						break
					end
				end
			end
			
			if hasSubcategories then
				optionPos = optionPos + Vector(0, -70)
			else
				optionPos = optionPos + Vector(0, math.min(numOptions-1, 10) * -7)
			end
			
			if numOptions > 12 then
			
				if configMenuPositionCursorOption > 6 and configMenuInOptions then
				
					optionsCanScrollUp = true
					
					local cursorScroll = configMenuPositionCursorOption - 6
					local maxOptionsScroll = numOptions - 12
					optionsDesiredOffset = math.min(cursorScroll, maxOptionsScroll) * -14
					
					if cursorScroll < maxOptionsScroll then
						optionsCanScrollDown = true
					end
				
				else
			
					optionsCanScrollDown = true
				
				end
				
			end
			
		end
	
		if optionsDesiredOffset ~= optionsCurrentOffset then
		
			local modifyOffset = math.floor(optionsDesiredOffset - optionsCurrentOffset)/10
			if modifyOffset > -0.1 and modifyOffset < 0 then
				modifyOffset = -0.1
			end
			if modifyOffset < 0.1 and modifyOffset > 0 then
				modifyOffset = 0.1
			end
			
			optionsCurrentOffset = optionsCurrentOffset + modifyOffset
			if (optionsDesiredOffset - optionsCurrentOffset) < 0.25 and (optionsDesiredOffset - optionsCurrentOffset) > -0.25 then
				optionsCurrentOffset = optionsDesiredOffset
			end
			
		end
		
		if optionsCurrentOffset ~= 0 then
			optionPos = optionPos + Vector(0, optionsCurrentOffset)
		end
		
		--info pos handling
		local infoPos = centerPos + Vector(-4,106)
	
		MenuSprite:Render(centerPos, vecZero, vecZero)
		
		--get if controls can be shown
		local shouldShowControls = true
		if configMenuInOptions and currentMenuOption and currentMenuOption.HideControls then
			shouldShowControls = false
		end
		if not ModConfigMenu.Config["Mod Config Menu"].ShowControls then
			shouldShowControls = false
		end
		
		--category
		local lastLeftPos = leftPos
		local renderedLeft = 0
		for categoryIndex=1, #ModConfigMenu.MenuData do
		
			--text
			if lastLeftPos.Y > leftPosTopmost and lastLeftPos.Y < leftPosBottommost then
			
				local textToDraw = tostring(ModConfigMenu.MenuData[categoryIndex].NameTranslate or ModConfigMenu.MenuData[categoryIndex].Name)
				
				local color = leftFontColor
				--[[
				if configMenuPositionCursorCategory == categoryIndex then
					color = leftFontColorSelected
				end
				]]
				
				local posOffset = Font12:GetStringWidthUTF8(textToDraw)/2
				Font12:DrawStringUTF8(textToDraw, lastLeftPos.X - posOffset, lastLeftPos.Y - 8, color, 0, true)
				
				--cursor
				if configMenuPositionCursorCategory == categoryIndex then
					CursorSpriteRight:Render(lastLeftPos + Vector((posOffset + 10)*-1,0), vecZero, vecZero)
				end
				
			end
			
			--increase counter
			renderedLeft = renderedLeft + 1
			
			--pos mod
			lastLeftPos = lastLeftPos + Vector(0,16)
			
		end
		
		--render scroll arrows
		if leftCanScrollUp then
			CursorSpriteUp:Render(centerPos + Vector(-78,-104), vecZero, vecZero) --up arrow
		end
		if leftCanScrollDown then
			CursorSpriteDown:Render(centerPos + Vector(-78,70), vecZero, vecZero) --down arrow
		end
		
		------------------------
		--RENDER SUBCATEGORIES--
		------------------------
		
		local lastOptionPos = optionPos
		local renderedOptions = 0
		
		if currentMenuCategory then
		
			local hasUncategorizedCategory = false
			local hasSubcategories = false
			local numCategories = 0
			for j=1, #currentMenuCategory.Subcategories do
				if currentMenuCategory.Subcategories[j].Name == "Uncategorized" then
					hasUncategorizedCategory = true
				else
					hasSubcategories = true
					numCategories = numCategories + 1
				end
			end
			
			if hasSubcategories then
				
				if hasUncategorizedCategory then
					numCategories = numCategories + 1
				end
				
				if lastOptionPos.Y > optionPosTopmost and lastOptionPos.Y < optionPosBottommost then
				
					local lastSubcategoryPos = optionPos
					if numCategories == 2 then
						lastSubcategoryPos = lastOptionPos + Vector(-38,0)
					elseif numCategories >= 3 then
						lastSubcategoryPos = lastOptionPos + Vector(-76,0)
					end
				
					local renderedSubcategories = 0
				
					for subcategoryIndex=1, #currentMenuCategory.Subcategories do
					
						if subcategoryIndex >= configMenuPositionFirstSubcategory then
						
							local thisSubcategory = currentMenuCategory.Subcategories[subcategoryIndex]
							
							local posOffset = 0
						
							if thisSubcategory.Name then
								local textToDraw = thisSubcategory.NameTranslate or thisSubcategory.Name
								
								textToDraw = tostring(textToDraw)
								
								local color = subcategoryFontColor
								if not configMenuInSubcategory then
									color = subcategoryFontColorAlpha
								--[[
								elseif configMenuPositionCursorSubcategory == subcategoryIndex and configMenuInSubcategory then
									color = subcategoryFontColorSelected
								]]
								end
								
								posOffset = Font12:GetStringWidthUTF8(textToDraw)/2
								Font12:DrawStringUTF8(textToDraw, lastSubcategoryPos.X - posOffset, lastSubcategoryPos.Y - 8, color, 0, true)
							end
							
							--cursor
							if configMenuPositionCursorSubcategory == subcategoryIndex and configMenuInSubcategory then
								CursorSpriteRight:Render(lastSubcategoryPos + Vector((posOffset + 10)*-1,0), vecZero, vecZero)
							end
							
							--increase counter
							renderedSubcategories = renderedSubcategories + 1
						
							if renderedSubcategories >= configMenuSubcategoriesCanShow then --if this is the last one we should render
							
								--render scroll arrows
								if configMenuPositionFirstSubcategory > 1 then --if the first one we rendered wasnt the first in the list
									SubcategoryCursorSpriteLeft:Render(lastOptionPos + Vector(-125,0), vecZero, vecZero)
								end
								
								if subcategoryIndex < #currentMenuCategory.Subcategories then --if this isnt the last thing
									SubcategoryCursorSpriteRight:Render(lastOptionPos + Vector(125,0), vecZero, vecZero)
								end
								
								break
								
							end
						
							--pos mod
							lastSubcategoryPos = lastSubcategoryPos + Vector(76,0)
						
						end
						
					end
				
				end
				
				--subcategory selection counts as an option that gets rendered
				renderedOptions = renderedOptions + 1
				lastOptionPos = lastOptionPos + Vector(0,14)
				
				--subcategory to options divider
				if lastOptionPos.Y > optionPosTopmost and lastOptionPos.Y < optionPosBottommost then
				
					SubcategoryDividerSprite:Render(lastOptionPos, vecZero, vecZero)
					
				end
				
				--subcategory to options divider counts as an option that gets rendered
				renderedOptions = renderedOptions + 1
				lastOptionPos = lastOptionPos + Vector(0,14)

			end
		end
		
		------------------
		--RENDER OPTIONS--
		------------------
		
		local firstOptionPos = lastOptionPos
		
		if currentMenuSubcategory
		and currentMenuSubcategory.Options
		and #currentMenuSubcategory.Options > 0 then
		
			for optionIndex=1, #currentMenuSubcategory.Options do
				
				local thisOption = currentMenuSubcategory.Options[optionIndex]
				
				local cursorIsAtThisOption = configMenuPositionCursorOption == optionIndex and configMenuInOptions
				local posOffset = 10
				
				if lastOptionPos.Y > optionPosTopmost and lastOptionPos.Y < optionPosBottommost then
					
					if thisOption.Type
					and thisOption.Type ~= ModConfigMenu.OptionType.SPACE
					and thisOption.Display then
					
						local optionType = thisOption.Type
						local optionDisplay = thisOption.DisplayTranslate or thisOption.Display
						local optionColor = thisOption.Color
		
						local useAltSlider = thisOption.AltSlider
						
						--get what to draw
						if optionType == ModConfigMenu.OptionType.TEXT
						or optionType == ModConfigMenu.OptionType.BOOLEAN
						or optionType == ModConfigMenu.OptionType.NUMBER
						or optionType == ModConfigMenu.OptionType.KEYBIND_KEYBOARD
						or optionType == ModConfigMenu.OptionType.KEYBIND_CONTROLLER
						or optionType == ModConfigMenu.OptionType.TITLE then
							local textToDraw = optionDisplay
							
							if type(optionDisplay) == "function" then
								textToDraw = optionDisplay(cursorIsAtThisOption, configMenuInOptions, lastOptionPos)
							end
							
							textToDraw = tostring(textToDraw)
							
							local heightOffset = 6
							local font = Font10
							local color = optionsFontColor
							if not configMenuInOptions then
								if thisOption.NoCursorHere then
									color = optionsFontColorNoCursorAlpha
								else
									color = optionsFontColorAlpha
								end
							elseif thisOption.NoCursorHere then
								color = optionsFontColorNoCursor
							end
							if optionType == ModConfigMenu.OptionType.TITLE then
								heightOffset = 8
								font = Font12
								color = optionsFontColorTitle
								if not configMenuInOptions then
									color = optionsFontColorTitleAlpha
								end
							end
							
							if optionColor then
								color = KColor(optionColor[1], optionColor[2], optionColor[3], color.A)
							end
							
							posOffset = font:GetStringWidthUTF8(textToDraw)/2
							font:DrawStringUTF8(textToDraw, lastOptionPos.X - posOffset, lastOptionPos.Y - heightOffset, color, 0, true)
						elseif optionType == ModConfigMenu.OptionType.SCROLL then
							local numberToShow = optionDisplay
							
							if type(optionDisplay) == "function" then
								numberToShow = optionDisplay(cursorIsAtThisOption, configMenuInOptions, lastOptionPos)
							end
							
							posOffset = 31
							local scrollOffset = 0
							
							if type(numberToShow) == "number" then
								numberToShow = math.max(math.min(math.floor(numberToShow), 10), 0)
							elseif type(numberToShow) == "string" then
								local numberToShowStart, numberToShowEnd = string.find(numberToShow, "$scroll")
								if numberToShowStart and numberToShowEnd then
									local numberStart = numberToShowEnd+1
									local numberEnd = numberToShowEnd+3
									local numberString = string.sub(numberToShow, numberStart, numberEnd)
									numberString = tonumber(numberString)
									if not numberString or (numberString and not type(numberString) == "number") or (numberString and type(numberString) == "number" and numberString < 10) then
										numberEnd = numberEnd-1
										numberString = string.sub(numberToShow, numberStart, numberEnd)
										numberString = tonumber(numberString)
									end
									if numberString and type(numberString) == "number" then
										local textToDrawPreScroll = string.sub(numberToShow, 0, numberToShowStart-1)
										local textToDrawPostScroll = string.sub(numberToShow, numberEnd, string.len(numberToShow))
										local textToDraw = textToDrawPreScroll .. "               " .. textToDrawPostScroll
										
										local color = optionsFontColor
										if not configMenuInOptions then
											color = optionsFontColorAlpha
										end
										if optionColor then
											color = KColor(optionColor[1], optionColor[2], optionColor[3], color.A)
										end
										
										scrollOffset = posOffset
										posOffset = Font10:GetStringWidthUTF8(textToDraw)/2
										Font10:DrawStringUTF8(textToDraw, lastOptionPos.X - posOffset, lastOptionPos.Y - 6, color, 0, true)
										
										scrollOffset = posOffset - (Font10:GetStringWidthUTF8(textToDrawPreScroll)+scrollOffset)
										numberToShow = numberString
									end
								end
							end
							
							local scrollColor = optionsSpriteColor
							if not configMenuInOptions then
								scrollColor = optionsSpriteColorAlpha
							end
							if optionColor then
								scrollColor = Color(optionColor[1], optionColor[2], optionColor[3], scrollColor.A, scrollColor.RO, scrollColor.GO, scrollColor.BO)
							end
							
							local sliderString = "Slider1"
							if useAltSlider then
								sliderString = "Slider2"
							end
							
							SliderSprite.Color = scrollColor
							SliderSprite:SetFrame(sliderString, numberToShow)
							SliderSprite:Render(lastOptionPos - Vector(scrollOffset, -2), vecZero, vecZero)
							
						end
						
						local showStrikeout = thisOption.ShowStrikeout
						if posOffset > 0 and (type(showStrikeout) == boolean and showStrikeout == true) or (type(showStrikeout) == "function" and showStrikeout() == true) then
							if configMenuInOptions then
								StrikeOutSprite.Color = colorDefault
							else
								StrikeOutSprite.Color = colorHalf
							end
							StrikeOutSprite:SetFrame("Strikeout", math.floor(posOffset))
							StrikeOutSprite:Render(lastOptionPos, vecZero, vecZero)
						end
					end
					
					--cursor
					if cursorIsAtThisOption then
						CursorSpriteRight:Render(lastOptionPos + Vector((posOffset + 10)*-1,0), vecZero, vecZero)
					end
				
				end
				
				--increase counter
				renderedOptions = renderedOptions + 1
				
				--pos mod
				lastOptionPos = lastOptionPos + Vector(0,14)
				
			end
			
			--render scroll arrows
			if optionsCanScrollUp then
				OptionsCursorSpriteUp:Render(centerPos + Vector(193,-86), vecZero, vecZero) --up arrow
			end
			if optionsCanScrollDown then
			
				local yPos = 66
				if shouldShowControls then
					yPos = 40
				end
				
				OptionsCursorSpriteDown:Render(centerPos + Vector(193,yPos), vecZero, vecZero) --down arrow
				
			end
		
		end
		
		MenuOverlaySprite:Render(centerPos, vecZero, vecZero)
		
		--title
		local titleText = "mod配置菜单" -- "Mod Config Menu"
		if configMenuInSubcategory then
			titleText = tostring(currentMenuCategory.NameTranslate or currentMenuCategory.Name)
		end
		local titleTextOffset = Font16Bold:GetStringWidthUTF8(titleText)/2
		Font16Bold:DrawStringUTF8(titleText, titlePos.X - titleTextOffset, titlePos.Y - 9, mainFontColor, 0, true)
		
		--info
		local infoTable = nil
		local isOldInfo = false
		
		if configMenuInOptions then
		
			if currentMenuOption and currentMenuOption.Info then
				infoTable = currentMenuOption.InfoTranslate or currentMenuOption.Info
			end
			
		elseif configMenuInSubcategory then
		
			if currentMenuSubcategory and currentMenuSubcategory.Info then
				infoTable = currentMenuSubcategory.InfoTranslate or currentMenuSubcategory.Info
			end
			
		elseif currentMenuCategory and currentMenuCategory.Info then
			
			infoTable = currentMenuCategory.InfoTranslate or currentMenuCategory.Info
			if currentMenuCategory.IsOld then
				isOldInfo = true
			end
			
		end
		
		if infoTable then
			
			local lineWidth = 340
			if shouldShowControls then
				lineWidth = 260
			end
			
			local infoTableDisplay = ModConfigMenu.ConvertDisplayToTextTable(infoTable, lineWidth, Font10)
			
			local lastInfoPos = infoPos - Vector(0,6*#infoTableDisplay)
			for line=1, #infoTableDisplay do
			
				--text
				local textToDraw = tostring(infoTableDisplay[line])
				local posOffset = Font10:GetStringWidthUTF8(textToDraw)/2
				local color = mainFontColor
				if isOldInfo then
					color = optionsFontColorTitle
				end
				Font10:DrawStringUTF8(textToDraw, lastInfoPos.X - posOffset, lastInfoPos.Y - 6, color, 0, true)
				
				--pos mod
				lastInfoPos = lastInfoPos + Vector(0,Font10:GetLineHeight())
				
			end
			
		end
		
		--hud offset
		if configMenuInOptions
		and currentMenuOption
		and currentMenuOption.ShowOffset
		and ScreenHelper then
		
			--render the visual
			HudOffsetVisualBottomRight:Render(ScreenHelper.GetScreenBottomRight(), vecZero, vecZero)
			HudOffsetVisualBottomLeft:Render(ScreenHelper.GetScreenBottomLeft(), vecZero, vecZero)
			HudOffsetVisualTopRight:Render(ScreenHelper.GetScreenTopRight(), vecZero, vecZero)
			HudOffsetVisualTopLeft:Render(ScreenHelper.GetScreenTopLeft(), vecZero, vecZero)
			
		end
		
		--popup
		if configMenuInPopup
		and currentMenuOption
		and (currentMenuOption.Popup or currentMenuOption.Restart or currentMenuOption.Rerun) then
		
			PopupSprite:Render(centerPos, vecZero, vecZero)
			
			local popupTable = currentMenuOption.PopupTranslate or currentMenuOption.Popup
			
			if not popupTable then
			
				if currentMenuOption.Restart then
				
					popupTable = "Restart the game for this setting to take effect"
				
				end
			
				if currentMenuOption.Rerun then
				
					popupTable = "Start a new run for this setting to take effect"
				
				end
				
			end
			
			if popupTable then
				
				local lineWidth = currentMenuOption.PopupWidth or 180
				
				local popupTableDisplay = ModConfigMenu.ConvertDisplayToTextTable(popupTable, lineWidth, Font10)
				
				local lastPopupPos = (centerPos + Vector(0,2)) - Vector(0,6*#popupTableDisplay)
				for line=1, #popupTableDisplay do
				
					--text
					local textToDraw = tostring(popupTableDisplay[line])
					local posOffset = Font10:GetStringWidthUTF8(textToDraw)/2
					Font10:DrawStringUTF8(textToDraw, lastPopupPos.X - posOffset, lastPopupPos.Y - 6, mainFontColor, 0, true)
					
					--pos mod
					lastPopupPos = lastPopupPos + Vector(0,Font10:GetLineHeight())
					
				end
			
			end
			
		end
		
		--controls
		if shouldShowControls then

			--back
			local bottomLeft = ScreenHelper.GetScreenBottomLeft(0)
			if not configMenuInSubcategory then
				CornerExit:Render(bottomLeft, vecZero, vecZero)
			else
				CornerBack:Render(bottomLeft, vecZero, vecZero)
			end

			local goBackString = ""
			if ModConfigMenu.Config.LastBackPressed then
				if InputHelper.KeyboardToString[ModConfigMenu.Config.LastBackPressed] then
					goBackString = InputHelper.KeyboardToString[ModConfigMenu.Config.LastBackPressed]
				elseif InputHelper.ControllerToString[ModConfigMenu.Config.LastBackPressed] then
					goBackString = InputHelper.ControllerToString[ModConfigMenu.Config.LastBackPressed]
				end
			end
			Font10:DrawStringUTF8(goBackString, (bottomLeft.X - Font10:GetStringWidthUTF8(goBackString)/2) + 36, bottomLeft.Y - 24, mainFontColor, 0, true)

			--select
			local bottomRight = ScreenHelper.GetScreenBottomRight(0)
			if not configMenuInPopup then
			
				local foundValidPopup = false
				--[[
				if configMenuInSubcategory
				and configMenuInOptions
				and currentMenuOption
				and currentMenuOption.Type
				and currentMenuOption.Type ~= ModConfigMenu.OptionType.SPACE
				and currentMenuOption.Popup then
					foundValidPopup = true
				end
				]]
				
				if foundValidPopup then
					CornerOpen:Render(bottomRight, vecZero, vecZero)
				else
					CornerSelect:Render(bottomRight, vecZero, vecZero)
				end
				
				local selectString = ""
				if ModConfigMenu.Config.LastSelectPressed then
					if InputHelper.KeyboardToString[ModConfigMenu.Config.LastSelectPressed] then
						selectString = InputHelper.KeyboardToString[ModConfigMenu.Config.LastSelectPressed]
					elseif InputHelper.ControllerToString[ModConfigMenu.Config.LastSelectPressed] then
						selectString = InputHelper.ControllerToString[ModConfigMenu.Config.LastSelectPressed]
					end
				end
				Font10:DrawStringUTF8(selectString, (bottomRight.X - Font10:GetStringWidthUTF8(selectString)/2) - 36, bottomRight.Y - 24, mainFontColor, 0, true)
				
			end
			
		end
		
	else
	
		for i=0, game:GetNumPlayers()-1 do
		
			local player = Isaac.GetPlayer(i)
			local data = player:GetData()
			
			--enable player controls
			if data.ConfigMenuPlayerPosition then
				data.ConfigMenuPlayerPosition = nil
			end
			if data.ConfigMenuPlayerControlsDisabled then
				player.ControlsEnabled = true
				data.ConfigMenuPlayerControlsDisabled = false
			end
			
		end
		
		for _, entity in pairs(Isaac.GetRoomEntities()) do
			if entity.Type == EntityType.ENTITY_DARK_ESAU then
				local data = entity:ToNPC():GetData()
				data.ConfigMenuEsauPosition = nil
				data.ConfigMenuEsauVelocity = nil
			end
		end

		configMenuInSubcategory = false
		configMenuInOptions = false
		configMenuInPopup = false
		
		holdingCounterDown = 0
		holdingCounterUp = 0
		holdingCounterLeft = 0
		holdingCounterRight = 0
		
		configMenuPositionCursorCategory = 1
		configMenuPositionCursorSubcategory = 1
		configMenuPositionCursorOption = 1
		
		configMenuPositionFirstSubcategory = 1
		
		leftCurrentOffset = 0
		optionsCurrentOffset = 0
		
	end
end
ModConfigMenu.Mod:AddCallback(ModCallbacks.MC_POST_RENDER, ModConfigMenu.PostRender)

function ModConfigMenu.OpenConfigMenu()

	if ModConfigMenu.RoomIsSafe() then
	
		if ModConfigMenu.Config["Mod Config Menu"].HideHudInMenu then
		
			local game = Game()
			local seeds = game:GetSeeds()
			seeds:AddSeedEffect(SeedEffect.SEED_NO_HUD)
			
		end
		
		ModConfigMenu.IsVisible = true
		
	else
	
		local sfx = SFXManager()
		sfx:Play(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.75, 0, false, 1)
		
	end
	
end

function ModConfigMenu.CloseConfigMenu()

	ModConfigMenu.LeavePopup()
	ModConfigMenu.LeaveOptions()
	ModConfigMenu.LeaveSubcategory()
	
	local game = Game()
	local seeds = game:GetSeeds()
	seeds:RemoveSeedEffect(SeedEffect.SEED_NO_HUD)
	
	
	ModConfigMenu.IsVisible = false
	
end

function ModConfigMenu.ToggleConfigMenu()
	if ModConfigMenu.IsVisible then
		ModConfigMenu.CloseConfigMenu()
	else
		ModConfigMenu.OpenConfigMenu()
	end
end

function ModConfigMenu.InputAction(_, entity, inputHook, buttonAction)

	if ModConfigMenu.IsVisible and buttonAction ~= ButtonAction.ACTION_FULLSCREEN and buttonAction ~= ButtonAction.ACTION_CONSOLE then
	
		if inputHook == InputHook.IS_ACTION_PRESSED or inputHook == InputHook.IS_ACTION_TRIGGERED then 
			return false
		else
			return 0
		end
		
	end
	
end
ModConfigMenu.Mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, ModConfigMenu.InputAction)

function ModConfigMenu.DarkEsauPreNpcUpdate(_, entityNPC)
	if ModConfigMenu.IsVisible then
		local data = entityNPC:GetData()
		if not data.ConfigMenuEsauPosition then
			data.ConfigMenuEsauPosition = entityNPC.Position
			data.ConfigMenuEsauVelocity = entityNPC.Velocity
		end
		entityNPC.Position = data.ConfigMenuEsauPosition
		entityNPC.Velocity = data.ConfigMenuEsauVelocity
		return true
	end
end

ModConfigMenu.Mod:AddCallback(ModCallbacks.MC_PRE_NPC_UPDATE,ModConfigMenu.DarkEsauPreNpcUpdate, EntityType.ENTITY_DARK_ESAU)

--console commands that toggle the menu
local toggleCommands = {
	["modconfigmenu"] = true,
	["modconfig"] = true,
	["mcm"] = true,
	["mc"] = true
}
function ModConfigMenu.ExecuteCmd(_, command, args)

	command = command:lower()
	
	if toggleCommands[command] then
	
		ModConfigMenu.ToggleConfigMenu()
		
	end
	
end
ModConfigMenu.Mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, ModConfigMenu.ExecuteCmd)

if ModConfigMenu.StandaloneMod then

	if not ModConfigMenu.StandaloneSaveLoaded then
		SaveHelper.Load(ModConfigMenu.StandaloneMod)
		ModConfigMenu.StandaloneSaveLoaded = true
	end
	
	if not ModConfigMenu.CompatibilityMode then
		dofile("scripts/modconfigoldcompatibility")
	end

end


------------
--FINISHED--
------------
Isaac.DebugString("Mod Config Menu v" .. ModConfigMenu.Version .. " loaded!")
print("Mod Config Menu v" .. ModConfigMenu.Version .. " loaded!")

-- code added by @frto027(steamid/github/bilibili)

-------------
--Translate--
-------------

-- i18n means internationalization
ModConfigMenu.i18n = "Chinese"

-- nameTranslate is string
function ModConfigMenu.SetCategoryNameTranslate(categoryName, nameTranslate)

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("ModConfigMenu.SetCategoryNameTranslate - No valid category name provided", 2)
	end

	ModConfigMenu.UpdateCategory(categoryName, {
		NameTranslate = nameTranslate
	})

end

-- nameTranslate is string
function ModConfigMenu.SetSubcategoryNameTranslate(categoryName, subcategoryName, nameTranslate)

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("ModConfigMenu.SetSubcategoryNameTranslate - No valid category name provided", 2)
	end

	ModConfigMenu.UpdateSubcategory(categoryName, subcategoryName, {
		NameTranslate = nameTranslate
	})

end

-- infoTranslate is string
function ModConfigMenu.SetCategoryInfoTranslate(categoryName, infoTranslate)

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("ModConfigMenu.SetCategoryInfoTranslate - No valid category name provided", 2)
	end

	ModConfigMenu.UpdateCategory(categoryName, {
		InfoTranslate = infoTranslate
	})

end

-- infoTranslate is string
function ModConfigMenu.SetSubcategoryInfoTranslate(categoryName, subcategoryName, infoTranslate)

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("ModConfigMenu.SetSubcategoryInfoTranslate - No valid category name provided", 2)
	end

	ModConfigMenu.UpdateSubcategory(categoryName, subcategoryName, {
		InfoTranslate = infoTranslate
	})

end

function ModConfigMenu.GetSubcategoryOptions(categoryName, subcategoryName)
	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("ModConfigMenu.GetSubcategoryOptions - No valid category name provided", 2)
	end

	subcategoryName = subcategoryName or "Uncategorized"

	if type(subcategoryName) ~= "string" and type(subcategoryName) ~= "number" then
		error("ModConfigMenu.GetSubcategoryOptions - No valid subcategory name provided", 2)
	end

	local categoryID = ModConfigMenu.GetCategoryIDByName(categoryName)
	if categoryID == nil then
		categoryID = #ModConfigMenu.MenuData+1
		ModConfigMenu.MenuData[categoryID] = {}
		ModConfigMenu.MenuData[categoryID].Name = tostring(categoryName)
		ModConfigMenu.MenuData[categoryID].Subcategories = {}
	end
	
	local subcategoryID = ModConfigMenu.GetSubcategoryIDByName(categoryID, subcategoryName)
	if subcategoryID == nil then
		subcategoryID = #ModConfigMenu.MenuData[categoryID].Subcategories+1
		ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID] = {}
		ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Name = tostring(subcategoryName)
		ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Options = {}
	end

	return ModConfigMenu.MenuData[categoryID].Subcategories[subcategoryID].Options
end

function ModConfigMenu.OptionsPairs(categoryName, subcategoryName)
	return pairs(ModConfigMenu.GetSubcategoryOptions(categoryName, subcategoryName))
end
----------
-- texts is {string:string},  target is string, strict match
function ModConfigMenu.TranslateOptionsTextWithTable(categoryName, subcategoryName, texts, settingsTableKey)
	local translateKey = settingsTableKey .. "Translate"
	for _,options in ModConfigMenu.OptionsPairs(categoryName, subcategoryName) do
		if type(options[settingsTableKey]) == "string" then
			options[translateKey] = texts[options[settingsTableKey]] or options[translateKey]
		elseif type(options[settingsTableKey]) == "table" then
			options[translateKey] = options[translateKey] or {}
			for _,v in pairs(options[settingsTableKey]) do
				table.insert(options[translateKey],texts[v] or v)
			end
		end
	end
end

-- translateFunc is function(string):string, target is function
function ModConfigMenu.TranslateOptionsWithFunc(categoryName, subcategoryName, translateFunc, settingsTableKey)
	local translateBuffer = {}
	local translatedBuffer = {}
	local translateKey = settingsTableKey .. "Translate"
	for _, option in ModConfigMenu.OptionsPairs(categoryName,subcategoryName) do
		local Display = option[settingsTableKey]
		if type(option[settingsTableKey]) == "function" then
			option[translateKey] = function(a,b,c,d,e,f,g,h)
				local result = Display(a,b,c,d,e,f,g,h)
				if type(result) == "string" then
					if translatedBuffer[result] == nil then
						translatedBuffer[result] = true
						translateBuffer[result] = translateFunc(result)
					end
					return translateBuffer[result]
				end
				if type(result) == "table" then
					for i = 1,#result do
						local value = result[i]
						if not translatedBuffer[value] then
							translatedBuffer[value] = true
							translateBuffer[value] = translateFunc(value)		
						end
						result[i] = translateBuffer[value]
					end
					return result
				end
				return result
			end
		end
	end
end

--translates is {{key,value},{key,value}},(partical match) target is function, but translate the return value
function ModConfigMenu.TranslateOptionsWithTable(categoryName, subcategoryName, translates,settingsTableKey)

	ModConfigMenu.TranslateOptionsWithFunc(categoryName, subcategoryName, function(text)
		for _ , v in pairs(translates) do
			text = string.gsub(text, v[1], v[2])
		end
		return text
	end,settingsTableKey)
end
---------Display----------
function ModConfigMenu.TranslateOptionsDisplayTextWithTable(categoryName, subcategoryName, texts)
	if texts == nil then
		subcategoryName, texts = nil, subcategoryName, texts
	end
	ModConfigMenu.TranslateOptionsTextWithTable(categoryName,subcategoryName,texts,"Display")
end
function ModConfigMenu.TranslateOptionsDisplayWithFunc(categoryName, subcategoryName, translateFunc)
	if translateFunc == nil then
		subcategoryName, translateFunc = nil, subcategoryName
	end
	ModConfigMenu.TranslateOptionsWithFunc(categoryName,subcategoryName,translateFunc,"Display")
end
function ModConfigMenu.TranslateOptionsDisplayWithTable(categoryName, subcategoryName, translates)
	if translates == nil then
		subcategoryName, translates = nil, subcategoryName
	end
	ModConfigMenu.TranslateOptionsWithTable(categoryName,subcategoryName,translates,"Display")
end
--------Info------------
function ModConfigMenu.TranslateOptionsInfoTextWithTable(categoryName, subcategoryName, texts)
	if texts == nil then
		subcategoryName, texts = nil, subcategoryName
	end
	ModConfigMenu.TranslateOptionsTextWithTable(categoryName,subcategoryName,texts,"Info")
end
function ModConfigMenu.TranslateOptionsInfoWithFunc(categoryName, subcategoryName, translateFunc)
	if translateFunc == nil then
		subcategoryName, translateFunc = nil, subcategoryName
	end
	ModConfigMenu.TranslateOptionsWithFunc(categoryName,subcategoryName,translateFunc,"Info")
end
function ModConfigMenu.TranslateOptionsInfoWithTable(categoryName, subcategoryName, translates)
	if translates == nil then
		subcategoryName, translates = nil, subcategoryName
	end
	ModConfigMenu.TranslateOptionsWithTable(categoryName,subcategoryName,translates,"Info")
end
---------Popup----------------
function ModConfigMenu.TranslateOptionsPopupTextWithTable(categoryName, subcategoryName, texts)
	if texts == nil then
		subcategoryName, texts = nil, subcategoryName, texts
	end
	ModConfigMenu.TranslateOptionsTextWithTable(categoryName,subcategoryName,texts,"Popup")
end
function ModConfigMenu.TranslateOptionsPopupWithFunc(categoryName, subcategoryName, translateFunc)
	if translateFunc == nil then
		subcategoryName, translateFunc = nil, subcategoryName
	end
	ModConfigMenu.TranslateOptionsWithFunc(categoryName,subcategoryName,translateFunc,"Popup")
end
function ModConfigMenu.TranslateOptionsPopupWithTable(categoryName, subcategoryName, translates)
	if translates == nil then
		subcategoryName, translates = nil, subcategoryName
	end
	ModConfigMenu.TranslateOptionsWithTable(categoryName,subcategoryName,translates,"Popup")
end
---------Translate---------------
ModConfigMenu.SetCategoryNameTranslate("General", "通用")
ModConfigMenu.SetCategoryInfoTranslate("General","影响大多数mod的设置项")
ModConfigMenu.TranslateOptionsDisplayTextWithTable("General",{
	["These settings apply to"]="此菜单项适用于",
	["all mods which support them"]="所有支持此菜单的mod",
})
ModConfigMenu.TranslateOptionsDisplayWithTable("General",{
	{"Sync Game Setting","同步游戏设置"},
	{"Hud Offset", "界面位置"},
	{"Overlays", "画面遮罩层"},
	{"Charge Bars", "蓄力条"},
	{"Bigbooks", "书本动画"},
	{"On", "启用"},
	{"Off", "禁用"},
	{"Yes","是"},
	{"No","否"},
	{"Announcer", "语音播报"},
	{"Sometimes", "偶尔"},
	{"Never", "从不"},
	{"Always", "总是"},
})
ModConfigMenu.TranslateOptionsInfoTextWithTable("General", {
	["Synchornize settings from game Options menu when game start."]
		= "在游戏开始时 将游戏的设置选项同步到此页",
	["How far from the corners of the screen custom hud elements will be.$newlineTry to make this match your base-game setting."] 
		= "自定义hud与屏幕角落的距离。$newline令此项与游戏的设置保持一致。",
	["Enable or disable custom visual overlays, like screen-wide fog."]
		= "启用或禁用自定义的视觉遮罩层， 例如烟雾效果",
	["Enable or disable custom charge bar visuals for mod effects, like those from chargable items."]
		= "启用或禁用mod效果的自定义蓄力条， 例如来自可充能道具的蓄力条",
	["Enable or disable custom bigbook overlays which can appear when an active item is used."]
		= "启用或禁用在使用主动道具时显示的 书本动画",
	["Choose how often a voice-over will play when a pocket item (pill or card) is used."]
		= "设置使用药丸/卡牌时, 播报语音的频率"
})

ModConfigMenu.SetCategoryNameTranslate("Mod Config Menu", "mod配置菜单")
ModConfigMenu.SetCategoryInfoTranslate("Mod Config Menu", "mod配置菜单设置项$newline在这里修改菜单的键位")
ModConfigMenu.TranslateOptionsDisplayTextWithTable("Mod Config Menu",{
	["F10 will always open this menu."] = "始终可以使用F10打开当前页面",
})

ModConfigMenu.TranslateOptionsDisplayWithTable("Mod Config Menu",{
	{"Open Menu", "开启菜单"},
	-- {"keyboard", "键盘"},
	-- {"controller", "控制器"},
	-- {"None", "无"},
	-- {"Unknown Key", "未知按键"},
	-- {"Unknown Button", "未知按钮"},
	{"Hide HUD", "隐藏HUD"},
	{"Reset To Default Keybind", "重置默认键位"},
	{"Show Controls", "显示控件"},
	{"Use Game Font%(Chinese Needed%)","使用官方字体(需游戏中文)"},
	{"Disable Legacy Warnings", "停用过时警告"},
	{"On", "启用"},
	{"Off", "禁用"},
	{"Yes","是"},
	{"No","否"},

})

ModConfigMenu.TranslateOptionsInfoTextWithTable("Mod Config Menu",{
	["Choose what button on your keyboard will open Mod Config Menu."]
		= "选择打开mod配置菜单的键盘按键",
	["Choose what button on your controller will open Mod Config Menu."]
		= "选择打开mod配置菜单的控制器按钮",
	["Enable or disable the hud when this menu is open."]
		= "当前菜单中是否显示HUD",
	["Press this button on your keyboard to reset a setting to its default value."]
		= "按下此键以重置一个设置到默认键位",
	["Use the Chinese font that comes with the game instead of the font in MCM."]
		= "使用游戏自带的中文字体， 而不是Mod配置菜单自带的字体",
	["Disable this to remove the back and select widgets at the lower corners of the screen and remove the bottom start-up message."]
		= "禁用此项可以移除屏幕角落的 “返回”和“选择”控件 与开局的信息提示",
	["Use this setting to prevent warnings from being printed to the console for mods that use outdated features of Mod Config Menu."]
		= "对于使用了过时MCM接口的mod， 不再打印警告信息到控制台"
})

-- changed in previous program
-- ModConfigMenu.TranslateOptionsPopupWithTable("Mod Config Menu",{
-- 	{"This setting is currently set to \"","当前设置为\""},
-- 	{"\".$newlinePress this button to keep it unchanged.$newline$newline","\".$newline按此键保持设置不变。$newline"},
-- 	{"Press a button on your ","在"},
-- 	{" to change this setting.$newline$newline", "上按任意键改变设置$newline"},
-- 	{"Press \"", "按\""},
-- 	{"\" to go back and clear this setting.","\"返回并清除设置"},
-- 	{"back","返回"},
-- 	{"keyboard","键盘"},
-- 	{"controller","控制器"},
-- })

----------------------------------
-- ControllerToString translate --
----------------------------------

for k in pairs(InputHelper.ControllerToString) do
	for _,rep in pairs({
		{"LEFT BUMPER","左肩键(LB)"},
		{"RIGHT BUMPER","右肩键(RB)"},
		{"LEFT TRIGGER","左扳机(LT)"},
		{"RIGHT BUMPER","右扳机(RT)"},
		{"RIGHT",  "右"},
		{"LEFT",  "左"},
		{"UP",  "上"},
		{"DOWN",  "下"},
		{"BACK",  "返回"},
		{"START", "开始"},
		{"DPAD",  "十字键"},
		{"STICK",  "摇杆"},
		{" ", ""},
	})do
		InputHelper.ControllerToString[k] = string.gsub(InputHelper.ControllerToString[k],rep[1],rep[2])
	end
end

return ModConfigMenu
