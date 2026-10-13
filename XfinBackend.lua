--[[
    XFIN SCRIPT EDITER
    ModuleScript: XfinBackend (v2)

    Saved scripts are written to  XFIN/scripts/<name>  with writefile and are
    loaded back the next time XFIN starts. If the executor has no file access,
    scripts stay session-only (and the output panel says so).

    Does not execute editor source (the loader's Run callback does that).
]]

local HttpService = game:GetService("HttpService")

local Backend = {}

local MAX_SOURCE_LENGTH = 200000
local MAX_NAME_LENGTH = 80

local ROOT_DIR = "XFIN"
local SCRIPT_DIR = "XFIN/scripts"
local INDEX_FILE = "XFIN/index.json"

local TEMPLATES = {
    {
        Id = "script",
        Name = "Script",
        Description = "A basic server Script.",
        Type = "Script",
        Source = [[print("Hello from a Script")

local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    print(player.Name .. " joined")
end)
]],
    },
    {
        Id = "localscript",
        Name = "LocalScript",
        Description = "A client-side LocalScript.",
        Type = "LocalScript",
        Source = [[local Players = game:GetService("Players")
local player = Players.LocalPlayer

print("Hello, " .. player.Name)
]],
    },
    {
        Id = "modulescript",
        Name = "ModuleScript",
        Description = "A module that returns a table.",
        Type = "ModuleScript",
        Source = [[local Module = {}

function Module.hello(name)
    return "Hello, " .. name
end

return Module
]],
    },
    {
        Id = "empty",
        Name = "Empty Script",
        Description = "A blank editor.",
        Type = "Luau",
        Source = "",
    },
}

local VALID_TYPES = {
    Script = true,
    LocalScript = true,
    ModuleScript = true,
    Luau = true,
}

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return
    end

    local ok, err = pcall(callback, ...)
    if not ok then
        warn("[XFIN Backend] UI callback failed:", err)
    end
end

local function normalizeName(value)
    if type(value) ~= "string" then
        return nil, "The script name must be text."
    end

    local name = value:match("^%s*(.-)%s*$")

    -- Names are simple editor filenames, not paths.
    name = name:gsub("[/\\]", "")
    name = name:gsub("[%c]", "")

    if name == "" then
        return nil, "Enter a script name."
    end

    if #name > MAX_NAME_LENGTH then
        return nil, "The script name is too long."
    end

    if name == "." or name == ".." then
        return nil, "That script name is not allowed."
    end

    if name:find("[<>:\"|?*]") then
        return nil, "The script name contains an invalid character."
    end

    if not name:match("%.[%w_%-]+$") then
        name ..= ".lua"
    end

    return name
end

-- ---------------------------------------------------------------- disk storage

local function canWrite()
    return type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
        and type(isfolder) == "function"
        and type(makefolder) == "function"
end

local function ensureFolders()
    if not isfolder(ROOT_DIR) then makefolder(ROOT_DIR) end
    if not isfolder(SCRIPT_DIR) then makefolder(SCRIPT_DIR) end
end

local function writeIndex(scripts)
    if not canWrite() then return end
    local names = {}
    for name, data in pairs(scripts) do
        if data.OnDisk then table.insert(names, name) end
    end
    table.sort(names)
    pcall(function()
        ensureFolders()
        writefile(INDEX_FILE, HttpService:JSONEncode({ scripts = names }))
    end)
end

local function diskSave(name, source)
    if not canWrite() then
        return false, "no file access"
    end
    local ok, err = pcall(function()
        ensureFolders()
        writefile(SCRIPT_DIR .. "/" .. name, source)
    end)
    return ok, err
end

-- Returns true if removed, false if this executor can't delete files.
local function diskDelete(name)
    if not canWrite() then return false end
    if type(delfile) ~= "function" then return false end
    pcall(function()
        local path = SCRIPT_DIR .. "/" .. name
        if isfile(path) then delfile(path) end
    end)
    return true
end

local function diskLoad()
    local loaded = {}
    if not canWrite() then return loaded end

    local names, seen = {}, {}
    local function add(n)
        if type(n) == "string" and not seen[n] then
            seen[n] = true
            table.insert(names, n)
        end
    end

    pcall(function()
        if type(listfiles) == "function" and isfolder(SCRIPT_DIR) then
            for _, path in ipairs(listfiles(SCRIPT_DIR)) do
                add(tostring(path):match("[^/\\]+$"))
            end
        end
    end)

    pcall(function()
        if isfile(INDEX_FILE) then
            local data = HttpService:JSONDecode(readfile(INDEX_FILE))
            if type(data) == "table" and type(data.scripts) == "table" then
                for _, n in ipairs(data.scripts) do add(n) end
            end
        end
    end)

    for _, n in ipairs(names) do
        if normalizeName(n) == n then
            local path = SCRIPT_DIR .. "/" .. n
            local ok, content = pcall(function()
                if isfile(path) then return readfile(path) end
            end)
            if ok and type(content) == "string" and #content <= MAX_SOURCE_LENGTH then
                loaded[n] = {
                    Name = n,
                    Type = "Luau",
                    Source = content,
                    SavedSource = content,
                    OnDisk = true,
                }
            end
        end
    end

    return loaded
end

-- ---------------------------------------------------------------- helpers

local function copyScriptList(scripts)
    local result = {}

    for _, scriptData in pairs(scripts) do
        table.insert(result, {
            Name = scriptData.Name,
            Type = scriptData.Type,
        })
    end

    table.sort(result, function(a, b)
        return a.Name:lower() < b.Name:lower()
    end)

    return result
end

local function getTemplate(id)
    for _, template in ipairs(TEMPLATES) do
        if template.Id == id then
            return template
        end
    end

    return nil
end

-- This is a lightweight source review, not a Luau compiler.
local function reviewSource(source, scriptType)
    local messages = {}
    local lineCount = 1

    for _ in source:gmatch("\n") do
        lineCount += 1
    end

    if source:match("^%s*$") then
        table.insert(messages, {
            Level = "warn",
            Message = "The source is empty.",
        })
    end

    if source:find("loadstring%s*%(") then
        table.insert(messages, {
            Level = "warn",
            Message = "The source uses loadstring. Availability is restricted and is not guaranteed.",
        })
    end

    if source:find("HttpGet%s*%(") then
        table.insert(messages, {
            Level = "warn",
            Message = "Review HttpGet usage. It is not a general-purpose client API for fetching arbitrary URLs.",
        })
    end

    if source:find("while%s+true%s+do") then
        table.insert(messages, {
            Level = "warn",
            Message = "A while true loop was found. Ensure it yields, for example with task.wait(), when appropriate.",
        })
    end

    if scriptType == "Script" and source:find("Players%.LocalPlayer") then
        table.insert(messages, {
            Level = "warn",
            Message = "Players.LocalPlayer is client-side; this code may not work in a server Script.",
        })
    end

    table.insert(messages, {
        Level = "info",
        Message = ("Review finished: %d line(s), %d character(s). No code was executed."):format(
            lineCount,
            #source
        ),
    })

    return messages
end

function Backend.attach(ui)
    assert(type(ui) == "table", "XfinBackend.attach expects a UI object")

    local callbacks = ui.Callbacks
    assert(type(callbacks) == "table", "XfinUI must expose ui.Callbacks")

    -- Source and SavedSource are separate so unsaved drafts survive
    -- when the user opens another file during the current session.
    local scripts = diskLoad()
    local loadedCount = 0
    for _ in pairs(scripts) do loadedCount += 1 end

    if not scripts["Main.lua"] then
        scripts["Main.lua"] = {
            Name = "Main.lua",
            Type = "Luau",
            Source = "",
            SavedSource = "",
            OnDisk = false,
        }
    end

    local current = "Main.lua"

    local function log(level, message)
        if level == "success" then
            safeCall(ui.Success, ui, message)
        elseif level == "warn" then
            safeCall(ui.Warn, ui, message)
        elseif level == "error" then
            safeCall(ui.Error, ui, message)
        else
            safeCall(ui.Info, ui, message)
        end
    end

    local function refreshList()
        safeCall(ui.SetScriptList, ui, copyScriptList(scripts), current)
    end

    local function setSavedStatus(scriptData)
        safeCall(
            ui.SetSaveStatus,
            ui,
            scriptData.Source == scriptData.SavedSource
        )
    end

    local function ensureCurrent()
        if current and scripts[current] then
            return scripts[current]
        end

        local name = "Main.lua"
        local suffix = 1

        while scripts[name] do
            suffix += 1
            name = ("Main%d.lua"):format(suffix)
        end

        scripts[name] = {
            Name = name,
            Type = "Luau",
            Source = "",
            SavedSource = "",
            OnDisk = false,
        }

        current = name
        return scripts[name]
    end

    local function showScript(name, message)
        local scriptData = scripts[name]
        if not scriptData then
            log("error", "Script not found: " .. tostring(name))
            return
        end

        current = name

        safeCall(ui.SetFileName, ui, scriptData.Name)
        safeCall(ui.SetSource, ui, scriptData.Source)
        setSavedStatus(scriptData)

        if message then
            log("info", message .. scriptData.Name)
        end
    end

    function callbacks.ListScripts()
        refreshList()
    end

    function callbacks.CreateScript(name)
        local normalized, nameError = normalizeName(name)
        if not normalized then
            log("error", nameError)
            return
        end

        if scripts[normalized] then
            log("error", "A script named " .. normalized .. " already exists.")
            return
        end

        scripts[normalized] = {
            Name = normalized,
            Type = "Luau",
            Source = "",
            SavedSource = "",
            OnDisk = false,
        }

        current = normalized
        refreshList()
        showScript(normalized, "Created: ")
        log("success", "Script created. Press Save to keep it.")
    end

    function callbacks.OpenScript(name)
        if type(name) ~= "string" then
            log("error", "Invalid script name.")
            return
        end

        showScript(name, "Opened: ")
    end

    function callbacks.SaveScript(name, source)
        local normalized, nameError = normalizeName(name)
        if not normalized then
            log("error", nameError)
            return
        end

        if type(source) ~= "string" then
            log("error", "Script source must be text.")
            return
        end

        if #source > MAX_SOURCE_LENGTH then
            log("error", "The source is too large to save in this editor session.")
            return
        end

        local existingTarget = scripts[normalized]
        if existingTarget and normalized ~= current then
            log("error", "A script named " .. normalized .. " already exists.")
            return
        end

        local active = scripts[current]
        local scriptType = existingTarget and existingTarget.Type
            or (active and active.Type)
            or "Luau"

        -- Saving under a different, unused name behaves like Save As.
        local okDisk, diskError = diskSave(normalized, source)

        scripts[normalized] = {
            Name = normalized,
            Type = scriptType,
            Source = source,
            SavedSource = source,
            OnDisk = okDisk,
        }

        current = normalized

        if okDisk then writeIndex(scripts) end

        safeCall(ui.SetFileName, ui, normalized)
        safeCall(ui.SetSaveStatus, ui, true)
        refreshList()

        if okDisk then
            log("success", "Saved to disk: " .. SCRIPT_DIR .. "/" .. normalized)
        else
            log("warn", "Saved for this session only (" .. tostring(diskError or "no file access") .. "): " .. normalized)
        end
    end

    function callbacks.DeleteScript(name)
        if type(name) ~= "string" or not scripts[name] then
            log("error", "Script not found: " .. tostring(name))
            return
        end

        local wasOnDisk = scripts[name].OnDisk
        scripts[name] = nil
        log("info", "Deleted: " .. name)

        if wasOnDisk then
            local removed = diskDelete(name)
            writeIndex(scripts)
            if not removed then
                log("warn", "Removed from the list, but this executor can't delete files, so the file may return next launch.")
            end
        end

        if current == name then
            current = nil
            ensureCurrent()
            showScript(current)
        end

        refreshList()
    end

    function callbacks.RenameScript(oldName, newName)
        if type(oldName) ~= "string" or not scripts[oldName] then
            log("error", "Script not found: " .. tostring(oldName))
            return
        end

        local normalized, nameError = normalizeName(newName)
        if not normalized then
            log("error", nameError)
            return
        end

        if normalized ~= oldName and scripts[normalized] then
            log("error", "A script named " .. normalized .. " already exists.")
            return
        end

        if normalized == oldName then
            log("info", "The filename has not changed.")
            return
        end

        local scriptData = scripts[oldName]
        scripts[oldName] = nil
        scriptData.Name = normalized
        scripts[normalized] = scriptData

        if scriptData.OnDisk then
            local okDisk = diskSave(normalized, scriptData.SavedSource)
            if okDisk then
                diskDelete(oldName)
            end
            scriptData.OnDisk = okDisk
            writeIndex(scripts)
        end

        if current == oldName then
            current = normalized
            safeCall(ui.SetFileName, ui, normalized)
            setSavedStatus(scriptData)
        end

        refreshList()
        log("success", ("Renamed %s to %s"):format(oldName, normalized))
    end

    function callbacks.RequestTemplate(id)
        local template = getTemplate(id)
        if not template then
            log("error", "Unknown template: " .. tostring(id))
            return
        end

        local scriptData = ensureCurrent()
        scriptData.Source = template.Source

        if VALID_TYPES[template.Type] then
            scriptData.Type = template.Type
        end

        safeCall(ui.SetSource, ui, template.Source)
        safeCall(ui.SetFileName, ui, scriptData.Name)
        safeCall(ui.SetSaveStatus, ui, false)

        refreshList()
        log("info", "Template inserted: " .. template.Name)
    end

    function callbacks.RequestTestOperations()
        safeCall(ui.SetSupportedOperations, ui, {
            {
                Id = "source-review",
                Label = "Review source",
                Description = "Checks for a few common issues. This is not a compiler and does not execute code.",
            },
        })
    end

    function callbacks.RunTestOperation(id, source)
        if id ~= "source-review" then
            log("error", "Unsupported operation: " .. tostring(id))
            return
        end

        if type(source) ~= "string" then
            log("error", "No source text was provided.")
            return
        end

        if #source > MAX_SOURCE_LENGTH then
            log("error", "Source is too large to review.")
            return
        end

        local active = scripts[current]
        local scriptType = active and active.Type or "Luau"
        local messages = reviewSource(source, scriptType)

        for _, item in ipairs(messages) do
            log(item.Level, item.Message)
        end
    end

    -- Copy the current script so it can be pasted into GitHub (or anywhere else).
    function callbacks.CopyScript(name, source)
        if type(source) ~= "string" or source == "" then
            log("warn", "Nothing to copy.")
            return
        end

        if type(setclipboard) ~= "function" then
            log("warn", "This executor has no setclipboard, so the script can't be copied.")
            return
        end

        local ok = pcall(setclipboard, source)
        if ok then
            log("success", "Copied " .. tostring(name) .. " to the clipboard.")
        else
            log("error", "Copy failed.")
        end
    end

    -- Optional callback exposed by XfinUI.
    function callbacks.SourceChanged(source)
        if type(source) ~= "string" then
            return
        end

        if #source > MAX_SOURCE_LENGTH then
            log("warn", "Source exceeds the editor's session size limit.")
            return
        end

        local scriptData = ensureCurrent()
        scriptData.Source = source
        setSavedStatus(scriptData)
    end

    -- Initialize the UI.
    local templateList = {}

    for _, template in ipairs(TEMPLATES) do
        table.insert(templateList, {
            Id = template.Id,
            Name = template.Name,
            Description = template.Description,
        })
    end

    safeCall(ui.SetTemplates, ui, templateList)
    safeCall(ui.SetSupportedOperations, ui, {})
    refreshList()
    showScript(current)

    if canWrite() then
        log("success", ("XFIN ready. Saved scripts live in %s (%d loaded)."):format(SCRIPT_DIR, loadedCount))
    else
        log("warn", "XFIN ready, but this executor has no file access. Scripts are session-only.")
    end

    return {
        GetCurrentName = function()
            return current
        end,

        GetScriptList = function()
            return copyScriptList(scripts)
        end,
    }
end

return Backend
