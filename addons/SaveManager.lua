local cloneref = (cloneref or clonereference or function(instance: any)
    return instance
end)
local clonefunction = (clonefunction or copyfunction or function(func) 
    return func 
end)

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

local SaveManager = {} do
    SaveManager.Folder = "mourne"
    SaveManager.SubFolder = ""
    SaveManager.Ignore = {}
    SaveManager.Library = nil
    SaveManager.UseLoadingOrder = false
    SaveManager.LoadingOrder = {}
    SaveManager.Parser = {
        Toggle = {
            Save = function(idx, object)
                return { type = 'Toggle', idx = idx, value = object.Value }
            end,
            Load = function(idx, data)
                local object = SaveManager.Library.Toggles[idx]
                if object and object.Value ~= data.value then
                    object:SetValue(data.value)
                end
            end,
        },
        Slider = {
            Save = function(idx, object)
                return { type = 'Slider', idx = idx, value = tostring(object.Value) }
            end,
            Load = function(idx, data)
                local object = SaveManager.Library.Options[idx]
                if object and object.Value ~= data.value then
                    object:SetValue(data.value)
                end
            end,
        },
        Dropdown = {
            Save = function(idx, object)
                return { type = 'Dropdown', idx = idx, value = object.Value, multi = object.Multi }
            end,
            Load = function(idx, data)
                local object = SaveManager.Library.Options[idx]
                if object and object.Value ~= data.value then
                    object:SetValue(data.value)
                end
            end,
        },
        ColorPicker = {
            Save = function(idx, object)
                return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
            end,
            Load = function(idx, data)
                if SaveManager.Library.Options[idx] then
                    SaveManager.Library.Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
                end
            end,
        },
        KeyPicker = {
            Save = function(idx, object)
                return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value, modifiers = object.Modifiers }
            end,
            Load = function(idx, data)
                if SaveManager.Library.Options[idx] then
                    SaveManager.Library.Options[idx]:SetValue({ data.key, data.mode, data.modifiers })
                end
            end,
        },
        Input = {
            Save = function(idx, object)
                return { type = 'Input', idx = idx, text = object.Value }
            end,
            Load = function(idx, data)
                local object = SaveManager.Library.Options[idx]
                if object and object.Value ~= data.text and type(data.text) == 'string' then
                    SaveManager.Library.Options[idx]:SetValue(data.text)
                end
            end,
        },
    }

    function SaveManager:SetLibrary(library)
        self.Library = library
    end

    function SaveManager:SetLoadingOrder(enabled, order)
        self.UseLoadingOrder = enabled

        if typeof(order) == "table" then
            self.LoadingOrder = order
        end
    end

    function SaveManager:IgnoreThemeSettings()
        self:SetIgnoreIndexes({
            "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", -- themes
            "ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName', -- themes
            "VideoLink",
        })
    end

    --// Folders \\--
    function SaveManager:CheckSubFolder(createFolder)
        if typeof(self.SubFolder) ~= "string" or self.SubFolder == "" then return false end

        if createFolder == true then
            if not isfolder(self.Folder .. "/settings/" .. self.SubFolder) then
                makefolder(self.Folder .. "/settings/" .. self.SubFolder)
            end
        end

        return true
    end

    function SaveManager:GetPaths()
        local paths = {}

        local parts = self.Folder:split('/')
        for idx = 1, #parts do
            local path = table.concat(parts, '/', 1, idx)
            if not table.find(paths, path) then paths[#paths + 1] = path end
        end

        paths[#paths + 1] = self.Folder .. '/themes'
        paths[#paths + 1] = self.Folder .. '/settings'

        if self:CheckSubFolder(false) then
            local subFolder = self.Folder .. "/settings/" .. self.SubFolder
            parts = subFolder:split('/')

            for idx = 1, #parts do
                local path = table.concat(parts, '/', 1, idx)
                if not table.find(paths, path) then paths[#paths + 1] = path end
            end
        end

        return paths
    end

    function SaveManager:BuildFolderTree()
        local paths = self:GetPaths()

        for i = 1, #paths do
            local str = paths[i]
            if isfolder(str) then continue end

            makefolder(str)
        end
    end

    function SaveManager:CheckFolderTree()
        if isfolder(self.Folder) then return end
        SaveManager:BuildFolderTree()

        task.wait(0.1)
    end

    function SaveManager:SetIgnoreIndexes(list)
        for _, key in next, list do
            self.Ignore[key] = true
        end
    end

    function SaveManager:SetFolder(folder)
        self.Folder = folder;
        self:BuildFolderTree()
    end

    function SaveManager:SetSubFolder(folder)
        self.SubFolder = folder;
        self:BuildFolderTree()
    end

    --// Save, Load, Delete, Refresh \\--
    -- Single source of truth for where a config lives, honouring the sub folder.
    function SaveManager:GetConfigPath(name)
        if self:CheckSubFolder(true) then
            return self.Folder .. '/settings/' .. self.SubFolder .. '/' .. name .. '.json'
        end

        return self.Folder .. '/settings/' .. name .. '.json'
    end

    function SaveManager:Serialize()
        local data = {
            objects = {}
        }

        for idx, toggle in next, self.Library.Toggles do
            if not toggle.Type then continue end
            if not self.Parser[toggle.Type] then continue end
            if self.Ignore[idx] then continue end

            table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
        end

        for idx, option in next, self.Library.Options do
            if not option.Type then continue end
            if not self.Parser[option.Type] then continue end
            if self.Ignore[idx] then continue end

            table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
        end

        local success, encoded = pcall(HttpService.JSONEncode, HttpService, data)
        if not success then
            return nil, 'failed to encode data'
        end

        return encoded
    end

    function SaveManager:LoadString(raw)
        if typeof(raw) ~= 'string' or raw:gsub('%s', '') == '' then
            return false, 'no config data'
        end

        local success, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
        if not success or typeof(decoded) ~= 'table' or typeof(decoded.objects) ~= 'table' then
            return false, 'decode error'
        end

        if self.UseLoadingOrder == true and typeof(self.LoadingOrder) == "table" then
            table.sort(decoded.objects, function(a, b)
                local aIndex = table.find(self.LoadingOrder, a.type) or math.huge
                local bIndex = table.find(self.LoadingOrder, b.type) or math.huge
                return aIndex < bIndex
            end)
        end

        for _, option in decoded.objects do
            if not option.type then continue end
            if not self.Parser[option.type] then continue end
            if self.Ignore[option.idx] then continue end

            task.spawn(self.Parser[option.type].Load, option.idx, option)
        end

        return true
    end

    function SaveManager:Save(name)
        if (not name) then
            return false, 'no config file is selected'
        end
        SaveManager:CheckFolderTree()

        local fullPath = self.Folder .. '/settings/' .. name .. '.json'
        if SaveManager:CheckSubFolder(true) then
            fullPath = self.Folder .. "/settings/" .. self.SubFolder .. "/" .. name .. '.json'
        end

        local encoded, err = self:Serialize()
        if not encoded then
            return false, err
        end

        writefile(fullPath, encoded)
        return true
    end

    function SaveManager:Load(name)
        if (not name) then
            return false, 'no config file is selected'
        end
        SaveManager:CheckFolderTree()

        local file = self.Folder .. '/settings/' .. name .. '.json'
        if SaveManager:CheckSubFolder(true) then
            file = self.Folder .. "/settings/" .. self.SubFolder .. "/" .. name .. '.json'
        end

        if not isfile(file) then return false, 'invalid file' end

        return self:LoadString(readfile(file))
    end

    function SaveManager:Delete(name)
        if (not name) then
            return false, 'no config file is selected'
        end

        local file = self.Folder .. '/settings/' .. name .. '.json'
        if SaveManager:CheckSubFolder(true) then
            file = self.Folder .. "/settings/" .. self.SubFolder .. "/" .. name .. '.json'
        end

        if not isfile(file) then return false, 'invalid file' end

        local success = pcall(delfile, file)
        if not success then return false, 'delete file error' end

        return true
    end

    function SaveManager:RefreshConfigList()
        local success, data = pcall(function()
            SaveManager:CheckFolderTree()

            local list = {}
            local out = {}

            if SaveManager:CheckSubFolder(true) then
                list = listfiles(self.Folder .. "/settings/" .. self.SubFolder)
            else
                list = listfiles(self.Folder .. "/settings")
            end
            if typeof(list) ~= "table" then list = {} end

            for i = 1, #list do
                local file = list[i]
                if file:sub(-5) == '.json' then
                    -- i hate this but it has to be done ...

                    local pos = file:find('.json', 1, true)
                    local start = pos

                    local char = file:sub(pos, pos)
                    while char ~= '/' and char ~= '\\' and char ~= '' do
                        pos = pos - 1
                        char = file:sub(pos, pos)
                    end

                    if char == '/' or char == '\\' then
                        table.insert(out, file:sub(pos + 1, start - 1))
                    end
                end
            end

            return out
        end)

        if (not success) then
            if self.Library then
                self.Library:Notify('Failed to load config list: ' .. tostring(data))
            else
                warn('Failed to load config list: ' .. tostring(data))
            end

            return {}
        end

        return data
    end

    --// Auto Load \\--
    function SaveManager:GetAutoloadConfig()
        SaveManager:CheckFolderTree()

        local autoLoadPath = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            autoLoadPath = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        if isfile(autoLoadPath) then
            local successRead, name = pcall(readfile, autoLoadPath)
            if not successRead then
                return "none"
            end

            name = tostring(name)
            return if name == "" then "none" else name
        end

        return "none"
    end

    function SaveManager:LoadAutoloadConfig()
        SaveManager:CheckFolderTree()

        local autoLoadPath = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            autoLoadPath = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        if isfile(autoLoadPath) then
            local successRead, name = pcall(readfile, autoLoadPath)
            if not successRead then
                self.Library:Notify('Failed to load autoload config: write file error')
                return
            end

            local success, err = self:Load(name)
            if not success then
                self.Library:Notify('Failed to load autoload config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Auto loaded config %q', name))
        end
    end

    function SaveManager:SaveAutoloadConfig(name)
        SaveManager:CheckFolderTree()

        local autoLoadPath = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            autoLoadPath = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        local success = pcall(writefile, autoLoadPath, name)
        if not success then return false, 'write file error' end

        return true, ""
    end

    function SaveManager:DeleteAutoLoadConfig()
        SaveManager:CheckFolderTree()

        local autoLoadPath = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            autoLoadPath = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        local success = pcall(delfile, autoLoadPath)
        if not success then return false, 'delete file error' end

        return true, ""
    end

    --// GUI \\--
    function SaveManager:BuildConfigSection(tab)
        assert(self.Library, 'SaveManager:BuildConfigSection -> Must set SaveManager.Library')

        local section = tab:AddRightGroupbox('Configuration')

        local function RefreshList()
            self.Library.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            self.Library.Options.SaveManager_ConfigList:SetValue(nil)
        end

        -- Trailing whitespace is stripped so a stray space cannot create a second config
        -- that looks identical to an existing one in the list.
        local function ConfigName()
            local name = self.Library.Options.SaveManager_ConfigName.Value
            return (typeof(name) == 'string' and name:gsub('%s+$', '') or '')
        end

        section:AddInput('SaveManager_ConfigName', { Text = 'Config name', Default = '' })
        section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true })

        section:AddButton({
            Text = 'Create config',
            Func = function()
                local name = ConfigName()
                if name == '' then
                    return self.Library:Notify('Invalid config name', 2)
                end

                local success, err = self:Save(name)
                if not success then
                    return self.Library:Notify('Failed to save: ' .. tostring(err), 3)
                end

                self.Library:Notify(string.format('Created config %q', name), 2)
                RefreshList()
            end,
        }):AddButton({
            Text = 'Load config',
            Func = function()
                local name = self.Library.Options.SaveManager_ConfigList.Value
                if not name then return end

                local success, err = self:Load(name)
                if not success then
                    return self.Library:Notify('Failed to load: ' .. tostring(err), 3)
                end

                self.Library:Notify(string.format('Loaded config %q', name), 2)
            end,
        })

        section:AddButton({
            Text = 'Overwrite config',
            DoubleClick = true,
            Func = function()
                local name = self.Library.Options.SaveManager_ConfigList.Value
                if not name then return end

                local success, err = self:Save(name)
                if not success then
                    return self.Library:Notify('Failed to overwrite: ' .. tostring(err), 3)
                end

                self.Library:Notify(string.format('Overwrote config %q', name), 2)
            end,
        }):AddButton({
            Text = 'Delete config',
            DoubleClick = true,
            Func = function()
                local name = self.Library.Options.SaveManager_ConfigList.Value
                if not name then return end

                local success, err = self:Delete(name)
                if not success then
                    return self.Library:Notify('Failed to delete: ' .. tostring(err), 3)
                end

                self.Library:Notify(string.format('Deleted config %q', name), 2)
                RefreshList()
            end,
        })

        section:AddButton({ Text = 'Refresh list', Func = RefreshList })

        section:AddButton({
            Text = 'Set autoload',
            Func = function()
                local name = self.Library.Options.SaveManager_ConfigList.Value
                if not name then return end

                local success, err = self:SaveAutoloadConfig(name)
                if not success then
                    return self.Library:Notify('Failed to set autoload config: ' .. tostring(err), 3)
                end

                self.Library:Notify(string.format('Set %q to auto load', name), 2)
                self.AutoloadConfigLabel:SetText('Current autoload config: ' .. name)
            end,
        }):AddButton({
            Text = 'Remove autoload',
            Func = function()
                local success, err = self:DeleteAutoLoadConfig()
                if not success then
                    return self.Library:Notify('Failed to remove autoload config: ' .. tostring(err), 3)
                end

                self.Library:Notify('Removed autoload config', 2)
                self.AutoloadConfigLabel:SetText('Current autoload config: none')
            end,
        })

        self.AutoloadConfigLabel = section:AddLabel('Current autoload config: ' .. self:GetAutoloadConfig(), true)

        section:AddDivider()

        section:AddInput('SaveManager_ImportConfig', {
            Text = 'Import config',
            Default = '',
            Placeholder = 'Paste config here...',
            Finished = true,
            Callback = function(value)
                if typeof(value) ~= 'string' or value == '' then return end

                local box = self.Library.Options.SaveManager_ImportConfig
                if box and box.SetValue then
                    box:SetValue('')
                end

                local success, err = self:LoadString(value)
                if not success then
                    return self.Library:Notify('Failed to import config: ' .. tostring(err), 3)
                end

                self.Library:Notify('Imported config - name it above and save to keep it', 3)
            end,
        })

        section:AddButton({
            Text = 'Copy config to clipboard',
            Func = function()
                local copy = setclipboard or toclipboard or (syn and syn.write_clipboard)
                if not copy then
                    return self.Library:Notify('Your executor cannot write to the clipboard', 3)
                end

                local encoded, err = self:Serialize()
                if not encoded then
                    return self.Library:Notify('Failed to copy config: ' .. tostring(err), 3)
                end

                copy(encoded)
                self.Library:Notify('Copied current config to clipboard', 2)
            end,
        })

        self:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName', 'SaveManager_ImportConfig' })
    end

    SaveManager:BuildFolderTree()
end

return SaveManager
