-- XFIN SCRIPT EDITER bootstrap (LocalScript).
-- Place this LocalScript, XfinUI and XfinBackend (ModuleScripts) together,
-- e.g. all inside StarterPlayer > StarterPlayerScripts.

local Players = game:GetService("Players")

local XfinUI = require(script.Parent:WaitForChild("XfinUI"))
local XfinBackend = require(script.Parent:WaitForChild("XfinBackend"))

local ui = XfinUI.new(Players.LocalPlayer:WaitForChild("PlayerGui"))
XfinBackend.attach(ui)
