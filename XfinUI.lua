-- XFIN Script Editor UI (v2)
-- Mobile-friendly editor: script tabs (S1/S2/S3), Run button, output console,
-- syntax colors, line numbers, settings panel (saved), reopen launcher.
-- This module does not execute source itself. Wire ui.Callbacks.RunScript in the loader.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local XfinUI = {}
XfinUI.__index = XfinUI

local SETTINGS_FOLDER = "XFIN"
local SETTINGS_FILE = "XFIN/settings.json"
local TAB_LABELS = { "S1", "S2", "S3" }
local TAB_FILES = { "Main.lua", "Script2.lua", "Script3.lua" }
local OUTPUT_OPEN_HEIGHT = 104
local OUTPUT_CLOSED_HEIGHT = 24
local MAX_OUTPUT_LINES = 150
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

local DEFAULTS = {
    width = 380, height = 500, textSize = 13,
    accent = "3FA876", bg = "16181E", editor = "111318",
    animations = true, highlight = true, lineNumbers = true, autoIndent = true,
    outputOpen = true,
}

-- { name, accent, window bg, editor bg }
local PRESETS = {
    { "Midnight", "3FA876", "16181E", "111318" },
    { "Ocean", "3D8BFD", "111A26", "0C131B" },
    { "Violet", "8B6CFF", "1A1626", "120F1C" },
    { "Amber", "E0A030", "1E1A14", "15120D" },
    { "Rose", "E0587A", "21151A", "170E12" },
    { "Mono", "B0B6C4", "1B1B1D", "121213" },
}

local PAL_DARK = { keyword = "C792EA", string = "A5D6A7", number = "F78C6C", comment = "6B7385", builtin = "82AAFF", func = "FFCB6B" }
local PAL_LIGHT = { keyword = "8A2BB5", string = "2E7D32", number = "C2410C", comment = "8A8F9C", builtin = "1D4ED8", func = "9A6700" }

local LOG_COLORS = { info = "97B7DC", success = "77DC9E", warn = "EEC26F", error = "F27B7B" }
local STATUS_COLORS = {
    info = Color3.fromRGB(151, 183, 220), success = Color3.fromRGB(119, 220, 158),
    warn = Color3.fromRGB(238, 194, 111), error = Color3.fromRGB(242, 123, 123),
}

local KEYWORDS, BUILTINS = {}, {}
for _, w in ipairs({ "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while", "continue" }) do KEYWORDS[w] = true end
for _, w in ipairs({ "game", "workspace", "script", "print", "warn", "error", "pairs", "ipairs", "require", "pcall", "xpcall", "task", "wait", "spawn", "delay", "tick", "os", "Instance", "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "TweenInfo", "Enum", "string", "table", "math", "tostring", "tonumber", "type", "typeof", "next", "select", "setmetatable", "getmetatable", "loadstring" }) do BUILTINS[w] = true end

-- ---------------------------------------------------------------- helpers

local function hexToColor(hex)
    local h = tostring(hex or ""):gsub("#", "")
    if not h:match("^%x%x%x%x%x%x$") then return nil end
    return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16))
end

local function colorToHex(c)
    return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function escapeRich(s)
    return (tostring(s):gsub("[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }))
end

local function hasFS()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function loadSettings()
    local s = {}
    for k, v in pairs(DEFAULTS) do s[k] = v end
    if hasFS() then
        local ok, data = pcall(function()
            if isfile(SETTINGS_FILE) then return HttpService:JSONDecode(readfile(SETTINGS_FILE)) end
        end)
        if ok and type(data) == "table" then
            for k, v in pairs(data) do
                if DEFAULTS[k] ~= nil and type(v) == type(DEFAULTS[k]) then s[k] = v end
            end
        end
    end
    return s
end

local function saveSettings(s)
    if not hasFS() then return false end
    local ok = pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(SETTINGS_FOLDER) then
            makefolder(SETTINGS_FOLDER)
        end
        writefile(SETTINGS_FILE, HttpService:JSONEncode(s))
    end)
    return ok
end

-- Luau syntax highlighter -> RichText string
local function highlight(source, pal)
    local out, n = {}, 0
    local function push(text, color)
        n += 1
        if color then
            out[n] = '<font color="#' .. color .. '">' .. escapeRich(text) .. "</font>"
        else
            out[n] = escapeRich(text)
        end
    end
    local i, len = 1, #source
    while i <= len do
        local c = source:sub(i, i)
        if source:sub(i, i + 1) == "--" then
            local long = source:match("^%-%-%[(=*)%[", i)
            local e
            if long then
                local _, f = source:find("]" .. long .. "]", i, true)
                e = f or len
            else
                e = (source:find("\n", i, true) or (len + 1)) - 1
            end
            push(source:sub(i, e), pal.comment)
            i = e + 1
        elseif c == '"' or c == "'" then
            local e, j = len, i + 1
            while j <= len do
                local cj = source:sub(j, j)
                if cj == "\\" then
                    j += 2
                elseif cj == c then
                    e = j
                    break
                elseif cj == "\n" then
                    e = j - 1
                    break
                else
                    j += 1
                end
            end
            push(source:sub(i, e), pal.string)
            i = e + 1
        elseif c == "[" and source:match("^%[=*%[", i) then
            local eq = source:match("^%[(=*)%[", i)
            local _, f = source:find("]" .. eq .. "]", i, true)
            local e = f or len
            push(source:sub(i, e), pal.string)
            i = e + 1
        elseif c:match("%d") then
            local s, e = source:find("^0[xX]%x+", i)
            if not s then s, e = source:find("^%d+%.?%d*[eE][%+%-]?%d+", i) end
            if not s then s, e = source:find("^%d+%.?%d*", i) end
            push(source:sub(s, e), pal.number)
            i = e + 1
        elseif c:match("[%a_]") then
            local s, e = source:find("^[%a_][%w_]*", i)
            local word = source:sub(s, e)
            local prev = source:sub(i - 1, i - 1)
            local color
            if KEYWORDS[word] and prev ~= "." and prev ~= ":" then
                color = pal.keyword
            elseif BUILTINS[word] and prev ~= "." then
                color = pal.builtin
            elseif source:sub(e + 1, e + 1) == "(" then
                color = pal.func
            end
            push(word, color)
            i = e + 1
        else
            local s, e = source:find("^[^%w_\"'%[%-]+", i)
            if s then
                push(source:sub(s, e))
                i = e + 1
            else
                push(c)
                i += 1
            end
        end
    end
    return table.concat(out)
end

local function opensBlock(line)
    line = line:gsub("%-%-.*$", ""):gsub("%s+$", "")
    return line:match("%f[%w_]then$") or line:match("%f[%w_]do$") or line:match("%f[%w_]else$")
        or line:match("%f[%w_]repeat$") or line:match("{$") or line:match("%f[%w_]function%s*[%w_%.:]*%s*%b()$")
end

-- ---------------------------------------------------------------- UI

function XfinUI.new(playerGui)
    assert(playerGui, "XfinUI.new requires a PlayerGui")
    local self = setmetatable({}, XfinUI)
    self.Callbacks = {}
    self.Settings = loadSettings()
    self.IsOpen = false
    self._explorerExpanded = {}
    self._explorerSelected = nil
    self._explorerRows = {}
    self._scriptNames = {}
    self._conns = {}
    self._logRows = {}
    self._logOrder = 0

    local function connect(signal, fn)
        local c = signal:Connect(fn)
        table.insert(self._conns, c)
        return c
    end

    local old = playerGui:FindFirstChild("XFINScriptEditor")
    if old then old:Destroy() end

    -- ------------------------------------------------ theme
    local theme = {}
    local themed = {}
    local hooks = {}

    local function computeTheme()
        local s = self.Settings
        local accent = hexToColor(s.accent) or hexToColor(DEFAULTS.accent)
        local bg = hexToColor(s.bg) or hexToColor(DEFAULTS.bg)
        local editorBg = hexToColor(s.editor) or hexToColor(DEFAULTS.editor)
        local lum = 0.299 * bg.R + 0.587 * bg.G + 0.114 * bg.B
        local light = lum > 0.6
        local fg = light and Color3.fromRGB(26, 28, 34) or Color3.fromRGB(236, 239, 246)
        local lift = light and BLACK or WHITE
        theme.light = light
        theme.bg, theme.editor = bg, editorBg
        theme.header = bg:Lerp(lift, 0.04)
        theme.panel = bg:Lerp(lift, 0.07)
        theme.btn = bg:Lerp(lift, 0.14)
        theme.raised = bg:Lerp(lift, 0.22)
        theme.stroke = bg:Lerp(lift, 0.26)
        theme.text = fg
        theme.muted = fg:Lerp(bg, 0.42)
        theme.accent = accent
        theme.accentBtn = accent:Lerp(bg, 0.42)
        theme.selected = accent:Lerp(bg, 0.6)
        theme.danger = Color3.fromRGB(122, 50, 58)
    end
    computeTheme()

    local function tween(obj, props, duration, style, direction)
        if not self.Settings.animations then
            for k, v in pairs(props) do pcall(function() obj[k] = v end) end
            return nil
        end
        local t = TweenService:Create(obj, TweenInfo.new(duration or 0.18, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
        t:Play()
        return t
    end

    -- Property values like "@panel" are theme roles and re-colored on theme changes.
    local function make(className, props, parent)
        local obj = Instance.new(className)
        for key, value in pairs(props or {}) do
            if type(value) == "string" and value:sub(1, 1) == "@" and key:match("Color3?$") then
                local r = value:sub(2)
                table.insert(themed, { obj, key, r })
                value = theme[r]
            end
            pcall(function() obj[key] = value end)
        end
        obj.Parent = parent
        return obj
    end

    local function corner(parent, radius)
        return make("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
    end

    local function stroke(parent, thickness)
        return make("UIStroke", { Color = "@stroke", Thickness = thickness or 1 }, parent)
    end

    local function baseOf(kind)
        if typeof(kind) == "Color3" then return kind end
        if type(kind) == "function" then return kind() end
        return theme[kind or "btn"]
    end

    local function textButton(parent, text, size, position, kind)
        local bgValue
        if type(kind) == "string" or kind == nil then bgValue = "@" .. (kind or "btn") else bgValue = baseOf(kind) end
        local button = make("TextButton", {
            Name = (text:gsub("%W", "")) .. "Button",
            Size = size, Position = position,
            BackgroundColor3 = bgValue, BorderSizePixel = 0,
            Text = text, TextColor3 = "@text", TextSize = 13,
            Font = Enum.Font.GothamMedium, AutoButtonColor = false,
        }, parent)
        corner(button, 5)
        local hovering = false
        button.MouseEnter:Connect(function()
            hovering = true
            tween(button, { BackgroundColor3 = baseOf(kind):Lerp(WHITE, 0.14) }, 0.12)
        end)
        button.MouseLeave:Connect(function()
            hovering = false
            tween(button, { BackgroundColor3 = baseOf(kind) }, 0.15)
        end)
        button.MouseButton1Down:Connect(function()
            tween(button, { BackgroundColor3 = baseOf(kind):Lerp(BLACK, 0.2) }, 0.06)
        end)
        button.MouseButton1Up:Connect(function()
            tween(button, { BackgroundColor3 = hovering and baseOf(kind):Lerp(WHITE, 0.14) or baseOf(kind) }, 0.1)
        end)
        return button
    end

    local function textLabel(parent, text, size, position, textSize, colorRole)
        return make("TextLabel", {
            Size = size, Position = position, BackgroundTransparency = 1, Text = text,
            TextColor3 = "@" .. (colorRole or "text"), TextSize = textSize or 12, Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, parent)
    end

    local function clearChildren(frame, keepLayout)
        for _, child in ipairs(frame:GetChildren()) do
            if not (keepLayout and child:IsA("UIListLayout")) then child:Destroy() end
        end
    end

    local function viewport()
        local cam = Workspace.CurrentCamera
        return cam and cam.ViewportSize or Vector2.new(800, 600)
    end

    local function clampSize(w, h)
        local v = viewport()
        return math.clamp(w, 300, math.max(300, math.min(1000, v.X - 12))),
            math.clamp(h, 340, math.max(340, math.min(760, v.Y - 12)))
    end

    -- forward declarations
    local applyTheme, applyEditorStyle, refreshVisuals, applyAll, scheduleSave, setStatus

    -- ------------------------------------------------ screen gui + window
    local gui = make("ScreenGui", {
        Name = "XFINScriptEditor", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100,
    }, playerGui)
    self.Gui = gui
    gui.Destroying:Connect(function()
        for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    end)

    local startW, startH = clampSize(self.Settings.width, self.Settings.height)
    local root = make("CanvasGroup", {
        Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(startW, startH), BackgroundColor3 = "@bg", BorderSizePixel = 0,
        GroupTransparency = 1, Visible = false,
    }, gui)
    corner(root, 10)
    stroke(root)
    self.Root = root
    local scale = make("UIScale", { Scale = 1 }, root)

    local HEADER_H, TOOLBAR_Y, BODY_TOP, FOOTER_H = 38, 44, 84, 24

    local header = make("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundColor3 = "@header", BorderSizePixel = 0 }, root)
    self.Header = header
    textLabel(header, "XFIN  /  SCRIPT EDITOR", UDim2.new(1, -120, 1, 0), UDim2.new(0, 12, 0, 0), 13).Font = Enum.Font.GothamBold
    local settingsButton = textButton(header, "⚙", UDim2.fromOffset(32, 28), UDim2.new(1, -76, 0, 5), "btn")
    settingsButton.TextSize = 16
    local closeButton = textButton(header, "×", UDim2.fromOffset(32, 28), UDim2.new(1, -38, 0, 5), "danger")
    closeButton.TextSize = 20

    -- toolbar (scrolls) + fixed Run button
    local toolbar = make("ScrollingFrame", {
        Name = "Toolbar", Position = UDim2.new(0, 8, 0, TOOLBAR_Y), Size = UDim2.new(1, -90, 0, 34),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
        ScrollingDirection = Enum.ScrollingDirection.X, CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
    }, root)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
    }, toolbar)
    self.Toolbar = toolbar
    local function tool(text, width, order, kind)
        local b = textButton(toolbar, text, UDim2.fromOffset(width, 29), UDim2.new(), kind)
        b.LayoutOrder = order
        return b
    end
    local newButton = tool("New", 48, 1)
    local saveButton = tool("Save", 50, 2)
    local clearButton = tool("Clear", 48, 3)
    local filesButton = tool("Files", 48, 4)
    local indentButton = tool("⇥ Tab", 56, 5)
    local reviewButton = tool("Review", 56, 6)
    local explorerButton = tool("Explorer", 66, 7)

    local runButton = textButton(root, "▶ Run", UDim2.fromOffset(66, 30), UDim2.new(1, -74, 0, TOOLBAR_Y + 2), "accentBtn")
    runButton.Font = Enum.Font.GothamBold
    self.RunButton = runButton

    local body = make("Frame", {
        Name = "Body", Position = UDim2.new(0, 8, 0, BODY_TOP),
        Size = UDim2.new(1, -16, 1, -(BODY_TOP + FOOTER_H + 8)), BackgroundTransparency = 1, BorderSizePixel = 0,
    }, root)
    self.Body = body

    local footer = textLabel(root, "Ready", UDim2.new(1, -16, 0, FOOTER_H), UDim2.new(0, 8, 1, -(FOOTER_H + 3)), 11, "muted")
    footer.Name = "Status"
    self.StatusLabel = footer

    -- ------------------------------------------------ editor panel (tabs, code, output)
    local editorPanel = make("Frame", {
        Name = "EditorPanel", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = "@editor", BorderSizePixel = 0,
    }, body)
    corner(editorPanel, 6)
    self.EditorPanel = editorPanel

    local tabBar = make("Frame", { Name = "TabBar", Position = UDim2.new(0, 4, 0, 4), Size = UDim2.new(1, -8, 0, 26), BackgroundTransparency = 1 }, editorPanel)
    make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, tabBar)

    local tabs, tabButtons, activeTab = {}, {}, 1
    for i = 1, #TAB_LABELS do tabs[i] = { label = TAB_LABELS[i], file = TAB_FILES[i], text = "" } end
    local function updateTabButtons()
        for i, b in ipairs(tabButtons) do
            b.BackgroundColor3 = (i == activeTab) and theme.accentBtn or theme.btn
            b.Font = (i == activeTab) and Enum.Font.GothamBold or Enum.Font.GothamMedium
        end
    end
    table.insert(hooks, updateTabButtons)

    local codeArea = make("Frame", { Name = "CodeArea", Position = UDim2.new(0, 0, 0, 34), BackgroundTransparency = 1, ClipsDescendants = true }, editorPanel)
    local codeScroll = make("ScrollingFrame", {
        Name = "CodeScroll", Position = UDim2.new(0, 4, 0, 0), Size = UDim2.new(1, -8, 1, 0),
        BackgroundColor3 = "@editor", BorderSizePixel = 0, ScrollBarThickness = 4,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.XY,
        ScrollingDirection = Enum.ScrollingDirection.XY,
    }, codeArea)

    local gutter = make("TextLabel", {
        Name = "LineNumbers", Position = UDim2.fromOffset(4, 6), Size = UDim2.fromOffset(38, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = "1",
        TextColor3 = "@muted", TextSize = 13, Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Top,
    }, codeScroll)
    local highlightLabel = make("TextLabel", {
        Name = "Highlight", Position = UDim2.fromOffset(46, 6), Size = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1, RichText = true, Text = "",
        TextColor3 = "@text", TextSize = 13, Font = Enum.Font.Code, TextWrapped = false,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 1,
    }, codeScroll)
    local editor = make("TextBox", {
        Name = "CodeEditor", Position = UDim2.fromOffset(46, 6), Size = UDim2.fromOffset(100, 40),
        AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1, BorderSizePixel = 0,
        Text = "", PlaceholderText = "-- Write Luau here...", ClearTextOnFocus = false,
        MultiLine = true, TextWrapped = false, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = "@text", PlaceholderColor3 = "@muted",
        TextSize = 13, Font = Enum.Font.Code, ZIndex = 2,
    }, codeScroll)
    self.Editor = editor
    local codeX = 46

    -- output console
    local outputPanel = make("Frame", { Name = "Output", BackgroundColor3 = "@bg", BorderSizePixel = 0, ClipsDescendants = true }, editorPanel)
    corner(outputPanel, 6)
    stroke(outputPanel)
    textLabel(outputPanel, "OUTPUT", UDim2.new(1, -120, 0, 22), UDim2.new(0, 8, 0, 0), 10, "muted").Font = Enum.Font.GothamBold
    local outClear = textButton(outputPanel, "Clear", UDim2.fromOffset(46, 18), UDim2.new(1, -86, 0, 2), "btn")
    outClear.TextSize = 10
    local outToggle = textButton(outputPanel, "▾", UDim2.fromOffset(28, 18), UDim2.new(1, -34, 0, 2), "btn")
    outToggle.TextSize = 11
    local outScroll = make("ScrollingFrame", {
        Name = "OutputList", Position = UDim2.new(0, 4, 0, 22), Size = UDim2.new(1, -8, 1, -26),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, outputPanel)
    make("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, outScroll)

    local function layoutEditor(instant)
        local h = self.Settings.outputOpen and OUTPUT_OPEN_HEIGHT or OUTPUT_CLOSED_HEIGHT
        local outSize, outPos = UDim2.new(1, -8, 0, h), UDim2.new(0, 4, 1, -(h + 4))
        local areaSize = UDim2.new(1, 0, 1, -(34 + h + 8))
        if instant then
            outputPanel.Size, outputPanel.Position, codeArea.Size = outSize, outPos, areaSize
        else
            tween(outputPanel, { Size = outSize, Position = outPos }, 0.2)
            tween(codeArea, { Size = areaSize }, 0.2)
        end
        outToggle.Text = self.Settings.outputOpen and "▾" or "▴"
    end

    -- ------------------------------------------------ sidebar (saved scripts + templates) overlay
    local sidebar = make("CanvasGroup", {
        Name = "Sidebar", Visible = false, Size = UDim2.new(0, 150, 1, 0),
        BackgroundColor3 = "@panel", BorderSizePixel = 0, ZIndex = 8, GroupTransparency = 1,
    }, body)
    corner(sidebar, 6)
    stroke(sidebar)
    self.Sidebar = sidebar

    local fileName = make("TextBox", {
        Name = "FileName", Position = UDim2.new(0, 6, 0, 6), Size = UDim2.new(1, -12, 0, 29),
        BackgroundColor3 = "@editor", BorderSizePixel = 0, Text = TAB_FILES[1], PlaceholderText = "File name",
        ClearTextOnFocus = false, TextColor3 = "@text", PlaceholderColor3 = "@muted",
        TextSize = 12, Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Left,
    }, sidebar)
    corner(fileName, 5)
    self.FileName = fileName

    textLabel(sidebar, "YOUR SCRIPTS", UDim2.new(1, -12, 0, 20), UDim2.new(0, 6, 0, 40), 10, "muted").Font = Enum.Font.GothamBold
    local fileList = make("ScrollingFrame", {
        Name = "ScriptList", Position = UDim2.new(0, 5, 0, 62), Size = UDim2.new(1, -10, 0.42, -62),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, sidebar)
    make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, fileList)
    self.FileList = fileList

    local deleteButton = textButton(sidebar, "Delete current", UDim2.new(1, -10, 0, 25), UDim2.new(0, 5, 0.47, -2), "danger")
    deleteButton.TextSize = 11
    textLabel(sidebar, "TEMPLATES", UDim2.new(1, -12, 0, 20), UDim2.new(0, 6, 0.47, 25), 10, "muted").Font = Enum.Font.GothamBold
    local templateList = make("ScrollingFrame", {
        Name = "TemplateList", Position = UDim2.new(0, 5, 0.47, 47), Size = UDim2.new(1, -10, 0.53, -52),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, sidebar)
    make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, templateList)
    self.TemplateList = templateList

    -- ------------------------------------------------ explorer overlay
    local explorer = make("CanvasGroup", {
        Name = "ExplorerPanel", Visible = false, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.82, 0, 1, 0),
        BackgroundColor3 = "@panel", BorderSizePixel = 0, ZIndex = 10, GroupTransparency = 1,
    }, body)
    corner(explorer, 7)
    stroke(explorer)
    self.ExplorerPanel = explorer
    textLabel(explorer, "INSTANCE EXPLORER", UDim2.new(1, -82, 0, 30), UDim2.new(0, 8, 0, 0), 11).Font = Enum.Font.GothamBold
    local refreshExplorer = textButton(explorer, "↻", UDim2.fromOffset(27, 24), UDim2.new(1, -62, 0, 3), "btn")
    local closeExplorer = textButton(explorer, "×", UDim2.fromOffset(27, 24), UDim2.new(1, -31, 0, 3), "danger")
    local tree = make("ScrollingFrame", {
        Name = "Tree", Position = UDim2.new(0, 5, 0, 32), Size = UDim2.new(0.53, -6, 1, -38),
        BackgroundColor3 = "@editor", BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, explorer)
    corner(tree, 5)
    make("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, tree)
    self.ExplorerTree = tree
    local details = make("ScrollingFrame", {
        Name = "Details", Position = UDim2.new(0.53, 2, 0, 32), Size = UDim2.new(0.47, -7, 1, -38),
        BackgroundColor3 = "@editor", BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, explorer)
    corner(details, 5)
    make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, details)
    self.ExplorerDetails = details

    -- ------------------------------------------------ settings panel
    local settingsPanel = make("CanvasGroup", {
        Name = "SettingsPanel", Visible = false, Position = UDim2.new(0, 8, 0, TOOLBAR_Y),
        Size = UDim2.new(1, -16, 1, -(TOOLBAR_Y + FOOTER_H + 6)), BackgroundColor3 = "@panel",
        BorderSizePixel = 0, ZIndex = 30, GroupTransparency = 1,
    }, root)
    corner(settingsPanel, 8)
    stroke(settingsPanel)
    textLabel(settingsPanel, "SETTINGS", UDim2.new(1, -50, 0, 30), UDim2.new(0, 10, 0, 0), 12).Font = Enum.Font.GothamBold
    local closeSettings = textButton(settingsPanel, "×", UDim2.fromOffset(28, 24), UDim2.new(1, -34, 0, 4), "danger")
    local settingsScroll = make("ScrollingFrame", {
        Position = UDim2.new(0, 6, 0, 34), Size = UDim2.new(1, -12, 1, -40), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, settingsPanel)
    make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, settingsScroll)

    -- ------------------------------------------------ launcher (reopen button)
    local launcher = make("TextButton", {
        Name = "Launcher", Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 10, 0.5, -22),
        BackgroundColor3 = "@accentBtn", BorderSizePixel = 0, Text = "X", TextColor3 = "@text",
        TextSize = 20, Font = Enum.Font.GothamBlack, AutoButtonColor = false, ZIndex = 50,
    }, gui)
    corner(launcher, 22)
    stroke(launcher, 2).Color = theme.accent
    self.Launcher = launcher

    -- ------------------------------------------------ core plumbing
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

    setStatus = function(message, kind)
        message = tostring(message)
        footer.Text = message:match("^[^\n]*") or message
        footer.TextColor3 = STATUS_COLORS[kind or "info"] or theme.muted
    end

    function self:Log(message, kind)
        kind = kind or "print"
        self._logOrder += 1
        local color = LOG_COLORS[kind]
        local text = '<font color="#7D8599">' .. os.date("%H:%M:%S") .. "</font>  "
            .. (color and ('<font color="#' .. color .. '">') or "") .. escapeRich(message) .. (color and "</font>" or "")
        local row = make("TextLabel", {
            Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
            RichText = true, Text = text, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Code, TextSize = 11,
            TextColor3 = "@text", LayoutOrder = self._logOrder,
        }, outScroll)
        table.insert(self._logRows, row)
        if #self._logRows > MAX_OUTPUT_LINES then
            table.remove(self._logRows, 1):Destroy()
        end
        task.defer(function()
            outScroll.CanvasPosition = Vector2.new(0, outScroll.AbsoluteCanvasSize.Y)
        end)
    end
    function self:ClearLog()
        for _, r in ipairs(self._logRows) do r:Destroy() end
        self._logRows = {}
    end

    function self:Info(message) setStatus(message, "info"); self:Log(message, "info") end
    function self:Success(message) setStatus(message, "success"); self:Log(message, "success") end
    function self:Warn(message) setStatus(message, "warn"); self:Log(message, "warn") end
    function self:Error(message) setStatus(message, "error"); self:Log(message, "error") end
    function self:SetRunning(running) runButton.Text = running and "…" or "▶ Run" end
    function self:SetSaveStatus(state)
        -- The backend passes true (saved) / false (unsaved edits); text is accepted too.
        if state == true then
            setStatus("Saved", "success")
        elseif state == false then
            setStatus("Unsaved changes", "warn")
        else
            setStatus(state or "Saved", "info")
        end
    end
    function self:SetSupportedOperations(items) self.SupportedOperations = items or {} end

    function self:SetFileName(name) fileName.Text = tostring(name or "Main.lua") end
    function self:SetSource(source) editor.Text = tostring(source or "") end
    function self:GetSource() return editor.Text end
    function self:GetFileName() return fileName.Text end
    function self:GetTabs() return tabs end

    -- panels (fade + slide)
    local bases, panelState, panelToken = {}, {}, {}
    local function registerPanel(panel) bases[panel] = panel.Position; panelState[panel] = false end
    registerPanel(sidebar); registerPanel(explorer); registerPanel(settingsPanel)
    local function setPanel(panel, show)
        panelState[panel] = show
        panelToken[panel] = (panelToken[panel] or 0) + 1
        local my = panelToken[panel]
        local base = bases[panel]
        local offset = UDim2.fromOffset(0, 12)
        if show then
            panel.Visible = true
            if self.Settings.animations then
                panel.GroupTransparency = 1
                panel.Position = base + offset
            end
            tween(panel, { GroupTransparency = 0, Position = base }, 0.2)
        else
            local t = tween(panel, { GroupTransparency = 1, Position = base + offset }, 0.15)
            local function finish()
                if panelToken[panel] == my then panel.Visible = false; panel.Position = base end
            end
            if t then t.Completed:Connect(finish) else finish() end
        end
    end
    local function togglePanel(panel)
        local want = not panelState[panel]
        if want then
            for p in pairs(panelState) do
                if p ~= panel and panelState[p] then setPanel(p, false) end
            end
        end
        setPanel(panel, want)
    end

    -- open / close / toggle (the window is hidden, never destroyed, so it can always be reopened)
    local openToken = 0
    function self:Open()
        if self.IsOpen then return end
        self.IsOpen = true
        openToken += 1
        root.Visible = true
        if self.Settings.animations then
            root.GroupTransparency = 1
            scale.Scale = 0.94
        end
        tween(root, { GroupTransparency = 0 }, 0.2)
        tween(scale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
        tween(launcher, { BackgroundTransparency = 0.5 }, 0.2)
    end
    function self:Close()
        if not self.IsOpen then return end
        self.IsOpen = false
        openToken += 1
        local my = openToken
        local function finish()
            if openToken == my and not self.IsOpen then root.Visible = false end
        end
        tween(root, { GroupTransparency = 1 }, 0.16)
        local t = tween(scale, { Scale = 0.94 }, 0.16)
        if t then t.Completed:Connect(finish) else finish() end
        tween(launcher, { BackgroundTransparency = 0 }, 0.2)
    end
    function self:Toggle() if self.IsOpen then self:Close() else self:Open() end end
    function self:Destroy() gui:Destroy() end

    -- dragging helper (title bar moves the window; the launcher moves itself, tap toggles)
    local function makeDraggable(handle, target, onTap)
        local dragging, moved, startPos, startUI = false, false, nil, nil
        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging, moved = true, false
                startPos, startUI = input.Position, target.Position
                local c
                c = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        c:Disconnect()
                        if onTap and not moved then onTap() end
                    end
                end)
            end
        end)
        connect(UserInputService.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - startPos
                if d.Magnitude > 5 then moved = true end
                if moved then
                    target.Position = UDim2.new(startUI.X.Scale, startUI.X.Offset + d.X, startUI.Y.Scale, startUI.Y.Offset + d.Y)
                end
            end
        end)
    end
    makeDraggable(header, root)
    makeDraggable(launcher, launcher, function() self:Toggle() end)

    connect(UserInputService.InputBegan, function(input, processed)
        if processed or UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode == Enum.KeyCode.RightShift then self:Toggle() end
    end)

    -- ------------------------------------------------ script lists
    function self:SetScriptList(items, current)
        self._lastScripts, self._lastCurrent = items, current
        clearChildren(fileList, true)
        self._scriptNames = {}
        for index, item in ipairs(items or {}) do
            local name = type(item) == "table" and item.Name or tostring(item)
            self._scriptNames[name] = true
            local row = textButton(fileList, name, UDim2.new(1, 0, 0, 25), UDim2.new(), name == current and theme.selected or theme.btn)
            row.LayoutOrder = index
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.TextSize = 11
            row.MouseButton1Click:Connect(function() invoke("OpenScript", name) end)
        end
    end

    function self:SetTemplates(items)
        self._lastTemplates = items
        clearChildren(templateList, true)
        for index, item in ipairs(items or {}) do
            local id = type(item) == "table" and (item.Id or item.ID or item.Name) or tostring(item)
            local title = type(item) == "table" and (item.Name or item.Title or id) or tostring(item)
            local row = textButton(templateList, "+ " .. tostring(title), UDim2.new(1, 0, 0, 25), UDim2.new(), "btn")
            row.LayoutOrder = index
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.TextSize = 11
            row.MouseButton1Click:Connect(function() invoke("RequestTemplate", id) end)
        end
    end

    -- ------------------------------------------------ explorer
    local refreshExplorerTree
    refreshExplorerTree = function()
        clearChildren(tree, true)
        self._explorerRows = {}
        local roots = {}
        local ok, children = pcall(function() return game:GetChildren() end)
        if ok and type(children) == "table" then
            for _, child in ipairs(children) do table.insert(roots, child) end
        end
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
            if depth > 5 then return order end
            local childrenOfObj = {}
            local childrenOk, found = pcall(function() return obj:GetChildren() end)
            if childrenOk then childrenOfObj = found end
            local expanded = self._explorerExpanded[obj] == true
            local prefix = string.rep("  ", depth) .. (#childrenOfObj > 0 and (expanded and "▾ " or "▸ ") or "  ")
            local label = prefix .. obj.Name .. "  [" .. obj.ClassName .. "]"
            local row = textButton(tree, label, UDim2.new(1, -4, 0, 23), UDim2.new(), self._explorerSelected == obj and theme.selected or theme.panel)
            row.LayoutOrder = order
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.TextSize = 10
            self._explorerRows[obj] = row
            row.MouseButton1Click:Connect(function()
                self._explorerSelected = obj
                if #childrenOfObj > 0 then self._explorerExpanded[obj] = not expanded end
                self:ShowInstanceDetails(obj)
                refreshExplorerTree()
            end)
            order += 1
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
                Name = "Property", Size = UDim2.new(1, -8, 0, 31), BackgroundColor3 = "@panel",
                BorderSizePixel = 0, Text = label .. "\n" .. tostring(value), TextColor3 = "@text",
                TextSize = 10, Font = Enum.Font.Code, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center, LayoutOrder = order,
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
                order += 1
            end
        end
    end

    -- ------------------------------------------------ code editor behavior
    local lastText, applying, suppress = "", false, false
    local lastLineCount, lastCursor = -1, nil

    local function updateMinSize()
        local a = codeScroll.AbsoluteSize
        editor.Size = UDim2.fromOffset(math.max(60, a.X - codeX - 8), math.max(40, a.Y - 14))
    end
    connect(codeScroll:GetPropertyChangedSignal("AbsoluteSize"), updateMinSize)

    refreshVisuals = function()
        local s = self.Settings
        local text = editor.Text
        if s.lineNumbers then
            local count = 1
            for _ in text:gmatch("\n") do count += 1 end
            if count ~= lastLineCount then
                local parts = {}
                for i = 1, count do parts[i] = tostring(i) end
                gutter.Text = table.concat(parts, "\n")
                lastLineCount = count
            end
        end
        if s.highlight and #text <= 30000 then
            highlightLabel.Visible = true
            editor.TextTransparency = 1
            highlightLabel.Text = highlight(text, theme.light and PAL_LIGHT or PAL_DARK)
        else
            highlightLabel.Visible = false
            editor.TextTransparency = 0
        end
    end

    applyEditorStyle = function()
        local s = self.Settings
        for _, o in ipairs({ editor, highlightLabel, gutter }) do o.TextSize = s.textSize end
        gutter.Visible = s.lineNumbers
        codeX = s.lineNumbers and 46 or 8
        editor.Position = UDim2.fromOffset(codeX, 6)
        highlightLabel.Position = UDim2.fromOffset(codeX, 6)
        lastLineCount = -1
        updateMinSize()
        refreshVisuals()
    end

    connect(editor:GetPropertyChangedSignal("CursorPosition"), function()
        if editor.CursorPosition ~= -1 then lastCursor = editor.CursorPosition end
    end)

    connect(editor:GetPropertyChangedSignal("Text"), function()
        if applying then return end
        local text = editor.Text
        -- auto-indent after Enter
        if self.Settings.autoIndent and #text == #lastText + 1 then
            local cur = editor.CursorPosition
            if cur and cur > 1 and text:sub(cur - 1, cur - 1) == "\n" then
                local before = text:sub(1, cur - 2)
                local prevLine = before:match("([^\n]*)$") or ""
                local add = prevLine:match("^[ ]*") or ""
                if opensBlock(prevLine) then add = add .. "    " end
                if add ~= "" then
                    applying = true
                    editor.Text = text:sub(1, cur - 1) .. add .. text:sub(cur)
                    editor.CursorPosition = cur + #add
                    applying = false
                    text = editor.Text
                end
            end
        end
        lastText = text
        tabs[activeTab].text = text
        refreshVisuals()
        if not suppress then invoke("SourceChanged", text) end
    end)

    connect(fileName:GetPropertyChangedSignal("Text"), function() tabs[activeTab].file = fileName.Text end)

    -- tabs
    local function switchTab(i)
        if i == activeTab or not tabs[i] then return end
        tabs[activeTab].text = editor.Text
        tabs[activeTab].file = fileName.Text
        activeTab = i
        suppress = true
        editor.Text = tabs[i].text
        fileName.Text = tabs[i].file
        suppress = false
        updateTabButtons()
        self:Info("Switched to " .. tabs[i].label .. " (" .. tabs[i].file .. ")")
    end
    for i, t in ipairs(tabs) do
        local b = textButton(tabBar, t.label, UDim2.fromOffset(54, 24), UDim2.new(), function()
            return i == activeTab and theme.accentBtn or theme.btn
        end)
        b.LayoutOrder = i
        tabButtons[i] = b
        b.MouseButton1Click:Connect(function() switchTab(i) end)
    end
    function self:SetTab(i) switchTab(i) end
    updateTabButtons()

    -- ------------------------------------------------ settings widgets
    do
        local order = 0
        local function ord() order += 1; return order end
        local function section(text)
            local l = textLabel(settingsScroll, text, UDim2.new(1, -6, 0, 20), UDim2.new(), 10, "accent")
            l.Font = Enum.Font.GothamBold
            l.LayoutOrder = ord()
        end

        local sliderActive = false
        local function slider(titleText, min, max, key, suffix, onChange)
            local row = make("Frame", { Size = UDim2.new(1, -6, 0, 48), BackgroundTransparency = 1, LayoutOrder = ord() }, settingsScroll)
            local label = textLabel(row, "", UDim2.new(1, 0, 0, 18), UDim2.new(), 11, "muted")
            local track = make("Frame", { Position = UDim2.new(0, 8, 0, 32), Size = UDim2.new(1, -16, 0, 6), BackgroundColor3 = "@raised", BorderSizePixel = 0 }, row)
            corner(track, 3)
            local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = "@accent", BorderSizePixel = 0 }, track)
            corner(fill, 3)
            local knob = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 18), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = "@accent", BorderSizePixel = 0 }, track)
            corner(knob, 9)
            local hit = make("TextButton", { Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, row)
            local function show(v)
                local alpha = math.clamp((v - min) / (max - min), 0, 1)
                fill.Size = UDim2.fromScale(alpha, 1)
                knob.Position = UDim2.fromScale(alpha, 0.5)
                label.Text = titleText .. ":  " .. tostring(v) .. suffix
            end
            local function fromInput(x)
                local w = track.AbsoluteSize.X
                local alpha = w > 0 and math.clamp((x - track.AbsolutePosition.X) / w, 0, 1) or 0
                local v = math.floor(min + alpha * (max - min) + 0.5)
                if v ~= self.Settings[key] then
                    self.Settings[key] = v
                    show(v)
                    onChange(v)
                end
            end
            local dragging = false
            hit.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    settingsScroll.ScrollingEnabled = false
                    fromInput(input.Position.X)
                end
            end)
            connect(UserInputService.InputChanged, function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    fromInput(input.Position.X)
                end
            end)
            connect(UserInputService.InputEnded, function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                    dragging = false
                    settingsScroll.ScrollingEnabled = true
                    scheduleSave()
                end
            end)
            table.insert(hooks, function() show(self.Settings[key]) end)
        end

        local v = viewport()
        section("WINDOW")
        slider("Width", 300, math.max(320, math.min(1000, math.floor(v.X) - 12)), "width", " px", function(val)
            local w, h = clampSize(val, self.Settings.height)
            root.Size = UDim2.fromOffset(w, h)
        end)
        slider("Height", 340, math.max(360, math.min(760, math.floor(v.Y) - 12)), "height", " px", function(val)
            local w, h = clampSize(self.Settings.width, val)
            root.Size = UDim2.fromOffset(w, h)
        end)
        slider("Text size", 10, 20, "textSize", " px", function() applyEditorStyle() end)

        section("THEME")
        local presetFrame = make("Frame", { Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = ord() }, settingsScroll)
        make("UIGridLayout", { CellSize = UDim2.new(0.333, -4, 0, 28), CellPadding = UDim2.fromOffset(5, 5), SortOrder = Enum.SortOrder.LayoutOrder }, presetFrame)
        for i, p in ipairs(PRESETS) do
            local color = hexToColor(p[2]):Lerp(hexToColor(p[3]), 0.35)
            local b = textButton(presetFrame, p[1], UDim2.new(), UDim2.new(), color)
            b.LayoutOrder = i
            b.TextSize = 11
            b.MouseButton1Click:Connect(function()
                self.Settings.accent, self.Settings.bg, self.Settings.editor = p[2], p[3], p[4]
                applyTheme()
                scheduleSave()
            end)
        end
        local function hexRow(label, key)
            local row = make("Frame", { Size = UDim2.new(1, -6, 0, 30), BackgroundTransparency = 1, LayoutOrder = ord() }, settingsScroll)
            textLabel(row, label, UDim2.new(0.4, 0, 1, 0), UDim2.new(), 12)
            local box = make("TextBox", {
                Position = UDim2.new(0.4, 0, 0, 2), Size = UDim2.new(0.6, -4, 0, 26), BackgroundColor3 = "@editor",
                BorderSizePixel = 0, Text = "#" .. self.Settings[key], TextColor3 = "@text", TextSize = 12,
                Font = Enum.Font.Code, ClearTextOnFocus = false,
            }, row)
            corner(box, 4)
            box.FocusLost:Connect(function()
                local c = hexToColor(box.Text)
                if c then
                    self.Settings[key] = colorToHex(c)
                    applyTheme()
                    scheduleSave()
                else
                    setStatus("Use a hex color like #3FA876", "warn")
                end
                box.Text = "#" .. self.Settings[key]
            end)
            table.insert(hooks, function() box.Text = "#" .. self.Settings[key] end)
        end
        hexRow("Accent", "accent")
        hexRow("Window", "bg")
        hexRow("Editor", "editor")

        section("OPTIONS")
        local function toggleRow(label, key, onChange)
            local row = make("Frame", { Size = UDim2.new(1, -6, 0, 30), BackgroundTransparency = 1, LayoutOrder = ord() }, settingsScroll)
            textLabel(row, label, UDim2.new(1, -70, 1, 0), UDim2.new(), 12)
            local b = textButton(row, "", UDim2.fromOffset(56, 24), UDim2.new(1, -60, 0.5, -12), "btn")
            local function refresh()
                local on = self.Settings[key]
                b.Text = on and "ON" or "OFF"
                b.TextColor3 = on and theme.accent or theme.muted
            end
            b.MouseButton1Click:Connect(function()
                self.Settings[key] = not self.Settings[key]
                refresh()
                if onChange then onChange(self.Settings[key]) end
                scheduleSave()
            end)
            table.insert(hooks, refresh)
        end
        toggleRow("Animations", "animations")
        toggleRow("Syntax colors", "highlight", function() applyEditorStyle() end)
        toggleRow("Line numbers", "lineNumbers", function() applyEditorStyle() end)
        toggleRow("Auto-indent", "autoIndent")

        section("MORE")
        local resetButton = textButton(settingsScroll, "Reset to defaults", UDim2.new(1, -6, 0, 30), UDim2.new(), "btn")
        resetButton.LayoutOrder = ord()
        resetButton.MouseButton1Click:Connect(function()
            for k, val in pairs(DEFAULTS) do self.Settings[k] = val end
            applyAll()
            scheduleSave()
        end)
        local unload = textButton(settingsScroll, "Unload XFIN", UDim2.new(1, -6, 0, 30), UDim2.new(), "danger")
        unload.LayoutOrder = ord()
        local confirmUnload = false
        unload.MouseButton1Click:Connect(function()
            if confirmUnload then gui:Destroy() return end
            confirmUnload = true
            unload.Text = "Tap again to unload"
            task.delay(3, function()
                confirmUnload = false
                if unload.Parent then unload.Text = "Unload XFIN" end
            end)
        end)
        local hint = textLabel(settingsScroll, "Closing with × only hides XFIN. Reopen with the X button or RightShift.", UDim2.new(1, -6, 0, 30), UDim2.new(), 10, "muted")
        hint.TextWrapped = true
        hint.TextTruncate = Enum.TextTruncate.None
        hint.LayoutOrder = ord()
    end

    -- ------------------------------------------------ theme + settings application
    applyTheme = function()
        computeTheme()
        for i = #themed, 1, -1 do
            local e = themed[i]
            if e[1].Parent == nil then
                table.remove(themed, i)
            else
                pcall(function() e[1][e[2]] = theme[e[3]] end)
            end
        end
        for _, hook in ipairs(hooks) do pcall(hook) end
        pcall(function() launcher:FindFirstChildOfClass("UIStroke").Color = theme.accent end)
        if self._lastScripts then self:SetScriptList(self._lastScripts, self._lastCurrent) end
        refreshVisuals()
    end

    applyAll = function()
        local w, h = clampSize(self.Settings.width, self.Settings.height)
        root.Size = UDim2.fromOffset(w, h)
        applyTheme()
        applyEditorStyle()
        layoutEditor(true)
    end

    local saveToken = 0
    scheduleSave = function()
        saveToken += 1
        local my = saveToken
        task.delay(0.6, function()
            if my ~= saveToken then return end
            if saveSettings(self.Settings) then
                setStatus("Settings saved", "success")
            else
                setStatus("Settings applied (no file access, so not saved)", "warn")
            end
        end)
    end

    -- ------------------------------------------------ button wiring
    closeButton.MouseButton1Click:Connect(function() self:Close() end)
    settingsButton.MouseButton1Click:Connect(function() togglePanel(settingsPanel) end)
    closeSettings.MouseButton1Click:Connect(function() setPanel(settingsPanel, false) end)
    filesButton.MouseButton1Click:Connect(function() togglePanel(sidebar) end)
    explorerButton.MouseButton1Click:Connect(function()
        togglePanel(explorer)
        if panelState[explorer] then refreshExplorerTree() end
    end)
    closeExplorer.MouseButton1Click:Connect(function() setPanel(explorer, false) end)
    refreshExplorer.MouseButton1Click:Connect(refreshExplorerTree)

    newButton.MouseButton1Click:Connect(function()
        local base = (fileName.Text ~= "" and fileName.Text) or "Script.lua"
        local candidate = base
        local number = 2
        while self._scriptNames[candidate] do
            local stem, extension = base:match("^(.*)(%.[^%.]+)$")
            if not stem then stem, extension = base, ".lua" end
            candidate = stem .. number .. extension
            number += 1
        end
        fileName.Text = candidate
        invoke("CreateScript", candidate)
    end)
    saveButton.MouseButton1Click:Connect(function() invoke("SaveScript", fileName.Text, editor.Text) end)
    runButton.MouseButton1Click:Connect(function() invoke("RunScript", fileName.Text, editor.Text) end)
    clearButton.MouseButton1Click:Connect(function() editor.Text = ""; invoke("SourceChanged", "") end)
    reviewButton.MouseButton1Click:Connect(function() invoke("RunTestOperation", "source-review", editor.Text) end)
    deleteButton.MouseButton1Click:Connect(function() invoke("DeleteScript", fileName.Text) end)
    outClear.MouseButton1Click:Connect(function() self:ClearLog() end)
    outToggle.MouseButton1Click:Connect(function()
        self.Settings.outputOpen = not self.Settings.outputOpen
        layoutEditor(false)
        scheduleSave()
    end)
    indentButton.MouseButton1Click:Connect(function()
        local text = editor.Text
        local pos = math.clamp(lastCursor or (#text + 1), 1, #text + 1)
        editor.Text = text:sub(1, pos - 1) .. "    " .. text:sub(pos)
        editor:CaptureFocus()
        lastCursor = pos + 4
        task.defer(function() editor.CursorPosition = pos + 4 end)
    end)

    -- ------------------------------------------------ start
    applyAll()
    self:Log("XFIN ready. Reopen anytime with the X button or RightShift.", "info")
    self:Open()
    return self
end

return XfinUI
