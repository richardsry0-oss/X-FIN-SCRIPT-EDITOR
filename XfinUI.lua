
-- XFIN SCRIPT EDITOR
-- ModuleScript: XfinUI
-- Clean UI for the existing XfinBackend module.
-- Review-only: does not execute editor source.

local XfinUI = {}

local COLORS = {
    Background = Color3.fromRGB(24, 26, 31),
    Panel = Color3.fromRGB(32, 35, 42),
    Editor = Color3.fromRGB(19, 21, 26),
    Border = Color3.fromRGB(57, 61, 71),
    Text = Color3.fromRGB(235, 237, 242),
    Muted = Color3.fromRGB(157, 163, 176),
    Accent = Color3.fromRGB(83, 132, 210),
    Danger = Color3.fromRGB(178, 75, 75),
}

local function make(className, properties, parent)
    local object = Instance.new(className)

    for property, value in pairs(properties or {}) do
        object[property] = value
    end

    object.Parent = parent
    return object
end

local function round(parent, radius)
    make("UICorner", {
        CornerRadius = UDim.new(0, radius or 6),
    }, parent)
end

local function outline(parent)
    make("UIStroke", {
        Color = COLORS.Border,
        Thickness = 1,
    }, parent)
end

local function button(parent, text, width, color)
    local result = make("TextButton", {
        Size = UDim2.new(0, width, 0, 32),
        BackgroundColor3 = color or COLORS.Panel,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = COLORS.Text,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = true,
    }, parent)

    round(result, 5)
    return result
end

local function textBox(parent, placeholder, size, position)
    local result = make("TextBox", {
        Size = size,
        Position = position or UDim2.new(),
        BackgroundColor3 = COLORS.Editor,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = placeholder,
        PlaceholderColor3 = COLORS.Muted,
        TextColor3 = COLORS.Text,
        TextSize = 13,
        Font = Enum.Font.Code,
        ClearTextOnFocus = false,
    }, parent)

    round(result, 5)
    outline(result)
    return result
end

function XfinUI.new(playerGui)
    assert(playerGui, "XfinUI.new requires PlayerGui")

    local screen = make("ScreenGui", {
        Name = "XFINScriptEditor",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        DisplayOrder = 20,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, playerGui)

    local root = make("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0.92, 0, 0.78, 0),
        BackgroundColor3 = COLORS.Background,
        BorderSizePixel = 0,
    }, screen)

    root.Size = UDim2.new(
        0.92, 0,
        0, 480
    )

    make("UISizeConstraint", {
        MinSize = Vector2.new(320, 360),
        MaxSize = Vector2.new(900, 650),
    }, root)

    round(root, 9)
    outline(root)

    local header = make("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 43),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
    }, root)

    round(header, 9)

    make("TextLabel", {
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(0.65, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "XFIN  /  Script Editor",
        TextColor3 = COLORS.Text,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)

    local closeButton = button(
        header, "Close", 55, COLORS.Danger
    )
    closeButton.AnchorPoint = Vector2.new(1, 0.5)
    closeButton.Position = UDim2.new(1, -9, 0.5, 0)
    closeButton.MouseButton1Click:Connect(function()
        screen:Destroy()
    end)

    local toolbar = make("Frame", {
        Name = "Toolbar",
        Position = UDim2.new(0, 10, 0, 51),
        Size = UDim2.new(1, -20, 0, 38),
        BackgroundTransparency = 1,
    }, root)

    local newButton = button(toolbar, "New", 48)
    local saveButton = button(
        toolbar, "Save", 52, COLORS.Accent
    )
    local clearButton = button(toolbar, "Clear", 48)
    local reviewButton = button(toolbar, "Review", 60)

    local function placeButton(item, x)
        item.Position = UDim2.new(0, x, 0, 3)
    end

    placeButton(newButton, 0)
    placeButton(saveButton, 54)
    placeButton(clearButton, 112)
    placeButton(reviewButton, 166)

    local body = make("Frame", {
        Name = "Body",
        Position = UDim2.new(0, 10, 0, 94),
        Size = UDim2.new(1, -20, 1, -132),
        BackgroundTransparency = 1,
    }, root)

    local sidebar = make("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 145, 1, 0),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
    }, body)

    round(sidebar, 6)

    local fileName = textBox(
        sidebar,
        "Filename.lua",
        UDim2.new(1, -12, 0, 30),
        UDim2.new(0, 6, 0, 7)
    )
    fileName.Text = "Main.lua"
    fileName.Font = Enum.Font.Gotham
    fileName.TextSize = 12

    make("TextLabel", {
        Position = UDim2.new(0, 8, 0, 43),
        Size = UDim2.new(1, -16, 0, 22),
        BackgroundTransparency = 1,
        Text = "YOUR SCRIPTS",
        TextColor3 = COLORS.Muted,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, sidebar)

    local fileList = make("ScrollingFrame", {
        Name = "FileList",
        Position = UDim2.new(0, 6, 0, 66),
        Size = UDim2.new(1, -12, 0.42, -66),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, sidebar)

    local fileLayout = make("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, fileList)

    local deleteButton = button(
        sidebar, "Delete current", 125, COLORS.Danger
    )
    deleteButton.AnchorPoint = Vector2.new(0.5, 1)
    deleteButton.Position = UDim2.new(0.5, 0, 1, -7)

    local templateTitle = make("TextLabel", {
        Position = UDim2.new(0, 8, 0.48, 0),
        Size = UDim2.new(1, -16, 0, 22),
        BackgroundTransparency = 1,
        Text = "TEMPLATES",
        TextColor3 = COLORS.Muted,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, sidebar)

    local templateList = make("ScrollingFrame", {
        Name = "Templates",
        Position = UDim2.new(0, 6, 0.48, 23),
        Size = UDim2.new(1, -12, 0.22, -23),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, sidebar)

    make("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, templateList)

    local editorPanel = make("Frame", {
        Name = "EditorPanel",
        Position = UDim2.new(0, 153, 0, 0),
        Size = UDim2.new(1, -153, 1, 0),
        BackgroundColor3 = COLORS.Editor,
        BorderSizePixel = 0,
    }, body)

    round(editorPanel, 6)
    outline(editorPanel)

    local editor = make("TextBox", {
        Name = "Code",
        Position = UDim2.new(0, 9, 0, 9),
        Size = UDim2.new(1, -18, 1, -18),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "-- Write Luau code here",
        PlaceholderColor3 = COLORS.Muted,
        TextColor3 = COLORS.Text,
        TextSize = 14,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = false,
        MultiLine = true,
        ClearTextOnFocus = false,
        TextEditable = true,
    }, editorPanel)

    local footer = make("TextLabel", {
        Name = "Status",
        Position = UDim2.new(0, 10, 1, -29),
        Size = UDim2.new(1, -20, 0, 21),
        BackgroundTransparency = 1,
        Text = "Ready",
        TextColor3 = COLORS.Muted,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, root)

    local ui = {
        Screen = screen,
        Callbacks = {},
    }

    local suppressSourceEvent = false
    local function invoke(name, ...)
        local callback = ui.Callbacks[name]
        if type(callback) == "function" then
            callback(...)
        end
    end

    function ui:Info(message)
        footer.Text = tostring(message)
        footer.TextColor3 = COLORS.Muted
    end

    function ui:Success(message)
        footer.Text = tostring(message)
        footer.TextColor3 = Color3.fromRGB(115, 205, 145)
    end

    function ui:Warn(message)
        footer.Text = tostring(message)
        footer.TextColor3 = Color3.fromRGB(230, 190, 100)
    end

    function ui:Error(message)
        footer.Text = tostring(message)
        footer.TextColor3 = Color3.fromRGB(240, 120, 120)
    end

    function ui:SetFileName(name)
        fileName.Text = tostring(name or "")
    end

    function ui:SetSource(source)
        suppressSourceEvent = true
        editor.Text = source or ""
        suppressSourceEvent = false
    end

    function ui:SetSaveStatus(saved)
        if saved then
            footer.Text = "Saved"
            footer.TextColor3 = Color3.fromRGB(115, 205, 145)
        else
            footer.Text = "Unsaved changes"
            footer.TextColor3 = Color3.fromRGB(230, 190, 100)
        end
    end

    function ui:SetScriptList(scripts)
        for _, child in ipairs(fileList:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        for index, item in ipairs(scripts or {}) do
            local fileButton = button(
                fileList, item.Name, 125
            )
            fileButton.Size = UDim2.new(1, -2, 0, 28)
            fileButton.LayoutOrder = index
            fileButton.TextSize = 11
            fileButton.TextXAlignment = Enum.TextXAlignment.Left

            fileButton.MouseButton1Click:Connect(function()
                invoke("OpenScript", item.Name)
            end)
        end
    end

    function ui:SetTemplates(templates)
        for _, child in ipairs(templateList:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        for index, item in ipairs(templates or {}) do
            local templateButton = button(
                templateList, item.Name, 125
            )
            templateButton.Size = UDim2.new(1, -2, 0, 27)
            templateButton.LayoutOrder = index
            templateButton.TextSize = 11

            templateButton.MouseButton1Click:Connect(function()
                invoke("RequestTemplate", item.Id)
            end)
        end
    end

    function ui:SetSupportedOperations(operations)
        -- The Review button is permanently available in the toolbar.
        -- Backend operations can be exposed here in future versions.
    end

    editor:GetPropertyChangedSignal("Text"):Connect(function()
        if not suppressSourceEvent then
            invoke("SourceChanged", editor.Text)
        end
    end)

    newButton.MouseButton1Click:Connect(function()
        invoke("CreateScript", fileName.Text)
    end)

    saveButton.MouseButton1Click:Connect(function()
        invoke("SaveScript", fileName.Text, editor.Text)
    end)

    clearButton.MouseButton1Click:Connect(function()
        editor.Text = ""
        invoke("SourceChanged", "")
        ui:Info("Editor cleared. Save to keep this draft in the session.")
    end)

    reviewButton.MouseButton1Click:Connect(function()
        invoke("RunTestOperation", "source-review", editor.Text)
    end)

    deleteButton.MouseButton1Click:Connect(function()
        invoke("DeleteScript", fileName.Text)
    end)

    -- Drag the window using its header.
    local dragging = false
    local dragStart
    local startPosition

    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = root.Position
        end
    end)

    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            root.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)

    return ui
end

return XfinUI
