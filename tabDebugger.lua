--author cs
--email 04nycs@gmail.com
--https://github.com/ThinEureka/tabMachine
--created on Jan 8, 2020  

local tabDebugger = class("tabDebugger")

function tabDebugger:ctor(traceback)
    self._traceback =  traceback
end

function tabDebugger:onMachineStart(machine, scName)
    local msg = g_frameIndex .. " tab start machine"  
    if self._traceback then
        msg = msg .. "\n" .. debug.traceback()
    end
    print(msg)
end

function tabDebugger:onContextStart(context, scName)
    local msg = g_frameIndex .. " tab start " ..  context:getDetailedPath(context) .. "." .. scName
    if self._traceback then
        msg = msg .. "\n" .. debug.traceback()
    end
    print(msg)
end

function tabDebugger:onContextQuit(context)
    local msg = g_frameIndex .. " tab quit " ..  context:getDetailedPath(context)
    if self._traceback then
        msg = msg .. "\n" .. debug.traceback()
    end
    print(msg)
end

function tabDebugger:onContextStop(context)
    local msg = g_frameIndex .. " tab stop " ..  context:getDetailedPath(context)
    if self._traceback then
        msg = msg .. "\n" .. debug.traceback()
    end
    print(msg)
end

function tabDebugger:onContextException(context, exception)
    local msg = g_frameIndex .. " tab throw exception " ..  context:getDetailedPath(context)
    if self._traceback then
        msg = msg .. "\n" .. debug.traceback()
    end
    print(msg)
end

function tabDebugger:onTabCall(context, scName, tabName)
    local msg = g_frameIndex .. " tab call " ..  context:getDetailedPath(context) .. "." .. scName
    if self._traceback then
        msg = msg .. "\n" .. debug.traceback()
    end
    print(msg)
end

function tabDebugger:onTabJoin(context, scName, scNames)
    local joins = table.concat(scNames, "")
    local msg = g_frameIndex .. " tab join " .. context:getDetailedPath(context) .. "." .. scName .. " " .. joins
    if self._traceback then
        msg = msg .. "\n" .. debug.traceback()
    end
    print(msg)
end

function tabDebugger:onTabSuspend(context, scName)
    local msg = g_frameIndex .. " tab suspend " ..  context:getDetailedPath(context) .. "." .. scName
    if self._traceback then
        msg = msg .. "\n" .. debug.traceback()
    end
    print(msg)
end

function tabDebugger:onTabResume(context, scName)
    -- TODO
    local msg = g_frameIndex .. " tab resume " ..  context:getDetailedPath(context) .. "." .. scName
    if self._traceback then
        msg = msg .. "\n" .. debug.traceback()
    end
    print(msg)
end

return tabDebugger
