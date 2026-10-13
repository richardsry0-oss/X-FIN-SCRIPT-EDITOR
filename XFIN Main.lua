local Players = game:GetService("Players")
local LogService = game:GetService("LogService")

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

-- Create the UI (running this again replaces the old window)
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ui = XfinUI.new(playerGui)

-- Attach the existing script editor backend
XfinBackend.attach(ui)

-- Run button: compile, run in its own thread, show errors + prints in the output panel
local activeRuns = 0
local logConn

ui.Callbacks.RunScript = function(fileName, source)
    if type(source) ~= "string" or source:match("^%s*$") then
        ui:Warn("The editor is empty.")
        return
    end

    if type(loadstring) ~= "function" then
        ui:Error("loadstring is unavailable.")
        return
    end

    local label = tostring(fileName or "script")

    local compileOK, fn, compileError = pcall(loadstring, source, "=" .. label)
    if not compileOK then
        ui:Error("Compile error: " .. tostring(fn))
        return
    end
    if type(fn) ~= "function" then
        ui:Error("Compile error: " .. tostring(compileError))
        return
    end

    -- Forward print/warn/error output to the XFIN output panel while the script runs
    -- (and for a few seconds after, to catch task.wait / event output).
    if logConn then logConn:Disconnect() end
    local thisConn
    thisConn = LogService.MessageOut:Connect(function(message, messageType)
        local kind = "print"
        if messageType == Enum.MessageType.MessageError then
            kind = "error"
        elseif messageType == Enum.MessageType.MessageWarning then
            kind = "warn"
        elseif messageType == Enum.MessageType.MessageInfo then
            kind = "info"
        end
        ui:Log(message, kind)
    end)
    logConn = thisConn

    activeRuns += 1
    ui:SetRunning(true)
    ui:Info("Running " .. label .. "...")
    local started = os.clock()

    task.spawn(function()
        local ok, err = xpcall(fn, function(e)
            return debug.traceback(tostring(e), 2)
        end)

        activeRuns -= 1
        if activeRuns <= 0 then
            activeRuns = 0
            ui:SetRunning(false)
        end

        if not ok then
            ui:Error("Runtime error: " .. tostring(err))
        else
            ui:Success(string.format("Finished %s in %.2fs", label, os.clock() - started))
        end

        task.delay(4, function()
            if logConn == thisConn then
                thisConn:Disconnect()
                logConn = nil
            end
        end)
    end)
end

ui:Success("XFIN loaded. Close with ×, reopen with the X button or RightShift.")
