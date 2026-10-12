
local Players = game:GetService("Players")

local BASE = "https://raw.githubusercontent.com/richardsry0-oss/X-FIN-SCRIPT-EDITOR/main/"

local function getModule(filename)
    local url = BASE .. filename
    local source = game:HttpGet(url)
    local fn, err = loadstring(source)

    assert(fn, err or "Compilation failed: " .. filename)

    return fn()
end

local XfinUI = getModule("XfinUI.lua")
local XfinBackend = getModule("XfinBackend.lua")

local player = Players.LocalPlayer
local ui = XfinUI.new(player:WaitForChild("PlayerGui"))

XfinBackend.attach(ui)

-- Connect the Run button
ui.Callbacks.runscript = function(source)
    if type(source) ~= "string" or source:match("^%s*$") then
        ui:Warn("Nothing to run.")
        return
    end

    if type(loadstring) ~= "function" then
        ui:Error("loadstring is unavailable.")
        return
    end

    local okCompile, fn, compileError = pcall(loadstring, source)

    if not okCompile then
        ui:Error("Compile error: " .. tostring(fn))
        return
    end

    if type(fn) ~= "function" then
        ui:Error("Compile error: " .. tostring(compileError))
        return
    end

    local okRun, runtimeError = pcall(fn)

    if not okRun then
        ui:Error("Runtime error: " .. tostring(runtimeError))
        return
    end

    ui:Success("Script executed.")
end

print("XFIN loaded!")
