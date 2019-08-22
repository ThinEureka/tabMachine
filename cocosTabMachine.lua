
--author cs
--email 04nycs@gmail.com
--created on July 13, 2019 
--

local tabMachine = require("app.common.tabMachine.tabMachine")

local cocosTabMachine = class("cocosTabMachine", tabMachine)

local cocosContext = require("app.common.tabMachine.cocosContext")

-------------------------- cocosTabMachine ----------------------

function cocosTabMachine:ctor()
    tabMachine.ctor(self)
    self._updateTimer = nil
    self._tickTimer = nil
end

function cocosTabMachine:getObject(path)
    if self._rootContext == nil then
        return nil
    end

    return self._rootContext:getObject(path)
end

function cocosTabMachine:_addUpdate()
    print("machine add update")
    if self._updateTimer == nil then
        self._updateTimer = SoradCreateTimer(self, function(dt)
                self:update(dt)
            end, true)
    end
end

function cocosTabMachine:_decUpdate()
    print("machine dec update")
    if self._updateTimer then
        SoraDManagerRemoveTimer(self, self._updateTimer)
        self._updateTimer = nil
    end
end

function cocosTabMachine:_addTick()
    print("machine add tick")
    if self._tickTimer == nil then
        self._tickTimer = SoradCreateTimer(self, function(dt)
                print("m tick")
                self._tickIndex = self._tickIndex + 1
                self:tick(self._tickIndex)
            end, false)
    end
end

-- to restart timer in the case all timers are 
-- stopped globally
function cocosTabMachine:refreshTimer()
    if self._updateTimer ~= nil then
        self._updateTimer = nil
        self:_addUpdate()
    end

    if self._tickTimer ~= nil then
        self._tickTimer = nil
        self:_addTick()
    end
end

function cocosTabMachine:_decTick()
    print("machine dec tick")
    if self._tickTimer then
        SoraDManagerRemoveTimer(self, self._tickTimer)
        self._tickTimer = nil
    end
end

function tabMachine:_addNotify()
    print("machine add notify")
end

function tabMachine:_decNotify()
    print("machine dec notify")
end

function cocosTabMachine:_onStopped()
    print("machine stopped")
    tabMachine._onStopped(self)
end

function cocosTabMachine:_createContext(tab, ...)
    if tab ~= nil and tab.isTabClass then
        return tab.new(...)
    else
        return cocosContext.new(...)
    end
end

function cocosTabMachine:_createException(errorMsg, isTabMachineError)
    local e = tabMachine._createException(self, errorMsg, isTabMachineError)
    
    e.luaErrorMsg = errorMsg
    e.luaStackTrace = tostring(debug.traceback("", 2))
    e.tabStack = {}

    local c = self._curContext
    if c ~= nil then
        e.pcName = c._pcName
        e.pcAction = c._pcAction
    end

    while c ~= nil do
        local pc = {}
        pc.pcName = c._pcName
        pc.pcAction = c._pcAction
        pc.name = c._name
        table.insert(e.tabStack, pc)
        c = c._pp
    end

    return e
end

function cocosTabMachine:_onUnCaughtException(e)
    dump(e, "uncaught exception", 100)
    device.showAlert("出错了,测试使用,请截图", tostring(e.luaStackTrace), {"下次不再显示","确定"}, function ( event )
        
    end)
end

function cocosTabMachine:_disposeContext(context)
    if context.dispose then
        context:dispose()
    end
end

return cocosTabMachine

