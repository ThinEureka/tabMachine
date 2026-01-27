local cjson = require("cjson")
local kTid = 1024
local kPid = 1024
local kCat = "tabMachine"
local Frequency = CS.System.Diagnostics.Stopwatch.Frequency
local microsecondPerTick = (1000 * 1000) / Frequency


local tabDebuggerTrace = {}

function tabDebuggerTrace.new()
    local t = {}
    setmetatable(t, {__index = t})
    t._ContextStartAsDurationEvents = false
    t._traceEvents = {}
    t._stopwatch = CS.System.Diagnostics.Stopwatch.StartNew()
	return t
end

function tabDebuggerTrace:close()
    local success, filePath, fileSize = self:saveTraceFile()
    print(filePath, success, fileSize)
end

function tabDebuggerTrace:getTimestamp()
    local ticks = self._stopwatch.ElapsedTicks
    return microsecondPerTick * ticks
end

function tabDebuggerTrace:getDetailedPath(context)
    local c = context
    local name = nil
    if c then
        name = c.__name
    else
        name = ""
    end

    return tostring(name)
end

local function on_error(e)
    printError(e)
end
function tabDebuggerTrace:saveTraceFile()
    local context = ""
    local success = false
    local fileSize = 0
    local fileName = os.date('trace_%Y-%m-%d-%H-%M-%S')
    local filePath = CS.System.IO.Path.Combine(CS.UnityEngine.Application.persistentDataPath, "tab_trace/" .. fileName .. ".json")
    success = xpcall(function()
        CS.SystemIOUtils.EnsureFileDirectoryExists(filePath)
        local data = {
            traceEvents = self._traceEvents,
        }
        context = cjson.encode(data)

        local file, err = io.open(filePath, "wb")
        if not err and file then
            file:write(context)
            fileSize = file:seek()
            file:close()
        end
    end, on_error)
    return success, filePath, fileSize
end

function tabDebuggerTrace:onMachineStart(machine, scName)
    local msg = g_frameIndex .. " tab start machine"
    if self._traceback then
        msg = msg .. "\n" .. debug.traceback()
    end
    print(msg)
end

function tabDebuggerTrace:onContextStart(context, scName)
    local fullName = context:getDetailedPath(context) .. "." .. scName
    if self._ContextStartAsDurationEvents then
        -- As Duration Events
        local name = scName
        local ts = self:getTimestamp()
        local args = {fullName = fullName}
        local traceEvent = { cat = kCat, pid = kPid, tid = kTid, ts = ts, ph = "B", name = name, args = args }
        table.insert(self._traceEvents, traceEvent)
        local ts = self:getTimestamp()
        local traceEvent = { cat = kCat, pid = kPid, tid = kTid, ts = ts, ph = "E", name = name, args = args }
        table.insert(self._traceEvents, traceEvent)
    else
        -- As Instant Events
        local name = "[tab start]" .. scName
        local ts = self:getTimestamp()
        local traceEvent = { cat = kCat, pid = kPid, tid = kTid, ts = ts, ph = "i", name = name}
        table.insert(self._traceEvents, traceEvent)
    end
end

function tabDebuggerTrace:onTabCall(context, scName, tabName)
    local name = scName
    local fullName = context:getDetailedPath(context) .. "." .. scName
    local args = {fullName = fullName}
    if type(tabName) == "string" and tabName ~= "context" then
        args.tabName = tabName
    end
    local ts = self:getTimestamp()
    local traceEvent = { cat = kCat, pid = kPid, tid = kTid, ts = ts, ph = "B", name = name, args = args }
    table.insert(self._traceEvents, traceEvent)
end

function tabDebuggerTrace:onContextStop(context)
    local name = self:getDetailedPath(context)
    local fullName = context:getDetailedPath(context)
    local args = {fullName = fullName}
    if type(context.tabName) == "string" and context.tabName ~= "context" then
        args.tabName = context.tabName
    end
    local ts = self:getTimestamp()
    local traceEvent = { cat = kCat, pid = kPid, tid = kTid, ts = ts, ph = "E", name = name, args = args }
    table.insert(self._traceEvents, traceEvent)
end

function tabDebuggerTrace:onContextQuit(context)
    local name = "[tab quit]" ..self:getDetailedPath(context)
    local fullName = context:getDetailedPath(context)
    local ts = self:getTimestamp()
    local traceEvent = { cat = kCat, pid = kPid, tid = kTid, ts = ts, ph = "i", name = name }
    table.insert(self._traceEvents, traceEvent)
end

function tabDebuggerTrace:onContextException(context, exception)
    local name = "[tab exception]" ..self:getDetailedPath(context)
    local fullName = context:getDetailedPath(context)
    local ts = self:getTimestamp()
    local traceEvent = { cat = kCat, pid = kPid, tid = kTid, ts = ts, ph = "i", name = name }
    table.insert(self._traceEvents, traceEvent)
end

function tabDebuggerTrace:onTabJoin(context, scName, scNames)
    local joins = table.concat(scNames, "")
    local name = "[tab join]" .. scName
    local fullName = context:getDetailedPath(context) .. "." .. scName .. " " .. joins
    local ts = self:getTimestamp()
    local traceEvent = { cat = kCat, pid = kPid, tid = kTid, ts = ts, ph = "i", name = name}
    table.insert(self._traceEvents, traceEvent)
end

function tabDebuggerTrace:onTabSuspend(context, scName)
    local name = "[tab suspend]" .. scName
    local fullName = context:getDetailedPath(context) .. "." .. scName
    local ts = self:getTimestamp()
    local traceEvent = { cat = kCat, pid = kPid, tid = kTid, ts = ts, ph = "i", name = name}
    table.insert(self._traceEvents, traceEvent)
end

function tabDebuggerTrace:onTabResume(context, scName)
    local name = "[tab resume]" .. scName
    local name = "[tab resume]" .. scName
    local fullName = context:getDetailedPath(context) .. "." .. scName
    local ts = self:getTimestamp()
    local traceEvent = { cat = kCat, pid = kPid, tid = kTid, ts = ts, ph = "i", name = name}
    table.insert(self._traceEvents, traceEvent)
end

return tabDebuggerTrace
