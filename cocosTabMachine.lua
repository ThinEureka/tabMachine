
--author cs
--email 04nycs@gmail.com
--https://github.com/ThinEureka/tabMachine
--created on July 13, 2019 

local tabMachine = require("app.common.tabMachine.tabMachine")

local cocosTabMachine = tabMachine

local cocosContext = require("app.common.tabMachine.cocosContext")

-------------------------- cocosTabMachine ----------------------

cocosTabMachine.p_ctor = tabMachine.ctor
cocosTabMachine.p_createException = tabMachine._createException

function cocosTabMachine:ctor()
    cocosTabMachine.p_ctor(self)
    self._updateTimer = nil
    self._tickTimer = nil
    
    self._scheduler = self:createSystemScheduler()
end

function cocosTabMachine:createSystemScheduler()
    local cocosScheduler = cc.Director:getInstance():getScheduler()
    local actionManager = cc.Director:getInstance():getActionManager()
    return self:createScheduler(cocosScheduler, actionManager, nil) 
end

function cocosTabMachine:createScheduler(cocosScheduler, actionManager, ctrl)
    local scheduler = {}
    function scheduler:createTimer(callback, interval)
        if interval == 0 or interval == nil then
            return  cocosScheduler:scheduleScriptFunc(callback, 0, false)
        else
            return  cocosScheduler:scheduleScriptFunc(callback, interval, false)
        end
    end

    function scheduler:destroyTimer(handler)
        cocosScheduler:unscheduleScriptEntry(handler)
    end

    function scheduler:getCocosScheduler()
        return cocosScheduler
    end

    function scheduler:getActionManager()
        return actionManager
    end

    function scheduler:isUsingDirectorScheduler()
        return cocosScheduler == cc.Director:getInstance():getScheduler()
    end

    function scheduler:pause()
        if ctrl then
            ctrl:pause()
        end
    end

    function scheduler:resume()
        if ctrl then
            ctrl:resume()
        end
    end

    function scheduler:setTimeScale(timeScale)
        if ctrl then
            ctrl:setTimeScale(timeScale)
        else
            cocosScheduler:setTimeScale(timeScale)
        end
    end

    function scheduler:getTimeScale()
        if ctrl then
            return ctrl:getTimeScale()
        else
            return cocosScheduler:getTimeScale() 
        end
    end

    function scheduler:isPaused()
        if ctrl then
            return ctrl:isPaused()
        else
            return false
        end
    end

    return scheduler
end

function cocosTabMachine:getScheduler()
    return self._scheduler
end

function cocosTabMachine:getObject(path)
    if self._rootContext == nil then
        return nil
    end

    return self._rootContext:getObject(path)
end

function cocosTabMachine:_createContext(tab, ...)
    if tab ~= nil and tab.isTabClass then
        return tab.new(...)
    else
        local c = {}
        local class = (tab and tab.class) or cocosContext
        setmetatable(c, {__index = function(t, k)
            return (tab and tab[k]) or class[k]
        end})
        c.class = class
        c:ctor(...)
        return c
    end
end

function cocosTabMachine:_createException(errorMsg, isTabMachineError)
    local e = cocosTabMachine.p_createException(self, errorMsg, isTabMachineError)
    e.luaErrorMsg = errorMsg
    e.luaStackTrace = tostring(debug.traceback("", 2))
    return e
end

function cocosTabMachine:_addContextException(e, context)
    if e.tabStacks == nil then
        e.tabStacks = {}
    end

    local tabStack = {}
    table.insert(e.tabStacks, tabStack)

    local c = context
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
        table.insert(tabStack, pc)
        c = c._pp
    end
end

function cocosTabMachine:_onUnCaughtException(e)
    dump(e, "uncaught exception", 100)

    --上报
    local eMsg = ""
    local errorMsg = e.errorMsg or "no errorMsg"
    local reportVals = self:getObject("report") and self:getObject("report"):getTreeMsg() or "no reportVals"
    local tabStacks = e.tabStacks and self:prettyStr(e.tabStacks or {}) or "no tabStacks"
    local luaStackTrace = e.luaStackTrace or "no luaStackTrace"
    local tabTreeInfo = self._rootContext and self._rootContext:getTreeMsg() or ""

    local strTop = "==== errorMsg ====\n"
    eMsg = eMsg .. strTop .. errorMsg
    strTop = "\n\n==== reportVals ====\n"
    eMsg = eMsg .. strTop .. reportVals
    strTop = "\n\n==== tabStacks ====\n"
    eMsg = eMsg .. strTop .. tabStacks
    strTop = "\n\n==== luaStackTrace ====\n"
    eMsg = eMsg .. strTop .. luaStackTrace
    strTop = "\n\n==== tabTreeInfo ====\n"
    eMsg = eMsg .. strTop .. tabTreeInfo
    if fabric then
        fabric:getInstance():allSet(tostring(errorMsg), eMsg)
    end

    if device.platform == "mac" or userSDKManager.isBeta() or userSDKManager.isReportError() then
        device.showAlert("出错了,测试使用,请截图", tostring(eMsg), {"下次不再显示","复制"}, function ( event )
            SoraDCopyText( tostring(eMsg) )
        end)
    end
end

function cocosTabMachine:_disposeContext(context)
    if context.dispose then
        context:dispose()
    end
end

function cocosTabMachine:prettyStr(arr)
    local str = "{\n"
    for i,v in ipairs(arr or {}) do
        str = str .. string.format("    [%d] = {\n", i)
        for m,n in ipairs(v or {}) do
            str = str .. "        "
            str = str .. string.format("%s", n.name)
            if n.className then
                str = str .. string.format("(%s)", n.className)
            end
            if n.nickName then
                str = str .. string.format("[%s]", n.nickName)
            end
            if n.pcName and n.pcAction then
                str = str .. string.format(":%s,%s", n.pcName, n.pcAction)
            end
            str = str .. "\n"
        end
        str = str .. "    }\n"
    end
    str = str .. "}"
    return str
end

return cocosTabMachine

