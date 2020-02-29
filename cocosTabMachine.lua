
--author cs
--email 04nycs@gmail.com
--https://github.com/ThinEureka/tabMachine
--created on July 13, 2019 

local tabMachine = require("app.common.tabMachine.tabMachine")

local cocosTabMachine = class("cocosTabMachine", tabMachine)

local cocosContext = require("app.common.tabMachine.cocosContext")
local schedulerTime = require(cc.PACKAGE_NAME .. ".scheduler")

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
        self._updateTimer = schedulerTime.scheduleUpdateGlobal(function(dt)
            self:update(dt) end)
    end
end

function cocosTabMachine:_decUpdate()
    print("machine dec update")
    if self._updateTimer then
        schedulerTime.unscheduleGlobal(self._updateTimer)
        self._updateTimer = nil
    end
end

function cocosTabMachine:_addTick()
    print("machine add tick")
    if self._tickTimer == nil then
        local schedulerTime = require(cc.PACKAGE_NAME .. ".scheduler")
        self._tickTimer = schedulerTime.scheduleGlobal(function(dt)
            self:tick(dt) end, 1.0)
    end
end

function cocosTabMachine:_decTick()
    print("machine dec tick")
    if self._tickTimer then
        schedulerTime.unscheduleGlobal(self._tickTimer)
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
        pc.nickName = c._nickName
        if c.__cname ~= "cocosContext" and c.__cname ~= nil then
            pc.className = c.__cname
        end
        table.insert(e.tabStack, pc)
        c = c._pp
    end

    return e
end

function cocosTabMachine:_onUnCaughtException(e)
    dump(e, "uncaught exception", 100)

    --上报
    local eMsg = ""
    local errorMsg = e.errorMsg or "no errorMsg"
    local tabStack = e.tabStack and util.serialize(e.tabStack or {}) or "no tabStack"
    local luaStackTrace = e.luaStackTrace or "no luaStackTrace"

    local strTop = "==== errorMsg ====\n"
    eMsg = eMsg .. strTop .. errorMsg
    strTop = "\n\n==== tabStack ====\n"
    eMsg = eMsg .. strTop .. tabStack
    strTop = "\n\n==== luaStackTrace ===="
    eMsg = eMsg .. strTop .. luaStackTrace
    if fabric then
        fabric:getInstance():allSet(tostring(errorMsg), eMsg)
    end

    if device.platform == "mac" or userSDKManager.isBeta() or userSDKManager.isReportError() then
        device.showAlert("出错了,测试使用,请截图", tostring(eMsg), {"下次不再显示","确定"}, function ( event )
            
        end)
    end
end

function cocosTabMachine:_disposeContext(context)
    if context.dispose then
        context:dispose()
    end
end

return cocosTabMachine

