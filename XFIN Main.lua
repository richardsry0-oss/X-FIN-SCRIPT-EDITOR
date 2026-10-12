
local Players = game:GetService("Players")

local BASE = "https://raw.githubusercontent.com/richardsry0-oss/X-FIN-SCRIPT-EDITOR/main/"

local function getModule(filename)
    local url = BASE .. filename
    local source = game:HttpGet(url)
    local fn, err = loadstring(source)

    assert(fn, err or ("Compilation failed: " .. filename))

    return fn()
end

-- Load XFIN modules
local XfinUI = getModule("XfinUI.lua")
local XfinBackend = getModule("XfinBackend.lua")

-- Create the UI
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ui = XfinUI.new(playerGui)

-- Attach the existing script editor backend
XfinBackend.attach(ui)

-- Connect the Run button
ui.Callbacks.RunScript = function(fileName, source)
    if type(source) ~= "string" or source:match("^%s*$") then
        ui:Warn("The editor is empty.")
        return
    end

    if type(loadstring) ~= "function" then
        ui:Error("loadstring is unavailable.")
        return
    end

    -- Compile the source
    local compileOK, fn, compileError = pcall(function()
        return loadstring(source)
    end)

    if not compileOK then
        ui:Error("Compile error: " .. tostring(fn))
        return
    end

    if type(fn) ~= "function" then
        ui:Error("Compile error: " .. tostring(compileError))
        return
    end

    ui:Info("Running " .. tostring(fileName or "script") .. "...")

    -- Execute in the current client/executor environment
    local runOK, result = pcall(fn)

    if not runOK then
        ui:Error("Runtime error: " .. tostring(result))
        return
    end

    ui:Success("Finished running " .. tostring(fileName or "script"))
end

print("XFIN loaded with Run callback!")
