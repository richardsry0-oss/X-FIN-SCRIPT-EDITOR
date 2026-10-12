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

print("XFIN loaded!")
