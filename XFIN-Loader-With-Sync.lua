-- XFIN main loader with local XFINSCRIPT sync bridge.
-- Client-side only: source is stored as StringValue data; protected Script.Source is not modified.

local Players = game:GetService("Players")
local BASE = "https://raw.githubusercontent.com/richardsry0-oss/X-FIN-SCRIPT-EDITOR/main/"

local function getModule(filename)
    local source = game:HttpGet(BASE .. filename)
    local fn, err = loadstring(source)
    assert(fn, err or ("Compilation failed: " .. filename))
    return fn()
end

local XfinUI = getModule("XfinUI.lua")
local XfinBackend = getModule("XfinBackend.lua")
local player = Players.LocalPlayer
local ui = XfinUI.new(player:WaitForChild("PlayerGui"))
XfinBackend.attach(ui)

local function ensureFolder(parent, name)
    local folder = parent:FindFirstChild(name)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = parent
    end
    return folder
end

local recordsFolder = ensureFolder(workspace, "XFINSCRIPT")
local instanceFolder = ensureFolder(workspace, "XFIN SCRIPT INSTANCE")

local function ensureString(parent, name, value)
    local item = parent:FindFirstChild(name)
    if not item or not item:IsA("StringValue") then
        if item then item:Destroy() end
        item = Instance.new("StringValue")
        item.Name = name
        item.Parent = parent
    end
    if value ~= nil then item.Value = value end
    return item
end

local function ensureObjectValue(parent, name, value)
    local item = parent:FindFirstChild(name)
    if not item or not item:IsA("ObjectValue") then
        if item then item:Destroy() end
        item = Instance.new("ObjectValue")
        item.Name = name
        item.Parent = parent
    end
    if value ~= nil then item.Value = value end
    return item
end

local function normalizeInstanceName(name)
    return tostring(name or "Main.lua"):gsub("%.lua$", "")
end

local function classForType(scriptType)
    if scriptType == "Script" then return "Script" end
    if scriptType == "LocalScript" then return "LocalScript" end
    return "ModuleScript"
end

local function findRecord(name)
    return recordsFolder:FindFirstChild(tostring(name))
end

local function ensureRecord(name, scriptType, source)
    name = tostring(name or "Main.lua")
    local record = findRecord(name)
    if not record or not record:IsA("Folder") then
        if record then record:Destroy() end
        record = Instance.new("Folder")
        record.Name = name
        record.Parent = recordsFolder
    end

    local sourceValue = ensureString(record, "Source", source or "")
    local targetRef = ensureObjectValue(record, "OBJECTVALUE")
    local targetName = normalizeInstanceName(name)
    local target = instanceFolder:FindFirstChild(targetName)
    local wantedClass = classForType(scriptType)

    if target and target.ClassName ~= wantedClass then
        target:Destroy()
        target = nil
    end
    if not target then
        target = Instance.new(wantedClass)
        target.Name = targetName
        target.Parent = instanceFolder
    end

    targetRef.Value = target
    ensureString(target, "XFIN_Source", sourceValue.Value)
    ensureString(target, "XFIN_Type", scriptType or "Luau")
    return record, targetRef, target, sourceValue
end

-- SaveChangesTo(OBJECTVALUE [, source]) stores source text next to the referenced instance.
-- It intentionally does not attempt to assign the protected Script.Source property.
local function SaveChangesTo(objectValue, source)
    if typeof(objectValue) ~= "Instance" or not objectValue:IsA("ObjectValue") then
        return false, "Expected an ObjectValue."
    end
    local target = objectValue.Value
    if not target then return false, "OBJECTVALUE.Value is empty." end
    if source == nil then source = ui:GetSource() end
    if type(source) ~= "string" then return false, "Source must be a string." end

    local sourceValue = ensureString(target, "XFIN_Source", source)
    sourceValue.Value = source
    for _, record in ipairs(recordsFolder:GetChildren()) do
        if record:IsA("Folder") then
            local reference = record:FindFirstChild("OBJECTVALUE")
            if reference and reference:IsA("ObjectValue") and reference.Value == target then
                ensureString(record, "Source", source).Value = source
                break
            end
        end
    end
    return true, "Source text saved as XFIN_Source."
end

ui.SaveChangesTo = SaveChangesTo
ui.Callbacks.SaveChangesTo = SaveChangesTo

local originalSetScriptList = ui.SetScriptList
function ui:SetScriptList(items, current)
    local merged = {}
    local seen = {}
    for _, item in ipairs(items or {}) do
        local name = type(item) == "table" and item.Name or tostring(item)
        if not seen[name] then
            seen[name] = true
            table.insert(merged, item)
        end
    end
    for _, record in ipairs(recordsFolder:GetChildren()) do
        if record:IsA("Folder") and not seen[record.Name] then
            seen[record.Name] = true
            table.insert(merged, {Name = record.Name, Type = "Luau", External = true})
        end
    end
    originalSetScriptList(self, merged, current)
end

local callbacks = ui.Callbacks
local backendOpen = callbacks.OpenScript
callbacks.OpenScript = function(name, ...)
    local record = findRecord(name)
    if record then
        local sourceValue = record:FindFirstChild("Source")
        ui:SetFileName(record.Name)
        ui:SetSource(sourceValue and sourceValue.Value or "")
        ui:SetSaveStatus("Opened XFINSCRIPT record: " .. record.Name)
        return
    end
    if type(backendOpen) == "function" then return backendOpen(name, ...) end
end

local backendCreate = callbacks.CreateScript
callbacks.CreateScript = function(name, ...)
    local result
    if type(backendCreate) == "function" then result = backendCreate(name, ...) end
    ensureRecord(name, "Luau", "")
    ui:SetScriptList(XfinBackend.GetScriptList(), name)
    return result
end

local backendSave = callbacks.SaveScript
callbacks.SaveScript = function(name, source, ...)
    local result
    if type(backendSave) == "function" then result = backendSave(name, source, ...) end
    local item
    for _, entry in ipairs(XfinBackend.GetScriptList()) do
        if entry.Name == name then item = entry break end
    end
    local _, objectValue = ensureRecord(name, item and item.Type or "Luau", source or "")
    SaveChangesTo(objectValue, source or "")
    ui:SetScriptList(XfinBackend.GetScriptList(), name)
    return result
end

local backendSourceChanged = callbacks.SourceChanged
callbacks.SourceChanged = function(source, ...)
    local result
    if type(backendSourceChanged) == "function" then result = backendSourceChanged(source, ...) end
    local name = ui:GetFileName()
    local record = findRecord(name)
    if record then
        ensureString(record, "Source", type(source) == "string" and source or "")
        local objectValue = record:FindFirstChild("OBJECTVALUE")
        if objectValue and objectValue:IsA("ObjectValue") then
            SaveChangesTo(objectValue, type(source) == "string" and source or "")
        end
    end
    return result
end

local backendDelete = callbacks.DeleteScript
callbacks.DeleteScript = function(name, ...)
    local result
    if type(backendDelete) == "function" then result = backendDelete(name, ...) end
    local record = findRecord(name)
    if record then
        local objectValue = record:FindFirstChild("OBJECTVALUE")
        local target = objectValue and objectValue.Value
        if target and target.Parent == instanceFolder then target:Destroy() end
        record:Destroy()
    end
    ui:SetScriptList(XfinBackend.GetScriptList(), ui:GetFileName())
    return result
end

local backendRename = callbacks.RenameScript
callbacks.RenameScript = function(oldName, newName, ...)
    local result
    if type(backendRename) == "function" then result = backendRename(oldName, newName, ...) end
    local record = findRecord(oldName)
    if record then
        record.Name = newName
        local objectValue = record:FindFirstChild("OBJECTVALUE")
        local target = objectValue and objectValue.Value
        if target then target.Name = normalizeInstanceName(newName) end
    end
    ui:SetScriptList(XfinBackend.GetScriptList(), newName)
    return result
end

-- Detect records added/removed outside the editor and refresh the visible list.
recordsFolder.ChildAdded:Connect(function()
    task.defer(function() ui:SetScriptList(XfinBackend.GetScriptList(), ui:GetFileName()) end)
end)
recordsFolder.ChildRemoved:Connect(function()
    task.defer(function() ui:SetScriptList(XfinBackend.GetScriptList(), ui:GetFileName()) end)
end)

-- Run button: UI invokes RunScript(fileName, source).
callbacks.RunScript = function(fileName, source)
    if type(source) ~= "string" or source:match("^%s*$") then
        ui:Warn("The editor is empty.")
        return
    end
    if type(loadstring) ~= "function" then
        ui:Error("loadstring is unavailable.")
        return
    end
    local compileOK, fn, compileError = pcall(function() return loadstring(source) end)
    if not compileOK then ui:Error("Compile error: " .. tostring(fn)); return end
    if type(fn) ~= "function" then ui:Error("Compile error: " .. tostring(compileError)); return end
    ui:Info("Running " .. tostring(fileName or "script") .. "...")
    local runOK, result = pcall(fn)
    if not runOK then ui:Error("Runtime error: " .. tostring(result)); return end
    ui:Success("Finished running " .. tostring(fileName or "script"))
end

-- Initial view combines session scripts and XFINSCRIPT records.
ui:SetScriptList(XfinBackend.GetScriptList(), ui:GetFileName())
print("XFIN loaded with XFINSCRIPT sync bridge.")
print("SaveChangesTo(ObjectValue, source) is available as ui.SaveChangesTo.")
