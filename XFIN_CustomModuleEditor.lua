-- XFIN_CustomModuleEditor.lua
-- Test build for the XFIN custom-module editor workflow.
-- Run this source through the existing XFIN execution path in the client environment.
-- This does NOT intercept Roblox's native require() function.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
if not player then
    error("XFIN_CustomModuleEditor must run in a client environment with Players.LocalPlayer.")
end

local root = Workspace:FindFirstChild("XFIN SCRIPT INSTANCE")
if not root then
    error('Missing Workspace["XFIN SCRIPT INSTANCE"]. Create that folder and put your ModuleScripts inside it.')
end

local playerGui = player:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild("XFIN_CustomModuleEditor")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "XFIN_CustomModuleEditor"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 1000
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "XFIN_EditorFrame"
frame.Size = UDim2.new(0.88, 0, 0.76, 0)
frame.Position = UDim2.new(0.06, 0, 0.12, 0)
frame.BackgroundColor3 = Color3.fromRGB(27, 29, 35)
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -52, 0, 38)
title.Position = UDim2.new(0, 12, 0, 3)
title.BackgroundTransparency = 1
title.Text = "XFIN Custom Module Editor — TEST"
title.TextColor3 = Color3.fromRGB(240, 242, 248)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local close = Instance.new("TextButton")
close.Name = "CloseButton"
close.Size = UDim2.new(0, 34, 0, 30)
close.Position = UDim2.new(1, -42, 0, 7)
close.Text = "×"
close.TextSize = 22
close.Font = Enum.Font.GothamBold
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.BackgroundColor3 = Color3.fromRGB(160, 55, 65)
close.Parent = frame
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)
close.MouseButton1Click:Connect(function() gui:Destroy() end)

local moduleLabel = Instance.new("TextLabel")
moduleLabel.Name = "ModuleLabel"
moduleLabel.Size = UDim2.new(0, 90, 0, 30)
moduleLabel.Position = UDim2.new(0, 12, 0, 47)
moduleLabel.BackgroundTransparency = 1
moduleLabel.Text = "Module:"
moduleLabel.TextColor3 = Color3.fromRGB(220, 224, 234)
moduleLabel.Font = Enum.Font.Gotham
moduleLabel.TextSize = 13
moduleLabel.TextXAlignment = Enum.TextXAlignment.Left
moduleLabel.Parent = frame

local moduleButton = Instance.new("TextButton")
moduleButton.Name = "ModulePicker"
moduleButton.Size = UDim2.new(0.54, 0, 0, 30)
moduleButton.Position = UDim2.new(0, 95, 0, 47)
moduleButton.BackgroundColor3 = Color3.fromRGB(47, 51, 61)
moduleButton.TextColor3 = Color3.fromRGB(245, 245, 250)
moduleButton.Font = Enum.Font.Gotham
moduleButton.TextSize = 13
moduleButton.Text = "Choose Module ▾"
moduleButton.Parent = frame
Instance.new("UICorner", moduleButton).CornerRadius = UDim.new(0, 6)

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -24, 0, 24)
status.Position = UDim2.new(0, 12, 1, -30)
status.BackgroundTransparency = 1
status.Text = "Choose a ModuleScript, edit source, then Save."
status.TextColor3 = Color3.fromRGB(177, 190, 205)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextTruncate = Enum.TextTruncate.AtEnd
status.Parent = frame

local editor = Instance.new("TextBox")
editor.Name = "XFIN_CodeBox"
editor.Size = UDim2.new(1, -24, 1, -150)
editor.Position = UDim2.new(0, 12, 0, 86)
editor.BackgroundColor3 = Color3.fromRGB(17, 19, 24)
editor.TextColor3 = Color3.fromRGB(226, 232, 240)
editor.PlaceholderColor3 = Color3.fromRGB(120, 130, 145)
editor.PlaceholderText = "Select a ModuleScript to load its XFIN_Soruse source..."
editor.Font = Enum.Font.Code
editor.TextSize = 14
editor.TextXAlignment = Enum.TextXAlignment.Left
editor.TextYAlignment = Enum.TextYAlignment.Top
editor.ClearTextOnFocus = false
editor.MultiLine = true
editor.TextWrapped = false
editor.Text = ""
editor.Parent = frame
Instance.new("UICorner", editor).CornerRadius = UDim.new(0, 6)

-- SaveCode is an ObjectValue child of the editor frame and points to that frame.
-- ObjectValue stores an Instance reference; the actual code is stored in XFIN_Soruse.
local saveCode = Instance.new("ObjectValue")
saveCode.Name = "SaveCode"
saveCode.Value = frame
saveCode.Parent = frame

local saveButton = Instance.new("TextButton")
saveButton.Name = "SaveButton"
saveButton.Size = UDim2.new(0, 94, 0, 30)
saveButton.Position = UDim2.new(1, -206, 1, -66)
saveButton.BackgroundColor3 = Color3.fromRGB(45, 112, 82)
saveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
saveButton.Text = "Save Source"
saveButton.Font = Enum.Font.GothamBold
saveButton.TextSize = 12
saveButton.Parent = frame
Instance.new("UICorner", saveButton).CornerRadius = UDim.new(0, 6)

local runButton = Instance.new("TextButton")
runButton.Name = "RunButton"
runButton.Size = UDim2.new(0, 94, 0, 30)
runButton.Position = UDim2.new(1, -106, 1, -66)
runButton.BackgroundColor3 = Color3.fromRGB(55, 94, 160)
runButton.TextColor3 = Color3.fromRGB(255, 255, 255)
runButton.Text = "Test Run"
runButton.Font = Enum.Font.GothamBold
runButton.TextSize = 12
runButton.Parent = frame
Instance.new("UICorner", runButton).CornerRadius = UDim.new(0, 6)

local picker = Instance.new("ScrollingFrame")
picker.Name = "ModuleList"
picker.Size = UDim2.new(0.54, 0, 0, 0)
picker.Position = UDim2.new(0, 95, 0, 80)
picker.BackgroundColor3 = Color3.fromRGB(37, 40, 48)
picker.BorderSizePixel = 0
picker.ScrollBarThickness = 5
picker.Visible = false
picker.ZIndex = 5
picker.CanvasSize = UDim2.new(0, 0, 0, 0)
picker.Parent = frame
Instance.new("UICorner", picker).CornerRadius = UDim.new(0, 6)

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 3)
listLayout.SortOrder = Enum.SortOrder.Name
listLayout.Parent = picker

local selectedModule = nil
local moduleConnections = {}
local function setStatus(message, color)
    status.Text = message
    status.TextColor3 = color or Color3.fromRGB(177, 190, 205)
end

local function getOrCreateSourceValue(moduleScript)
    local value = moduleScript:FindFirstChild("XFIN_Soruse")
    if not value then
        value = Instance.new("StringValue")
        value.Name = "XFIN_Soruse" -- Preserve the project's exact spelling.
        value.Value = ""
        value.Parent = moduleScript
    end
    if not value:IsA("StringValue") then
        error(moduleScript:GetFullName() .. ".XFIN_Soruse exists but is not a StringValue.")
    end
    return value
end

local function selectModule(moduleScript)
    selectedModule = moduleScript
    moduleButton.Text = moduleScript.Name .. " ▾"
    local ok, sourceValue = pcall(getOrCreateSourceValue, moduleScript)
    if not ok then
        editor.Text = ""
        setStatus(tostring(sourceValue), Color3.fromRGB(255, 120, 120))
        return
    end
    editor.Text = sourceValue.Value
    -- Keep a SaveChangesTo reference if the project already has that value.
    local saveChangesTo = moduleScript:FindFirstChild("SaveChangesTo")
    if saveChangesTo and saveChangesTo:IsA("ObjectValue") then
        -- Do not overwrite Studio Lite's existing target; just report it for debugging.
        setStatus("Selected " .. moduleScript.Name .. " • source loaded • SaveChangesTo=" .. (saveChangesTo.Value and saveChangesTo.Value.Name or "nil"))
    else
        setStatus("Selected " .. moduleScript.Name .. " • source loaded • no SaveChangesTo ObjectValue found")
    end
    picker.Visible = false
end

local function rebuildPicker()
    for _, child in ipairs(picker:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local modules = {}
    for _, child in ipairs(root:GetDescendants()) do
        if child:IsA("ModuleScript") then table.insert(modules, child) end
    end
    table.sort(modules, function(a, b) return a:GetFullName() < b:GetFullName() end)
    for index, moduleScript in ipairs(modules) do
        local button = Instance.new("TextButton")
        button.Name = string.format("Module_%03d", index)
        button.Size = UDim2.new(1, -8, 0, 28)
        button.BackgroundColor3 = Color3.fromRGB(52, 57, 68)
        button.TextColor3 = Color3.fromRGB(235, 238, 245)
        button.Font = Enum.Font.Gotham
        button.TextSize = 12
        button.TextXAlignment = Enum.TextXAlignment.Left
        button.Text = "  " .. moduleScript.Name
        button.ZIndex = 6
        button.Parent = picker
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, 4)
        button.MouseButton1Click:Connect(function() selectModule(moduleScript) end)
    end
    task.defer(function()
        picker.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 6)
        picker.Size = UDim2.new(0.54, 0, 0, math.min(180, listLayout.AbsoluteContentSize.Y + 8))
    end)
    if #modules == 0 then
        setStatus('No ModuleScripts found under Workspace["XFIN SCRIPT INSTANCE"].', Color3.fromRGB(255, 190, 110))
    end
end

moduleButton.MouseButton1Click:Connect(function()
    picker.Visible = not picker.Visible
    if picker.Visible then rebuildPicker() end
end)

saveButton.MouseButton1Click:Connect(function()
    if not selectedModule then
        setStatus("Select a ModuleScript first.", Color3.fromRGB(255, 190, 110))
        return
    end
    local ok, result = pcall(function()
        local sourceValue = getOrCreateSourceValue(selectedModule)
        sourceValue.Value = editor.Text
        return sourceValue
    end)
    if ok then
        setStatus("Saved " .. #editor.Text .. " characters to " .. selectedModule.Name .. ".XFIN_Soruse", Color3.fromRGB(130, 225, 165))
    else
        setStatus("Save failed: " .. tostring(result), Color3.fromRGB(255, 120, 120))
    end
end)

runButton.MouseButton1Click:Connect(function()
    if not selectedModule then
        setStatus("Select a ModuleScript first.", Color3.fromRGB(255, 190, 110))
        return
    end
    -- Save first, then execute the saved source through the same client loadstring capability
    -- expected by XFIN's existing execution environment. This is a test button, not native require.
    local okSave, sourceValue = pcall(getOrCreateSourceValue, selectedModule)
    if not okSave then
        setStatus("Cannot read source value: " .. tostring(sourceValue), Color3.fromRGB(255, 120, 120))
        return
    end
    sourceValue.Value = editor.Text
    if type(loadstring) ~= "function" then
        setStatus("This environment has no loadstring. Use XFIN's existing Run button to execute the saved source.", Color3.fromRGB(255, 190, 110))
        return
    end
    local compiled, chunkOrError, compileError = pcall(loadstring, sourceValue.Value, "@XFIN/" .. selectedModule.Name)
    if not compiled then
        setStatus("Compile call failed: " .. tostring(chunkOrError), Color3.fromRGB(255, 120, 120))
        return
    end
    if type(chunkOrError) ~= "function" then
        setStatus("Compile failed: " .. tostring(compileError or chunkOrError), Color3.fromRGB(255, 120, 120))
        return
    end
    local ran, runError = pcall(chunkOrError)
    if ran then
        setStatus("Executed saved source for " .. selectedModule.Name .. ".", Color3.fromRGB(130, 225, 165))
    else
        setStatus("Runtime error: " .. tostring(runError), Color3.fromRGB(255, 120, 120))
    end
end)

-- Drag the editor window on touch/mouse.
do
    local dragging, dragInput, dragStart, startPos
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    title.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

rebuildPicker()
setStatus("Ready. Choose RagdollModule, edit XFIN_CodeBox, Save Source, then Test Run.")
return gui
