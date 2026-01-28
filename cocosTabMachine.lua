
--author cs
--email 04nycs@gmail.com
--https://github.com/ThinEureka/tabMachine
--created on July 13, 2019 

local tabMachine = require("tabMachine.tabMachine")

local cocosTabMachine = tabMachine

local cocosContext = require("tabMachine.cocosContext")

-------------------------- cocosTabMachine ----------------------

cocosTabMachine.p_createException = tabMachine._createException

function cocosTabMachine:createSystemScheduler()
    return self:createScheduler(true) 
end

local scheduler = {}

function scheduler.new(isSystem)
    local s = {}
    setmetatable(s, {__index = scheduler})
    s._isSystem = isSystem
    s._timeScale = 1
    s._timerMgrList = {}
    return s
end

function scheduler:createTimer(target, callback, interval, timerMgrType)
    if timerMgrType == nil then 
        timerMgrType = 1 --g_t.updateTimerMgr_normal
    end

    local timerMgr = self._timerMgrList[timerMgrType]
    if not timerMgr then 
        timerMgr = require("framework.updater.timerMgr").new()
        timerMgr:setTimeScale(self._timeScale)
        self._timerMgrList[timerMgrType] = timerMgr
        updateFunctionAddTimerMgr(timerMgr, timerMgrType)
    end
    return timerMgr:createTimer(target, callback, interval, false)
end

function scheduler:destroyTimer(handler, timerMgrType)
    if timerMgrType == nil then 
        timerMgrType = 1 --g_t.updateTimerMgr_normal
    end
    local timerMgrList = self._timerMgrList
    if timerMgrList == nil then
        return
    end
    local timerMgr = timerMgrList[timerMgrType]
    timerMgr:removeTimer(handler)
end

function scheduler:pause()
    if self._isSystem then 
        return
    end
    local timerMgrList = self._timerMgrList
    if timerMgrList == nil then
        return
    end
    for k,v in pairs(timerMgrList) do 
        v:pause()
    end
end

function scheduler:resume()
    if self._isSystem then 
        return
    end
    local timerMgrList = self._timerMgrList
    if timerMgrList == nil then
        return
    end
    for k,v in pairs(timerMgrList) do 
        v:resume()
    end
end

function scheduler:setTimeScale(timeScale)
    if self._isSystem then 
        return
    end
    self._timeScale = timeScale
    local timerMgrList = self._timerMgrList
    if timerMgrList == nil then
        return
    end

    for k,v in pairs(timerMgrList) do 
        v:setTimeScale(timeScale)
    end
end

function scheduler:getTimeScale()
    return self._timeScale
end

function scheduler:isPaused()
    return false
end

function scheduler:dispose()
    if self._isSystem then 
        return
    end

    local timerMgrList = self._timerMgrList
    if timerMgrList == nil then
        return
    end
    for k,v in pairs(timerMgrList) do 
        updateFunctionRemoveTimerMgr(v, k)
    end
    self._timerMgrList = nil
end

function cocosTabMachine:createScheduler(isSystem)
    return scheduler.new(isSystem)
end

function cocosTabMachine:getScheduler()
    return self.__scheduler
end

function cocosTabMachine:getObject(path)
    if self.__rootContext == nil then
        return nil
    end

    return self.__rootContext:getObject(path)
end

--inline optimization
-- function cocosTabMachine:_recycleContext(context)
    -- table.insert(__contextPool, context)
-- end

-- function cocosTabMachine:_addContextException(e, context)
    -- if e.errorTabStatcks == nil then
        -- e.errorTabStatcks = {}
    -- end
--
    -- table.insert(e.errorTabStatcks, context:getDetailedPath())
-- end

-- function cocosTabMachine:_onUnCaughtException(e)
    -- dump(e, "uncaught exception", 100, printError)
--
    -- 上报
    -- local eMsg = ""
    -- local errorMsg = e.errorMsg or "no errorMsg"
    -- local reportVals = self:getObject("report") and self:getObject("report"):getTreeMsg() or "no reportVals"
    -- local errorTabStatcks = e.errorTabStatcks and self:prettyStr(e.errorTabStatcks or {}) or "no errorTabStatcks"
    -- local luaStackTrace = e.luaStackTrace or "no luaStackTrace"
--
    -- local strTop = "==== errorMsg ====\n"
    -- eMsg = eMsg .. strTop .. errorMsg
    -- strTop = "\n\n==== reportVals ====\n"
    -- eMsg = eMsg .. strTop .. reportVals
    -- strTop = "\n\n==== errorTabStatcks ====\n"
    -- eMsg = eMsg .. strTop .. errorTabStatcks
    -- strTop = "\n\n==== luaStackTrace ====\n"
    -- eMsg = eMsg .. strTop .. luaStackTrace
    -- if fabric then
        -- fabric:getInstance():allSet(tostring(errorMsg), eMsg, errorTabStatcks)
    -- end
--
    -- if g_enableDumpTabSnapshotOnCaughtException then
        -- if tabSnapshotLogger then
            -- tabSnapshotLogger:getInstance():dumpTabSnapshot(tostring(errorMsg), eMsg, errorTabStatcks)
        -- end
    -- end
-- end
--
-- function cocosTabMachine:_disposeContext(context)
    -- if context.dispose then
        -- context:dispose()
    -- end
-- end

-- function cocosTabMachine:prettyStr(arr)
    -- local str = ""
    -- for _,v in ipairs(arr or {}) do
        -- str = str .. v .. "\n"
    -- end
    -- return str
-- end

return cocosTabMachine

