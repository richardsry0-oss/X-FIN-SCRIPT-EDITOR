-- XFIN Script Editor UI
-- Mobile-friendly editor UI with Run, size controls, and a client-visible instance explorer.
-- This module does not itself execute source. Wire ui.Callbacks.RunScript in the loader/backend.

local XfinUI = {}
XfinUI.__index = XfinUI

local function make(className, props, parent)
    local obj = Instance.new(className)
    for key, value in pairs(props or {}) do
        pcall(function() obj[key] = value end)
    end
    obj.Parent = parent
    return obj
end

local function corner(parent, radius)
    return make("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
end

local function stroke(parent, color, thickness)
    return make("UIStroke", { Color = color or Color3.fromRGB(57, 61, 72), Thickness = thickness or 1 }, parent)
end

local function textButton(parent, text, size, position, color)
    local button = make("TextButton", {
        Name = text:gsub("%W", "") .. "Button",
        Size = size,
        Position = position,
        BackgroundColor3 = color or Color3.fromRGB(43, 47, 58),
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = Color3.fromRGB(240, 242, 247),
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = true,
    }, parent)
    corner(button, 5)
    return button
end

local function textLabel(parent, text, size, position, sizeText, color)
    return make("TextLabel", {
        Size = size,
        Position = position,
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = color or Color3.fromRGB(220, 224, 234),
        TextSize = sizeText or 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
end

function XfinUI.new(playerGui)
    assert(playerGui, "XfinUI.new requires a PlayerGui")
    local self = setmetatable({}, XfinUI)
    self.Callbacks = {}
    self._explorerExpanded = {}
    self._explorerSelected = nil
    self._explorerRows = {}
    self._scriptNames = {}

    local old = playerGui:FindFirstChild("XFINScriptEditor")
    if old then old:Destroy() end

    local gui = make("ScreenGui", {
        Name = "XFINScriptEditor",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 100,
    }, playerGui)
    self.Gui = gui

    local root = make("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0.92, 0, 0, 480),
        BackgroundColor3 = Color3.fromRGB(22, 24, 30),
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, gui)
    corner(root, 10)
    stroke(root, Color3.fromRGB(65, 70, 83), 1)
    self.Root = root

    local sizeConstraint = make("UISizeConstraint", {
        MinSize = Vector2.new(300, 340),
        MaxSize = Vector2.new(1000, 760),
    }, root)
    self.SizeConstraint = sizeConstraint

    local header = make("Frame", {
        Name = "Header", Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = Color3.fromRGB(30, 33, 41), BorderSizePixel = 0,
    }, root)
    self.Header = header
    textLabel(header, "XFIN  /  SCRIPT EDITOR", UDim2.new(1, -82, 1, 0), UDim2.new(0, 12, 0, 0), 13, Color3.fromRGB(248, 249, 252)).Font = Enum.Font.GothamBold
    local close = textButton(header, "×", UDim2.fromOffset(32, 28), UDim2.new(1, -38, 0, 5), Color3.fromRGB(110, 47, 55))
    close.TextSize = 20
    close.MouseButton1Click:Connect(function() gui:Destroy() end)

    local toolbar = make("ScrollingFrame", {
        Name = "Toolbar", Position = UDim2.new(0, 8, 0, 44), Size = UDim2.new(1, -16, 0, 34),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollingDirection = Enum.ScrollingDirection.X, CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
    }, root)
    local toolbarLayout = make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
    }, toolbar)
    self.Toolbar = toolbar

    local function tool(text, width, order, color)
        local b = textButton(toolbar, text, UDim2.fromOffset(width, 29), UDim2.new(), color)
        b.LayoutOrder = order
        return b
    end
    local newButton = tool("New", 48, 1)
    local saveButton = tool("Save", 50, 2, Color3.fromRGB(43, 83, 66))
    local runButton = tool("▶ Run", 58, 3, Color3.fromRGB(40, 105, 72))
    local clearButton = tool("Clear", 48, 4)
    local reviewButton = tool("Review", 54, 5)
    local explorerButton = tool("Explorer", 64, 6)
    local sizeButton = tool("Size", 45, 7)
    self.RunButton = runButton

    local bodyTop = 84
    local footerHeight = 24
    local body = make("Frame", {
        Name = "Body", Position = UDim2.new(0, 8, 0, bodyTop),
        Size = UDim2.new(1, -16, 1, -(bodyTop + footerHeight + 8)),
        BackgroundTransparency = 1, BorderSizePixel = 0,
    }, root)
    self.Body = body

    local sidebar = make("Frame", {
        Name = "Sidebar", Size = UDim2.new(0, 132, 1, 0),
        BackgroundColor3 = Color3.fromRGB(28, 31, 38), BorderSizePixel = 0,
    }, body)
    corner(sidebar, 6)
    self.Sidebar = sidebar

    local fileName = make("TextBox", {
        Name = "FileName", Position = UDim2.new(0, 6, 0, 6), Size = UDim2.new(1, -12, 0, 29),
        BackgroundColor3 = Color3.fromRGB(17, 19, 24), BorderSizePixel = 0,
        Text = "Main.lua", PlaceholderText = "File name", ClearTextOnFocus = false,
        TextColor3 = Color3.fromRGB(242, 244, 249), PlaceholderColor3 = Color3.fromRGB(130, 135, 148),
        TextSize = 12, Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Left,
    }, sidebar)
    corner(fileName, 5)
    self.FileName = fileName

    textLabel(sidebar, "YOUR SCRIPTS", UDim2.new(1, -12, 0, 20), UDim2.new(0, 6, 0, 40), 10, Color3.fromRGB(153, 162, 180)).Font = Enum.Font.GothamBold
    local fileList = make("ScrollingFrame", {
        Name = "ScriptList", Position = UDim2.new(0, 5, 0, 62), Size = UDim2.new(1, -10, 0.42, -62),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, sidebar)
    local fileLayout = make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, fileList)
    self.FileList = fileList

    local deleteButton = textButton(sidebar, "Delete current", UDim2.new(1, -10, 0, 25), UDim2.new(0, 5, 0.47, -2), Color3.fromRGB(87, 43, 49))
    deleteButton.TextSize = 11
    textLabel(sidebar, "TEMPLATES", UDim2.new(1, -12, 0, 20), UDim2.new(0, 6, 0.47, 25), 10, Color3.fromRGB(153, 162, 180)).Font = Enum.Font.GothamBold
    local templateList = make("ScrollingFrame", {
        Name = "TemplateList", Position = UDim2.new(0, 5, 0.47, 47), Size = UDim2.new(1, -10, 0.53, -52),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, sidebar)
    make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, templateList)
    self.TemplateList = templateList

    local editorPanel = make("Frame", {
        Name = "EditorPanel", Position = UDim2.new(0, 140, 0, 0), Size = UDim2.new(1, -140, 1, 0),
        BackgroundColor3 = Color3.fromRGB(17, 19, 24), BorderSizePixel = 0,
    }, body)
    corner(editorPanel, 6)
    self.EditorPanel = editorPanel

    local editor = make("TextBox", {
        Name = "CodeEditor", Position = UDim2.new(0, 7, 0, 7), Size = UDim2.new(1, -14, 1, -14),
        BackgroundColor3 = Color3.fromRGB(17, 19, 24), BorderSizePixel = 0,
        Text = "", PlaceholderText = "-- Write Luau here...", ClearTextOnFocus = false,
        MultiLine = true, TextWrapped = false, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(222, 229, 240),
        PlaceholderColor3 = Color3.fromRGB(100, 108, 124), TextSize = 13, Font = Enum.Font.Code,
    }, editorPanel)
    self.Editor = editor

    local explorer = make("Frame", {
        Name = "ExplorerPanel", Visible = false, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.72, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(25, 28, 35), BorderSizePixel = 0, ZIndex = 10,
    }, body)
    corner(explorer, 7)
    stroke(explorer, Color3.fromRGB(70, 76, 91), 1)
    self.ExplorerPanel = explorer
    textLabel(explorer, "INSTANCE EXPLORER", UDim2.new(1, -82, 0, 30), UDim2.new(0, 8, 0, 0), 11, Color3.fromRGB(245, 246, 250)).ZIndex = 11
    local refreshExplorer = textButton(explorer, "↻", UDim2.fromOffset(27, 24), UDim2.new(1, -62, 0, 3), Color3.fromRGB(42, 67, 87))
    refreshExplorer.ZIndex = 11
    local closeExplorer = textButton(explorer, "×", UDim2.fromOffset(27, 24), UDim2.new(1, -31, 0, 3), Color3.fromRGB(95, 44, 51))
    closeExplorer.ZIndex = 11
    local tree = make("ScrollingFrame", {
        Name = "Tree", Position = UDim2.new(0, 5, 0, 32), Size = UDim2.new(0.53, -6, 1, -38),
        BackgroundColor3 = Color3.fromRGB(18, 20, 26), BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 11,
    }, explorer)
    corner(tree, 5)
    make("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, tree)
    self.ExplorerTree = tree
    local details = make("ScrollingFrame", {
        Name = "Details", Position = UDim2.new(0.53, 2, 0, 32), Size = UDim2.new(0.47, -7, 1, -38),
        BackgroundColor3 = Color3.fromRGB(18, 20, 26), BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 11,
    }, explorer)
    corner(details, 5)
    make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, details)
    self.ExplorerDetails = details

    local footer = textLabel(root, "Ready", UDim2.new(1, -16, 0, footerHeight), UDim2.new(0, 8, 1, -(footerHeight + 3)), 11, Color3.fromRGB(151, 161, 180))
    footer.Name = "Status"
    self.StatusLabel = footer

    local sizePanel = make("Frame", {
        Name = "SizeSettings", Visible = false, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -8, 0, 82), Size = UDim2.fromOffset(210, 128),
        BackgroundColor3 = Color3.fromRGB(31, 34, 42), BorderSizePixel = 0, ZIndex = 20,
    }, root)
    corner(sizePanel, 8)
    stroke(sizePanel, Color3.fromRGB(78, 84, 99), 1)
    textLabel(sizePanel, "WINDOW SIZE (PX)", UDim2.new(1, -12, 0, 22), UDim2.new(0, 7, 0, 4), 10, Color3.fromRGB(244, 245, 249)).ZIndex = 21
    textLabel(sizePanel, "Width", UDim2.fromOffset(42, 24), UDim2.new(0, 8, 0, 31), 11).ZIndex = 21
    local widthInput = make("TextBox", {
        Size = UDim2.fromOffset(82, 24), Position = UDim2.new(0, 54, 0, 31),
        BackgroundColor3 = Color3.fromRGB(16, 18, 23), BorderSizePixel = 0,
        Text = "360", TextColor3 = Color3.fromRGB(245, 246, 250), TextSize = 12,
        Font = Enum.Font.Code, ClearTextOnFocus = false, ZIndex = 21,
    }, sizePanel)
    corner(widthInput, 4)
    textLabel(sizePanel, "Height", UDim2.fromOffset(42, 24), UDim2.new(0, 8, 0, 61), 11).ZIndex = 21
    local heightInput = make("TextBox", {
        Size = UDim2.fromOffset(82, 24), Position = UDim2.new(0, 54, 0, 61),
        BackgroundColor3 = Color3.fromRGB(16, 18, 23), BorderSizePixel = 0,
        Text = "480", TextColor3 = Color3.fromRGB(245, 246, 250), TextSize = 12,
        Font = Enum.Font.Code, ClearTextOnFocus = false, ZIndex = 21,
    }, sizePanel)
    corner(heightInput, 4)
    local applySize = textButton(sizePanel, "Apply", UDim2.fromOffset(58, 54), UDim2.new(1, -66, 0, 31), Color3.fromRGB(42, 84, 65))
    applySize.ZIndex = 21

    local function invoke(name, ...)
        local callback = self.Callbacks[name]
        if type(callback) == "function" then
            local ok, err = pcall(callback, ...)
            if not ok then self:Error(name .. " failed: " .. tostring(err)) end
        else
            self:Warn("Action not connected: " .. name)
        end
    end
    self.Invoke = invoke

    local function clearChildren(frame, keepLayout)
        for _, child in ipairs(frame:GetChildren()) do
            if not (keepLayout and child:IsA("UIListLayout")) then child:Destroy() end
        end
    end

    function self:Info(message) footer.Text = tostring(message); footer.TextColor3 = Color3.fromRGB(151, 183, 220) end
    function self:Success(message) footer.Text = tostring(message); footer.TextColor3 = Color3.fromRGB(119, 220, 158) end
    function self:Warn(message) footer.Text = tostring(message); footer.TextColor3 = Color3.fromRGB(238, 194, 111) end
    function self:Error(message) footer.Text = tostring(message); footer.TextColor3 = Color3.fromRGB(242, 123, 123) end
    function self:SetFileName(name) fileName.Text = tostring(name or "Main.lua") end
    function self:SetSource(source) editor.Text = tostring(source or "") end
    function self:GetSource() return editor.Text end
    function self:GetFileName() return fileName.Text end
    function self:SetSaveStatus(message) self:Info(message or "Saved") end

    function self:SetScriptList(items, current)
        clearChildren(fileList, true)
        self._scriptNames = {}
        for index, item in ipairs(items or {}) do
            local name = type(item) == "table" and item.Name or tostring(item)
            self._scriptNames[name] = true
            local row = textButton(fileList, name, UDim2.new(1, 0, 0, 25), UDim2.new(), name == current and Color3.fromRGB(45, 61, 82) or Color3.fromRGB(36, 39, 47))
            row.LayoutOrder = index
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.TextSize = 11
            row.MouseButton1Click:Connect(function() invoke("OpenScript", name) end)
        end
    end

    function self:SetTemplates(items)
        clearChildren(templateList, true)
        for index, item in ipairs(items or {}) do
            local id = type(item) == "table" and (item.Id or item.ID or item.Name) or tostring(item)
            local title = type(item) == "table" and (item.Name or item.Title or id) or tostring(item)
            local row = textButton(templateList, "+ " .. tostring(title), UDim2.new(1, 0, 0, 25), UDim2.new(), Color3.fromRGB(37, 43, 51))
            row.LayoutOrder = index
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.TextSize = 11
            row.MouseButton1Click:Connect(function() invoke("RequestTemplate", id) end)
        end
    end

    function self:SetSupportedOperations(items)
        -- Kept for compatibility with the existing backend.
        self.SupportedOperations = items or {}
    end

    local function refreshExplorerTree()
        clearChildren(tree, true)
        self._explorerRows = {}
        local roots = {}
        local ok, children = pcall(function() return game:GetChildren() end)
        if ok and type(children) == "table" then
            for _, child in ipairs(children) do table.insert(roots, child) end
        end
        -- Add useful services only when the current client can obtain them.
        local serviceNames = { "Workspace", "Players", "Lighting", "ReplicatedStorage", "ReplicatedFirst", "StarterGui", "StarterPlayer", "ServerScriptService", "ServerStorage", "SoundService", "Teams", "TextChatService" }
        local seen = {}
        for _, obj in ipairs(roots) do seen[obj] = true end
        for _, serviceName in ipairs(serviceNames) do
            local got, service = pcall(function() return game:GetService(serviceName) end)
            if got and service and not seen[service] then table.insert(roots, service); seen[service] = true end
        end
        table.sort(roots, function(a, b) return a.Name:lower() < b.Name:lower() end)

        local renderNode
        renderNode = function(obj, depth, order)
            if depth > 5 then return end
            local childrenOfObj = {}
            local childrenOk, found = pcall(function() return obj:GetChildren() end)
            if childrenOk then childrenOfObj = found end
            local expanded = self._explorerExpanded[obj] == true
            local prefix = string.rep("  ", depth) .. (#childrenOfObj > 0 and (expanded and "▾ " or "▸ ") or "  ")
            local label = prefix .. obj.Name .. "  [" .. obj.ClassName .. "]"
            local row = textButton(tree, label, UDim2.new(1, -4, 0, 23), UDim2.new(), self._explorerSelected == obj and Color3.fromRGB(52, 73, 98) or Color3.fromRGB(29, 32, 39))
            row.LayoutOrder = order
            row.Size = UDim2.new(1, -4, 0, 23)
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.TextSize = 10
            row.ZIndex = 12
            self._explorerRows[obj] = row
            row.MouseButton1Click:Connect(function()
                self._explorerSelected = obj
                if #childrenOfObj > 0 then self._explorerExpanded[obj] = not expanded end
                self:ShowInstanceDetails(obj)
                refreshExplorerTree()
            end)
            order = order + 1
            if expanded then
                table.sort(childrenOfObj, function(a, b) return a.Name:lower() < b.Name:lower() end)
                for _, child in ipairs(childrenOfObj) do order = renderNode(child, depth + 1, order) end
            end
            return order
        end
        local order = 1
        for _, obj in ipairs(roots) do order = renderNode(obj, 0, order) end
    end

    function self:ShowInstanceDetails(obj)
        clearChildren(details, true)
        if not obj then return end
        local function line(label, value, order)
            local item = make("TextLabel", {
                Name = "Property", Size = UDim2.new(1, -8, 0, 31), BackgroundColor3 = Color3.fromRGB(27, 30, 37),
                BorderSizePixel = 0, Text = label .. "\n" .. tostring(value), TextColor3 = Color3.fromRGB(220, 225, 235),
                TextSize = 10, Font = Enum.Font.Code, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center, LayoutOrder = order, ZIndex = 12,
            }, details)
            corner(item, 4)
        end
        line("Name", obj.Name, 1)
        line("ClassName", obj.ClassName, 2)
        local parentOk, parentName = pcall(function() return obj.Parent and obj.Parent:GetFullName() or "nil" end)
        line("Parent", parentOk and parentName or "unavailable", 3)
        local count = 0
        pcall(function() count = #obj:GetChildren() end)
        line("Children", count, 4)
        local fullOk, fullName = pcall(function() return obj:GetFullName() end)
        line("FullName", fullOk and fullName or "unavailable", 5)
        local properties = { "Archivable", "Enabled", "Visible", "Value", "Text", "DisplayName", "Health", "WalkSpeed" }
        local order = 6
        for _, property in ipairs(properties) do
            local okProp, value = pcall(function() return obj[property] end)
            if okProp and (type(value) == "string" or type(value) == "number" or type(value) == "boolean") then
                line(property, value, order)
                order = order + 1
            end
        end
    end

    local function showExplorer(show)
        explorer.Visible = show
        if show then refreshExplorerTree() end
    end

    newButton.MouseButton1Click:Connect(function()
        local base = (fileName.Text ~= "" and fileName.Text) or "Script.lua"
        local candidate = base
        local number = 2
        while self._scriptNames[candidate] do
            local stem, extension = base:match("^(.*)(%.[^%.]+)$")
            if not stem then stem, extension = base, ".lua" end
            candidate = stem .. number .. extension
            number = number + 1
        end
        fileName.Text = candidate
        invoke("CreateScript", candidate)
    end)
    saveButton.MouseButton1Click:Connect(function() invoke("SaveScript", fileName.Text, editor.Text) end)
    runButton.MouseButton1Click:Connect(function() invoke("RunScript", fileName.Text, editor.Text) end)
    clearButton.MouseButton1Click:Connect(function() editor.Text = ""; invoke("SourceChanged", "") end)
    reviewButton.MouseButton1Click:Connect(function() invoke("RunTestOperation", "source-review", editor.Text) end)
    explorerButton.MouseButton1Click:Connect(function() showExplorer(not explorer.Visible) end)
    closeExplorer.MouseButton1Click:Connect(function() showExplorer(false) end)
    refreshExplorer.MouseButton1Click:Connect(refreshExplorerTree)
    sizeButton.MouseButton1Click:Connect(function() sizePanel.Visible = not sizePanel.Visible end)
    applySize.MouseButton1Click:Connect(function()
        local width = math.floor(tonumber(widthInput.Text) or 360)
        local height = math.floor(tonumber(heightInput.Text) or 480)
        width = math.clamp(width, 300, 1000)
        height = math.clamp(height, 340, 760)
        root.Size = UDim2.fromOffset(width, height)
        widthInput.Text = tostring(width)
        heightInput.Text = tostring(height)
        sizePanel.Visible = false
        self:Success("Window resized to " .. width .. " × " .. height)
    end)
    deleteButton.MouseButton1Click:Connect(function() invoke("DeleteScript", fileName.Text) end)
    editor:GetPropertyChangedSignal("Text"):Connect(function() invoke("SourceChanged", editor.Text) end)

    -- Drag by the title bar; toolbar/buttons remain independently clickable.
    local UserInputService = game:GetService("UserInputService")
    local dragging, dragInput, dragStart, startPosition
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPosition = root.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            root.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        end
    end)

    return self
end

return XfinUI
