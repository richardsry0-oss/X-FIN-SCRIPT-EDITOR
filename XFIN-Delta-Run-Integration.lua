-- Add this AFTER creating the UI and attaching the backend in your XFIN loader.
-- Example order:
-- local ui = XfinUI.new(playerGui)
-- Backend.attach(ui)
-- then add the callback below.
--
-- This runs source in the current Delta client/executor environment only.
-- It does not grant server authority or execute server-only scripts.

ui.Callbacks.RunScript = function(fileName, source)
    if type(source) ~= "string" or source:match("^%s*$") then
        ui:Warn("Nothing to run.")
        return
    end

    if type(loadstring) ~= "function" then
        ui:Error("This runtime does not expose loadstring.")
        return
    end

    local compileOk, compiled, compileError = pcall(function()
        local fn, err = loadstring(source)
        return fn, err
    end)
    if not compileOk then
        ui:Error("Compile failed: " .. tostring(compiled))
        return
    end
    if type(compiled) ~= "function" then
        ui:Error("Compile failed: " .. tostring(compileError or "unknown error"))
        return
    end

    local runOk, runError = pcall(compiled)
    if not runOk then
        ui:Error("Runtime error: " .. tostring(runError))
    else
        ui:Success("Ran " .. tostring(fileName or "script") .. " in the client environment.")
    end
end
