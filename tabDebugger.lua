--author cs
--email 04nycs@gmail.com
--https://github.com/ThinEureka/tabMachine
--created on Jan 8, 2020  

local tabDebugger = class("tabDebugger")

function tabDebugger:ctor()
end

function tabDebugger:onMachineStart(machine, scName)
    print("start machine")
end

function tabDebugger:onContextStart(context, scName)
    print("start ",  self:_getContextPath(context).. "." ..scName)
end

function tabDebugger:onContextStop(context)
    print("stop ",  self:_getContextPath(context))
end

function tabDebugger:onContextException(context, exception)
    print("throw exception ",  self:_getContextPath(context))
end

function tabDebugger:onTabCall(context, scName, tabName)
    print("call ",  self:_getContextPath(context).. "." ..scName)
end

function tabDebugger:_getContextPath(context)
    local c = context
    local name = nil
    while c do
        local partName = c._name

        if c.__cname and c.__cname ~= "cocosContext" then
            partName = partName .. "(" .. c.__cname .. ")"
        end

        if c._nickName then
            partName = partName .. "[" .. c._nickName .. "]"
        end

        if name == nil then
            name = partName
        else
            name = partName .. "." .. name
        end

        c = c._pp
    end

    return name
end


return tabDebugger
