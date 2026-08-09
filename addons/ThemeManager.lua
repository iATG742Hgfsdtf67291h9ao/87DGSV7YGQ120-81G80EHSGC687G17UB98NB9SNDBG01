local cloneref = (cloneref or clonereference or function(instance: any)
    return instance
end)
local clonefunction = (clonefunction or copyfunction or function(func) 
    return func 
end)

local httprequest = request or http_request or (http and http.request)
local getassetfunc = getcustomasset

local HttpService: HttpService = cloneref(game:GetService("HttpService"))
local isfolder, isfile, listfiles = isfolder, isfile, listfiles;

local assert = function(condition, errorMessage) 
    if (not condition) then
        error(if errorMessage then errorMessage else "assert failed", 3)
    end
end

if typeof(clonefunction) == "function" then
    -- Fix is_____ functions for shitsploits, those functions should never error, only return a boolean.

    local
        isfolder_copy,
        isfile_copy,
        listfiles_copy = clonefunction(isfolder), clonefunction(isfile), clonefunction(listfiles)

    local isfolder_success, isfolder_error = pcall(function()
        return isfolder_copy("test" .. tostring(math.random(1000000, 9999999)))
    end)

    if isfolder_success == false or typeof(isfolder_error) ~= "boolean" then
        isfolder = function(folder)
            local success, data = pcall(isfolder_copy, folder)
            return (if success then data else false)
        end

        isfile = function(file)
            local success, data = pcall(isfile_copy, file)
            return (if success then data else false)
        end

        listfiles = function(folder)
            local success, data = pcall(listfiles_copy, folder)
            return (if success then data else {})
        end
    end
end

local ThemeManager = {} do
	local ThemeFields = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor", "RiskColor", "VideoLink" }
	ThemeManager.Folder = "mourne/themes"
	ThemeManager.DefaultTheme = "Default"
	-- if not isfolder(ThemeManager.Folder) then makefolder(ThemeManager.Folder) end

	ThemeManager.Library = nil
	ThemeManager.BuiltInThemes = {
		['Default']       = { 1, { FontColor = "e0dde8", MainColor = "1c1a26", AccentColor = "9684c4", BackgroundColor = "17151f", OutlineColor = "302c3e", RiskColor = "ff3232" } },
		['BBot']          = { 2, { FontColor = "ffffff", MainColor = "1e1e1e", AccentColor = "7e48a3", BackgroundColor = "232323", OutlineColor = "141414", RiskColor = "ff3232" } },
		['Fatality']      = { 3, { FontColor = "ffffff", MainColor = "1e1842", AccentColor = "c50754", BackgroundColor = "191335", OutlineColor = "3c355d", RiskColor = "ff2d6e" } },
		['Jester']        = { 4, { FontColor = "ffffff", MainColor = "242424", AccentColor = "db4467", BackgroundColor = "1c1c1c", OutlineColor = "373737", RiskColor = "ff4d6a" } },
		['Mint']          = { 5, { FontColor = "ffffff", MainColor = "242424", AccentColor = "3db488", BackgroundColor = "1c1c1c", OutlineColor = "373737", RiskColor = "ff5555" } },
		['Tokyo Night']   = { 6, { FontColor = "ffffff", MainColor = "191925", AccentColor = "6759b3", BackgroundColor = "16161f", OutlineColor = "323232", RiskColor = "f7768e" } },
		['Ubuntu']        = { 7, { FontColor = "ffffff", MainColor = "3e3e3e", AccentColor = "e2581e", BackgroundColor = "323232", OutlineColor = "191919", RiskColor = "ff4c1e" } },
		['Quartz']        = { 8, { FontColor = "ffffff", MainColor = "232330", AccentColor = "426e87", BackgroundColor = "1d1b26", OutlineColor = "27232f", RiskColor = "e05561" } },
	}

	local AppliedVideoLink = nil

	function ApplyBackgroundVideo(videoLink)
		if
			typeof(videoLink) ~= "string" or
			not (getassetfunc and writefile and readfile and isfile) or
			not (ThemeManager.Library and ThemeManager.Library.InnerVideoBackground)
		then return; end;

		if videoLink == AppliedVideoLink then return; end;

		--// Variables \\--
		local videoInstance = ThemeManager.Library.InnerVideoBackground;
		local extension = videoLink:match(".*/(.-)?") or videoLink:match(".*/(.-)$"); extension = tostring(extension);
		local filename = string.sub(extension, 0, -6);
		local _, domain = videoLink:match("^(https?://)([^/]+)"); domain = tostring(domain); -- _ is protocol

		--// Check URL \\--
		if videoLink == "" then
			videoInstance:Pause();
			videoInstance.Video = "";
			videoInstance.Visible = false;
			AppliedVideoLink = videoLink;
			return
		end
		if #extension > 5 and string.sub(extension, -5) ~= ".webm" then return; end;

		local videoFile = ThemeManager.Folder .. "/themes/" .. string.sub(domain .. filename, 0, 249) .. ".webm";
		if not isfile(videoFile) then
			local success, requestRes = pcall(httprequest, { Url = videoLink, Method = 'GET' })
			if not (success and typeof(requestRes) == "table" and typeof(requestRes.Body) == "string") then return; end;

			writefile(videoFile, requestRes.Body)
		end

		--// Play Video \\--
		videoInstance.Video = getassetfunc(videoFile);
		videoInstance.Visible = true;
		videoInstance:Play();

		AppliedVideoLink = videoLink;
	end

	function ThemeManager:SetLibrary(library)
		self.Library = library
	end

	--// Folders \\--
	function ThemeManager:GetPaths()
	    local paths = {}

		local parts = self.Folder:split('/')
		for idx = 1, #parts do
			paths[#paths + 1] = table.concat(parts, '/', 1, idx)
		end

		paths[#paths + 1] = self.Folder .. '/themes'
		
		return paths
	end

	function ThemeManager:BuildFolderTree()
		local paths = self:GetPaths()

		for i = 1, #paths do
			local str = paths[i]
			if isfolder(str) then continue end
			makefolder(str)
		end
	end

	function ThemeManager:CheckFolderTree()
		local RootExisted = isfolder(self.Folder)

		self:BuildFolderTree()

		if not RootExisted then
			task.wait(0.1)
		end
	end

	function ThemeManager:SetFolder(folder)
		self.Folder = folder;
		self:BuildFolderTree()
	end
	
	--// Apply, Update theme \\--
	function ThemeManager:ApplyTheme(theme)
		local customThemeData = self:GetCustomTheme(theme)
		local data = customThemeData or self.BuiltInThemes[theme]

		if not data then return end

		if self.Library.InnerVideoBackground ~= nil
			and not (self.Library.Options and self.Library.Options.VideoLink) then
			self.Library.InnerVideoBackground.Visible = false
		end
		
		local scheme = data[2]
		for idx, col in next, customThemeData or scheme do
			if idx == "VideoLink" then
				self.Library[idx] = col
				
				if self.Library.Options[idx] then
					self.Library.Options[idx]:SetValue(col)
				end
				
				ApplyBackgroundVideo(col)
			else
				self.Library[idx] = Color3.fromHex(col)
				
				if self.Library.Options[idx] then
					self.Library.Options[idx]:SetValueRGB(Color3.fromHex(col))
				end
			end
		end

		self:ThemeUpdate()
	end

	function ThemeManager:ThemeUpdate()
		if self.Library.InnerVideoBackground ~= nil
			and not (self.Library.Options and self.Library.Options.VideoLink) then
			self.Library.InnerVideoBackground.Visible = false
		end

		for i, field in next, ThemeFields do
			if self.Library.Options and self.Library.Options[field] then
				self.Library[field] = self.Library.Options[field].Value

				if field == "VideoLink" then
					ApplyBackgroundVideo(self.Library.Options[field].Value)
				end
			end
		end

		self.Library.AccentColorDark = self.Library:GetDarkerColor(self.Library.AccentColor);
		self.Library:UpdateColorsUsingRegistry()
	end

	--// Get, Load, Save, Delete, Refresh \\--
	function ThemeManager:GetCustomTheme(file)
		local path = self.Folder .. '/themes/' .. file .. '.json'
		if not isfile(path) then
			return nil
		end

		local data = readfile(path)
		local success, decoded = pcall(HttpService.JSONDecode, HttpService, data)
		
		if not success then
			return nil
		end

		return decoded
	end

	function ThemeManager:LoadDefault()
		local theme = 'Default'
		local content = isfile(self.Folder .. '/themes/default.txt') and readfile(self.Folder .. '/themes/default.txt')

		if typeof(content) == "string" then
			content = content:match("^%s*(.-)%s*$")
			if content == "" then content = nil end
		end

		local isDefault = true
		if content then
			if self.BuiltInThemes[content] then
				theme = content
			elseif self:GetCustomTheme(content) then
				theme = content
				isDefault = false;
			end
		elseif self.BuiltInThemes[self.DefaultTheme] then
			theme = self.DefaultTheme
		end

		if isDefault then
			self.Library.Options.ThemeManager_ThemeList:SetValue(theme)
		else
			self:ApplyTheme(theme)
		end
	end

	function ThemeManager:SaveDefault(theme)
		self:CheckFolderTree()

		writefile(self.Folder .. '/themes/default.txt', theme)
	end

	function ThemeManager:SaveCustomTheme(file)
		if file:gsub(' ', '') == '' then
			self.Library:Notify('Invalid file name for theme (empty)', 3)
			return
		end

		self:CheckFolderTree()

		local theme = {}
		for _, field in next, ThemeFields do
			local option = self.Library.Options[field]
			if option ~= nil then
				if field == "VideoLink" then
					theme[field] = option.Value
				else
					theme[field] = option.Value:ToHex()
				end
			end
		end

		writefile(self.Folder .. '/themes/' .. file .. '.json', HttpService:JSONEncode(theme))
	end

	function ThemeManager:Delete(name)
		if (not name) then
			return false, 'no config file is selected'
		end

		local file = self.Folder .. '/themes/' .. name .. '.json'
		if not isfile(file) then return false, 'invalid file' end

		local success = pcall(delfile, file)
		if not success then return false, 'delete file error' end
		
		return true
	end
	
	function ThemeManager:ReloadCustomThemes()
		self:CheckFolderTree()

		local list = listfiles(self.Folder .. '/themes')
		if typeof(list) ~= "table" then list = {} end

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == '.json' then
				local name = file:match("[^/\\]+%.json$")

				if name then
					table.insert(out, name:sub(1, -6))
				end
			end
		end

		return out
	end

	--// GUI \\--
	function ThemeManager:CreateThemeManager(groupbox)
		groupbox:AddLabel('Main Color'):AddColorPicker('MainColor', { Default = self.Library.MainColor, Title = 'Main Color' });
		groupbox:AddLabel('Accent Color'):AddColorPicker('AccentColor', { Default = self.Library.AccentColor, Title = 'Accent Color' });
		groupbox:AddLabel('Background Color'):AddColorPicker('BackgroundColor', { Default = self.Library.BackgroundColor, Title = 'Background Color' });
		groupbox:AddLabel('Outline Color'):AddColorPicker('OutlineColor', { Default = self.Library.OutlineColor, Title = 'Outline Color' });
		groupbox:AddLabel('Text Color'):AddColorPicker('FontColor', { Default = self.Library.FontColor, Title = 'Text Color' });
		groupbox:AddLabel('Risk Text Color'):AddColorPicker('RiskColor', { Default = self.Library.RiskColor, Title = 'Risk Text Color' });

		local ThemesArray = {}
		for Name, Theme in next, self.BuiltInThemes do
			table.insert(ThemesArray, Name)
		end

		table.sort(ThemesArray, function(a, b) return self.BuiltInThemes[a][1] < self.BuiltInThemes[b][1] end)

		groupbox:AddDropdown('ThemeManager_ThemeList', { Text = 'Theme list', Values = ThemesArray, Default = 1 })
		groupbox:AddButton('Set Default', function()
			self:SaveDefault(self.Library.Options.ThemeManager_ThemeList.Value)
			self.Library:Notify(string.format('Set default theme to %q', self.Library.Options.ThemeManager_ThemeList.Value), 3)
		end)

		groupbox:AddInput('ThemeManager_CustomThemeName', { Text = 'Custom theme name', Default = '' })

		local function RefreshCustomThemes()
			self.Library.Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
			self.Library.Options.ThemeManager_CustomThemeList:SetValue(nil)
		end

		groupbox:AddButton('Create theme', function()
			local name = self.Library.Options.ThemeManager_CustomThemeName.Value

			-- A name made only of spaces is still a valid file name, so only a truly
			-- empty string is rejected here.
			if typeof(name) ~= 'string' or name == '' then
				return self.Library:Notify('Failed to create theme: invalid name', 3)
			end

			self:SaveCustomTheme(name)
			self.Library:Notify(string.format('Created theme %q', name), 3)
			RefreshCustomThemes()
		end)

		groupbox:AddDropdown('ThemeManager_CustomThemeList', { Text = 'Custom themes', Values = self:ReloadCustomThemes(), AllowNull = true, Default = 1 })
		groupbox:AddButton('Load theme', function()
			local name = self.Library.Options.ThemeManager_CustomThemeList.Value
			if not name then return end

			self:ApplyTheme(name)
			self.Library:Notify(string.format('Loaded theme %q', name), 3)
		end)

		groupbox:AddButton({
			Text = 'Overwrite Theme',
			Func = function()
				local name = self.Library.Options.ThemeManager_CustomThemeList.Value

				if typeof(name) ~= 'string' or name == '' then
					return self.Library:Notify('Invalid file name for theme (empty)', 3)
				end

				self:SaveCustomTheme(name)
				self.Library:Notify(string.format('Overwrote theme %q', name), 3)
			end,
		}):AddButton({
			Text = 'Delete Theme',
			Func = function()
				local name = self.Library.Options.ThemeManager_CustomThemeList.Value

				if typeof(name) ~= 'string' or name == '' then
					return self.Library:Notify('Failed to delete theme: no config file is selected', 3)
				end

				local success, err = self:Delete(name)
				if not success then
					return self.Library:Notify('Failed to delete theme: ' .. tostring(err), 3)
				end

				self.Library:Notify(string.format('Deleted theme %q', name), 3)
				RefreshCustomThemes()
			end,
		})

		groupbox:AddButton({
			Text = 'Set Default',
			Func = function()
				local name = self.Library.Options.ThemeManager_CustomThemeList.Value
				if not name or name == '' then return end

				self:SaveDefault(name)
				self.Library:Notify(string.format('Set default theme to %q', name), 3)
			end,
		}):AddButton({
			Text = 'Reset Default',
			Func = function()
				local success = pcall(delfile, self.Folder .. '/themes/default.txt')
				if not success then
					return self.Library:Notify('Failed to reset default: delete file error', 3)
				end

				self.Library:Notify('Removed default theme', 3)
				RefreshCustomThemes()
			end,
		})

		groupbox:AddButton('Refresh', RefreshCustomThemes)

		self:LoadDefault()

		local function UpdateTheme() self:ThemeUpdate() end
		self.Library.Options.BackgroundColor:OnChanged(UpdateTheme)
		self.Library.Options.MainColor:OnChanged(UpdateTheme)
		self.Library.Options.AccentColor:OnChanged(UpdateTheme)
		self.Library.Options.OutlineColor:OnChanged(UpdateTheme)
		self.Library.Options.FontColor:OnChanged(UpdateTheme)
		self.Library.Options.RiskColor:OnChanged(UpdateTheme)

		self.Library.Options.ThemeManager_ThemeList:OnChanged(function()
			self:ApplyTheme(self.Library.Options.ThemeManager_ThemeList.Value)
		end)
	end

	-- Drives Library.BackgroundSettings: the rotating item in the viewport behind the
	-- menu, and the backdrop / blur / color grade applied while the menu is open.
	function ThemeManager:CreateBackgroundManager(groupbox)
		local Library = self.Library
		local Settings = Library.BackgroundSettings

		local ItemNames = {}
		for Name in next, Library.BackgroundItems do
			table.insert(ItemNames, Name)
		end

		-- Presented in a fixed order rather than the hash order of the item table.
		local ItemOrder = { 'None', 'Sword', 'Cross', 'Heart', 'Catholic Cross', 'Orthodox Cross', 'Mourne' }
		table.sort(ItemNames, function(a, b)
			local ia = table.find(ItemOrder, a) or math.huge
			local ib = table.find(ItemOrder, b) or math.huge
			if ia == ib then return a < b end
			return ia < ib
		end)

		groupbox:AddLabel('Item Color'):AddColorPicker('BackgroundItemColor', {
			Default = Settings.ItemColor,
			Title = 'Item Color',
			Callback = function(Value)
				Settings.ItemColor = Value
				Library:UpdateBackgroundItem()
			end,
		})

		groupbox:AddDropdown('BackgroundItem', {
			Text = 'Item',
			Values = ItemNames,
			Default = table.find(ItemNames, Settings.Item) or 1,
			Multi = false,
			Callback = function(Value)
				Library:SetBackgroundItem(Value)
			end,
		})

		groupbox:AddDualSlider(
			{
				Idx = 'BackgroundItemTransparency', Text = 'Transparency',
				Default = Settings.ItemTransparency, Min = 0, Max = 1, Rounding = 2,
				Callback = function(Value)
					Settings.ItemTransparency = Value
					Library:UpdateBackgroundItem()
				end,
			},
			{
				Idx = 'BackgroundItemReflectance', Text = 'Reflectance',
				Default = Settings.ItemReflectance, Min = 0, Max = 1, Rounding = 2,
				Callback = function(Value)
					Settings.ItemReflectance = Value
					Library:UpdateBackgroundItem()
				end,
			},
			{ Stacked = true }
		)

		groupbox:AddSlider('BackgroundSpeed', {
			Text = 'Speed', Default = Settings.Speed, Min = 0, Max = 1, Rounding = 2,
			Callback = function(Value)
				Settings.Speed = Value
			end,
		})

		groupbox:AddDropdown('BackgroundItemMaterial', {
			Text = 'Material',
			Values = {
				'ForceField', 'Neon', 'Plastic', 'SmoothPlastic', 'Wood', 'WoodPlanks', 'Marble', 'Slate',
				'Concrete', 'Granite', 'Brick', 'Pebble', 'Cobblestone', 'Rock', 'Sandstone', 'Basalt',
				'CrackedLava', 'Limestone', 'Pavement', 'CorrodedMetal', 'DiamondPlate', 'Foil', 'Metal',
				'Grass', 'LeafyGrass', 'Sand', 'Fabric', 'Snow', 'Mud', 'Ground', 'Asphalt', 'Salt',
				'Ice', 'Glacier', 'Glass',
			},
			Default = 2,
			Multi = false,
			Callback = function(Value)
				Settings.ItemMaterial = Value
				Library:UpdateBackgroundItem()
			end,
		})

		groupbox:AddDivider()

		groupbox:AddLabel('Background Color'):AddColorPicker('BackgroundColorPicker', {
			Default = Settings.Color,
			Title = 'Background Color',
			Callback = function(Value)
				Settings.Color = Value
				Library:UpdateBackground()
			end,
		})

		groupbox:AddDualSlider(
			{
				Idx = 'BackgroundTransparency', Text = 'Transparency',
				Default = Settings.Transparency, Min = 0, Max = 1, Rounding = 2,
				Callback = function(Value)
					Settings.Transparency = Value
					Library:UpdateBackground()
				end,
			},
			{
				Idx = 'BackgroundBlur', Text = 'Blur',
				Default = Settings.Blur, Min = 0, Max = 50, Rounding = 0,
				Callback = function(Value)
					Settings.Blur = Value
					Library:UpdateBackground()
				end,
			},
			{ Stacked = true }
		)

		groupbox:AddDualSlider(
			{
				Idx = 'BackgroundContrast', Text = 'Contrast',
				Default = Settings.Contrast, Min = -10, Max = 10, Rounding = 1,
				Callback = function(Value)
					Settings.Contrast = Value
					Library:UpdateBackground()
				end,
			},
			{
				Idx = 'BackgroundSaturation', Text = 'Saturation',
				Default = Settings.Saturation, Min = -10, Max = 10, Rounding = 1,
				Callback = function(Value)
					Settings.Saturation = Value
					Library:UpdateBackground()
				end,
			},
			{ Stacked = true }
		)

		groupbox:AddSlider('BackgroundBrightness', {
			Text = 'Brightness', Default = Settings.Brightness, Min = -1, Max = 1, Rounding = 2,
			Callback = function(Value)
				Settings.Brightness = Value
				Library:UpdateBackground()
			end,
		})

		Library:SetBackgroundItem(Settings.Item)
	end

	function ThemeManager:CreateGroupBox(tab)
		assert(self.Library, 'ThemeManager:CreateGroupBox -> Must set ThemeManager.Library first!')
		return tab:AddLeftGroupbox('Themes')
	end

	-- Builds a tabbox with the theme controls and the background controls side by side.
	function ThemeManager:ApplyToTab(tab)
		assert(self.Library, 'ThemeManager:ApplyToTab -> Must set ThemeManager.Library first!')

		local tabbox = tab:AddLeftTabbox()
		self:CreateThemeManager(tabbox:AddTab('Themes'))
		self:CreateBackgroundManager(tabbox:AddTab('Background'))
	end

	function ThemeManager:ApplyToGroupbox(groupbox)
		assert(self.Library, 'ThemeManager:ApplyToGroupbox -> Must set ThemeManager.Library first!')
		self:CreateThemeManager(groupbox)
	end

	ThemeManager:BuildFolderTree()
end

getgenv().LinoriaThemeManager = ThemeManager
return ThemeManager
