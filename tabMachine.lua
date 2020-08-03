--author cs
--email 04nycs@gmail.com
--https://github.com/ThinEureka/tabMachine
--created on July 11, 2019 

local tabMachine = class("tabMachine")

tabMachine.context = class("context")

g_t = {}
g_t.anyOutputVars = {"a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8", "a9", "a10"}

local context = tabMachine.context

tabMachine.event_context_stop = "context_stop"
tabMachine.event_trigger = "event_trigger"

----------------- util functions ---------------------
local function outputValues(env, outputVars, outputValues)
    for i, var in ipairs(outputVars) do
        if var ~= nil then 
            if outputValues == nil then
                env[var] = nil
            else
                env[var] = outputValues[i] 
            end
        end
    end
end

local function isEmptyTable(t)
    for k, v in pairs(t) do
        return false
    end

    return true
end

----------------- tabMachine -------------------------

function tabMachine:ctor()
    self._isRunning = false
    self._rootContext = nil
    self._outputs = nil
    self._tab = nil
    self._curContext = nil
    self._tickIndex = 0
    self._debugger = nil
    self._contextStack = {}
    self._curStackNum = 0
end

function tabMachine:installTab(tab)
    local subContext = self:_createContext(tab)
    subContext.tm = self
    subContext.p = nil
    subContext._name = "root"
    subContext._isRoot = true
    self._rootContext = subContext
    self._tab = tab
    self._rootContext:_installTab(tab)
end

function tabMachine:setDebugger(debugger)
    self._debugger = debugger
end

function tabMachine:getDebugger()
    return self._debugger
end

function tabMachine:start(...)
    if self._debugger then
        self._debugger:onMachineStart(self)
    end
    if self._tab == nil then
        return
    end

    self._isRunning = true
    self._rootContext:_enter(...)
end

function tabMachine:notify(msg, level)
    self._rootContext:notify(msg, level)
end

function tabMachine:stop()
    self._rootContext:stop()
    -- callback _onStopped is expected to be called
    -- then the variables would be proerly set
end

function tabMachine:isRunning()
    return self._isRunning
end

function tabMachine:getOutputs()
    if self._outputs then
        return unpack(self._outputs)
    end

    return nil
end

function tabMachine:_setOutputs(outputValues)
    self._outValues = outputValues
end

function tabMachine:_onStopped()
    self._isRunning = false
    self._rootContext = nil
end

function tabMachine:_createContext(...)
    return context.new(...)
end

function tabMachine:_pcall(f, c, ...)

    local function on_error(errorMsg)
        local e = self:_createException(errorMsg)
        local i = self._curStackNum
        local catched = true
        while i > 0 do
            local context = self._contextStack[i].context
            if not context:_throwException(e) then
                self:_addContextException(e, context)
                catched = false
            end

            i = i - 1
            local lastContext = context
            while i > 0 do
                local context = self._contextStack[i].context
                if context == lastContext._pp or context == lastContext then
                    lastContext = context
                    i = i - 1
                else
                    break
                end
            end
        end

        if not catched then
            self:_onUnCaughtException(e)
        end
    end

    local curContextInfo
    self._curStackNum = self._curStackNum + 1
    if #self._contextStack < self._curStackNum then
        curContextInfo = {}
        curContextInfo.context = c
        table.insert(self._contextStack, curContextInfo)
    else
        curContextInfo = self._contextStack[self._curStackNum]
        curContextInfo.context = c
    end

    local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 = ...


    local stat, result = xpcall(function()
        return f(c, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
    end, on_error)

    curContextInfo.context = nil
    self._curStackNum = self._curStackNum -1

    if stat then
        return result
    end

    return nil
end

function tabMachine:_createException(errorMsg)
    -- the subclass may override to get the call stack info
    -- acoording to whether its debug or release configuration
    local exception = {}
    exception.errorMsg = errorMsg
    exception.isCustom = false
    
    return exception
end

function tabMachine:_addContextException(e, context)
end

function tabMachine:_onUnCaughtException(e)
    -- the subclass can override this function to 
    -- provide default handling of e
end

function tabMachine:_disposeContext(context)
    -- the subclass may need to do some disposing work
end

---------------------- context -------------------------

function context:ctor()
    --il assignment optimization]
    -- self.tm = nil
    -- self.p = nil
    -- self._pp = nil

    -- self._pc = nil
    -- self._pcAction = nil
    -- self._pcName = nil

    -- self._tab = nil
    -- self._name = nil

    --[false assignment optimization]
    -- self._isRoot = false

    -- self._isStopped = false
    -- self._isUpdateTickNotifyStopped = false
    -- self._isSubStopped = false
    -- self._isFinalized = false
    -- self._isDetached = false
    -- self._isDisposed = false
    -- self._isNotifyStopped = false

    --[nil assignment optimization]
    -- self._headSubContext = nil
    -- self._tailSubContext = nil

    -- self._preContext = nil
    -- self._nextContext = nil

    -- self._eventFun = nil
    -- self._updateFun = nil
    -- self._tickFun = nil
    -- self._finalFun = nil
    -- self._catchFun = nil
    
    -- self._eventFunEx = nil
    -- self._updateFunEx = nil
    -- self._tickFunEx = nil
    -- self._finalFunEx = nil
    -- self._catchFunEx = nil

    -- self._outputVars = nil
    -- self._outputValues = nil

    --self._updateTimer = nil
    --self._tickTimer = nil

    self._enterCount = 0
    self.v = {}
end

function context:_getPath()
    local c = self
    local name = nil
    while c do
        if name == nil then
            name = c._name
        else
            name = c._name .. "." .. name
        end
        c = c._pp
    end

    return name
end

function context:getSub(scName)
    local curContext = self._tailSubContext
    while curContext ~= nil  do
        if curContext.p == self and
            curContext._name == scName then
            return curContext
        end
        curContext = curContext._preContext 
    end
    return nil
end

function context:hasAnySub()
    return self._headSubContext ~= nil
end

function context:_setPc(pc, pcName, action)
    -- do return end
    -- self.tm._curContext = self
    self._pc = pc
    self._pcName = pcName
    self._pcAction = action
end

function context:start(scName, ...)
    if self._isStopped then
        return
    end

    if self._tab == nil then
        return
    end

    self:_setPc(self, "self", scName)

    self:_addEnterCount()
    local sub = self._tab[scName]
    if sub == nil then
        self:_decEnterCount()
        return
    end

    local debugger = self:_getDebugger()
    if debugger then
        debugger:onContextStart(self, scName)
    end

    local subUpdateFunEx = self._tab[scName.."_update"]
    local subEventFunEx = self._tab[scName.."_event"]
    local subTickFunEx = self._tab[scName.."_tick"]
    local subFinalFunEx = self._tab[scName.."_final"]
    local subCatchFunEx = self._tab[scName.."_catch"]

    if subUpdateFunEx == nil and
        subTickFunEx == nil and
        subEventFunEx == nil then
        if subCatchFunEx == nil then
            self.tm:_pcall(sub, self, ...)
            self:_checkNext(scName)
            if subFinalFunEx ~= nil then
                self.tm:_pcall(subFinalFunEx, self, ...)
            end
        else
            local subContext = self.tm:_createContext()
            subContext.tm = self.tm
            subContext.p = self
            subContext._pp = self
            subContext._name = scName

            subContext._finalFunEx = subFinalFunEx
            subContext._catchFunEx = subCatchFunEx
            self:_addSubContext(subContext)

            subContext:_prepareEnter()

            -- to ganrantee that the subcontext is added before execution
            if (sub ~= nil) then
                subContext:_setPc(subContext, "self", "start")
                self.tm:_pcall(sub, self, ...)
            end

            subContext:stop()
        end
    else
        local subContext = self.tm:_createContext()
        subContext.tm = self.tm
        subContext.p = self
        subContext._pp = self
        subContext._name = scName

        subContext._updateFunEx = subUpdateFunEx
        subContext._eventFunEx = subEventFunEx
        subContext._tickFunEx = subTickFunEx
        subContext._finalFunEx = subFinalFunEx
        subContext._catchFunEx = subCatchFunEx
        self:_addSubContext(subContext)

        subContext:_addEnterCount()
        subContext:_prepareEnter()

        -- to ganrantee that the subcontext is added before execution
        if (sub ~= nil) then
            subContext:_setPc(subContext, "self", "start")
            self.tm:_pcall(sub, self, ...)
        end
    end
    self:_decEnterCount()
end

function  context:call(tab, scName, outputVars, ...)
    local debugger = self:_getDebugger()
    if debugger then
        debugger:onTabCall(self, scName, tab)
    end

    if self._isStopped then
        return
    end

    self:_setPc(self, scName, "call")
    self:_addEnterCount()

    if tab == nil then
        self:_decEnterCount()
        return
    end

    local subContext = self.tm:_createContext(tab, ...)
    subContext.tm = self.tm
    subContext.p = self
    subContext._pp = self
    subContext._name = scName

    subContext:_installTab(tab)

    local subUpdateFunEx, subEventFunEx, subTickFunEx, subFinalFunEx, subCatchFunEx
    if self._tab then
        subUpdateFunEx = self._tab[scName.."_update"]
        subEventFunEx = self._tab[scName.."_event"]
        subTickFunEx = self._tab[scName.."_tick"]
        subFinalFunEx = self._tab[scName.."_final"]
        subCatchFunEx = self._tab[scName.."_catch"]
    end

    subContext._updateFunEx = subUpdateFunEx
    subContext._eventFunEx = subEventFunEx
    subContext._tickFunEx = subTickFunEx
    subContext._finalFunEx = subFinalFunEx
    subContext._catchFunEx = subCatchFunEx

    subContext._outputVars = outputVars
    self:_addSubContext(subContext)
    subContext:_enter(...)

    self:_decEnterCount()
end

function  context:_callWithContext(context, tab, scName, outputVars, ...)
    local debugger = self:_getDebugger()
    if debugger then
        debugger:onTabCall(self, scName, tab)
    end

    if self._isStopped then
        return
    end

    self:_setPc(self, scName, "call")
    self:_addEnterCount()

    if tab == nil then
        self:_decEnterCount()
        return
    end

    local subContext = self.tm:_createContext(...)
    subContext.tm = self.tm
    subContext.p = self
    subContext._pp = self
    subContext._name = scName

    subContext:_installTab(tab)
    subContext._outputVars = outputVars
    self:_addSubContext(subContext)
    subContext:_enter(...)

    self:_decEnterCount()
end

function context:throw(e)
    local exception = {}
    exception.isCustom = true
    exception.e = e
    
    local c = self
    if c._pc ~= nil and 
        c._pc ~= self and
        c._pc._pp == self then
        c = c._pc
    end

    c:_throwException(exception)
end

local function joint_event(c, msg)
    if not c.p or c.p._isStopped then
        return false
    end

    if type(msg) == "table" 
        and msg.eventType == tabMachine.event_context_stop
        and msg.p == c.p then
        c.v._unTriggeredContexts[msg.name] = nil
    end

    if isEmptyTable(c.v._unTriggeredContexts) then
        if c.v._callback then
            c.v._callback()
        end
        c:stop()
    end
    -- always return false
    return false
end

function context:join(scNames, scName, callback)
    if self._isStopped then
        return
    end

    if #scNames == 0 then
        return
    end

    self:_setPc(self, scName, "join")
    self.tm:_pcall(self._pJoin, self, scNames, scName, callback)
end

function context:_pJoin(scNames, scName, callback)
    local subContext = self.tm:_createContext()
    subContext.tm = self.tm
    subContext.p = self
    subContext._pp = self
    subContext._name = scName
    subContext._eventFun = joint_event
    subContext.v._unTriggeredContexts = {}
    subContext.v._callback = callback

    for _, name in ipairs(scNames) do
        subContext.v._unTriggeredContexts[name] = true
    end

    self:_addSubContext(subContext)
    subContext:_prepareEnter()
end

function context:tabWait(scNames, scName)
    local t = {
        s1 = function(c)
            self:join(scNames, scName, function() 
                c:output(true)
                c:stop() end )
        end,

        s1_event = function() end
    }
    return t
end

function context:tabWaitEvents(eventNames, scName)
    return {
        s1 = function(c)
            local scNames = {}
            for _, name in ipairs(eventNames) do
                local tab = {
                    s1 = g_t.empty_fun,
                    s1_event = function(c1, msg)
                        if not c1.p or c1.p._isStopped then
                            return false
                        end
                        if type(msg) == "table" 
                            and msg.eventType == tabMachine.event_trigger
                            and msg.target == self
                            and msg.eventName == c1._tab._ename then
                                c1:stop()
                                return true
                        end
                    end,
                    _ename = name,
                }
                local tabName = name .. "_start"
                self:call(tab, tabName)
                table.insert(scNames, tabName)
            end
            c:call(self:tabWait(scNames, scName), "s2")
        end,
    }
end

function context:hasSub(scName)
    local subContext = self._headSubContext
    while subContext do
        if subContext and subContext._name == scName then
            return true
        end
        subContext = subContext._nextContext
    end

    return false
end

function context:output(...)
    self._outputValues = {...}
end

function context:getOutputs()
    return self._outputValues
end

function context:abort(scName)
    local sc
    if scName ~= nil then
        sc = self:getSub(scName)
    else
        sc = self
    end
    
    if sc ~= nil then
        sc._name = "__abort" .. sc._name
        sc:stop()
    end
end

function context:stop(scName)
    if self._isStopped then
        return
    end

    if scName == nil then
        self:_stopSelf(scName)
    else
        self:_stopSub(scName)
        self:_checkStop()
    end
end

function context:stopAllSubs(scName)
    if self._isStopped then
        return
    end

    local curContext = self._tailSubContext
    while curContext ~= nil do
        if scName == nil or curContext._name == scName then
            curContext:stop()
        end
        curContext = curContext._preContext
    end
end

function context:isStopped()
    return self._isStopped
end

function context:_addSubContext(subContext)
    if self._isStopped then
        return
    end

    if self._tailSubContext == nil then
        self._headSubContext = subContext
        self._tailSubContext = subContext
    else
        subContext._preContext = self._tailSubContext
        self._tailSubContext._nextContext = subContext
        self._tailSubContext = subContext
    end
end


function context:_removeSubContext(subContext)
    if subContext.p == nil then
        return
    end

    if subContext == self._headSubContext then
        self._headSubContext = subContext._nextContext
        if self._headSubContext ~= nil and
            self._headSubContext.p == nil then
            self._headSubContext = nil
        end
    end

    if subContext == self._tailSubContext then
        subContext.p._tailSubContext = subContext._preContext
        if self._tailSubContext ~= nil and
            self._tailSubContext.p == nil then
            self._tailSubContext = nil
        end
    end

    if subContext._preContext ~= nil then
        subContext._preContext._nextContext = subContext._nextContext
    end

    if subContext._nextContext ~= nil then
        subContext._nextContext._preContext = subContext._preContext
    end

    subContext.p = nil
end

function context:_checkNext(scName)
    if self._isStopped then
        return
    end

    self:_startNext(scName) 
end

function context:_checkStop()
    -- print("checkStop ", self:_getPath(), self._isEntering,
    --     " ", self._headSubContext, " ",
    --     self._updateFun, " ", self._tickFun, " ", self._eventFun, " ")

    if self._isStopped then
        return
    end

    if self._headSubContext == nil 
        and self._updateFun == nil
        and self._tickFun == nil
        and self._eventFun == nil 
        and self._enterCount <= 0 then
        self:_stopSelf() 
    end
end

function context:_startNext(scName)
    --print("start next ", self:_getPath().. "." ..scName)
    local l = scName:len()
    local splitPos = l
    local zero = '0'
    local nine = '9'

    for i = l, 1, -1 do
        local code = scName:byte(i)
        if code < zero:byte() or code > nine:byte()  then
            splitPos = i
            break
        end
    end

    local num = 0

    local base = scName:sub(1, splitPos)
    num = scName:sub(splitPos + 1, l)
    num = tonumber(num)

    if num == nil then
        num = 0
    end

    local nextSub = base .. (num + 1)
    return self:start(nextSub)
end

function context:_update(dt)
    -- inner update first
    if self._isStopped then
        return
    end

    self:_setPc(self, "self", "update")
    self:_addEnterCount()

    if self._updateFun then 
        self.tm:_pcall(self._updateFun, self, dt)
    end

    if self._updateFunEx and self.p then
        self.tm:_pcall(self._updateFunEx, self.p, dt)
    end

    self:_decEnterCount()
end

function context:_tick(index)
    -- inner update first
    if self._isStopped then
        return false
    end

    self:_setPc(self, "self", "tick")
    self:_addEnterCount()

    if self._tickFun then 
        self.tm:_pcall(self._tickFun, self, index)
    end

    if self._tickFunEx then
        self.tm:_pcall(self._tickFunEx, self.p, index)
    end

    self:_decEnterCount()
end

function context:notify(msg, level)
    if self._isStopped then
        return false
    end

    if level == nil then
        level = -1
    end

    if level == 0 then
        return false
    end

    self:_setPc(self, "self", "notify")
    self:_addEnterCount()

    local captured = false
    -- call ex notified first
    if self._eventFunEx and self.p and self._eventFunEx ~= g_t.empty_event then
        captured = self.tm:_pcall(self._eventFunEx, self.p, msg)
    end

    if captured then
        self:_decEnterCount()
        return true
    end

    if self._isStopped then
        self:_decEnterCount()
        return false
    end

    if self._eventFun and self._eventFun ~= g_t.empty_event then
        captured = self.tm:_pcall(self._eventFun, self, msg)
    end

    if captured then
        self:_decEnterCount()
        return true
    end

    if self._isStopped then
        self:_decEnterCount()
        return false
    end

    if level == 1 then
        self:_decEnterCount()
        return false
    end

    local subContext = self._headSubContext
    while subContext ~= nil do
        if subContext.p and not subContext.p._isStopped then
            self:_setPc(subContext, subContext._name, "notify_sub")
            captured = subContext:notify(msg, level - 1)
            if captured then
                self:_decEnterCount()
                return true
            end
        end
        subContext = subContext._nextContext
    end
    self:_decEnterCount()

    return false
end

function context:upwardNotify(msg, lvl)
    local p = self
    if lvl == nil then
        lvl = -1
    end

    while lvl ~= 0 and p ~= nil and not p._isStopped do
        local captured = p:notify(msg, 1)
        if captured then
            return true
        end
        p = p.p
        lvl = lvl - 1
    end

    return false
end

function  context:_installTab(tab)
    self._tab = tab
    if tab == nil then
        return
    end

    self._finalFun = self._tab.final
    self._eventFun = self._tab.event
    self._catchFun = self._tab.catch
    self._tickFun = self._tab.tick
    self._updateFun = self._tab.update
end

function  context:_enter(...)
    self:_prepareEnter()
    self:start("s1", ...)
end

function context:_prepareEnter()
    self:_setPc(self, "self", "prepare")

    if self.p then
        self._debugger = self.p._debugger
    end

    if self:_selfNeedUpdate() then
        self._updateTimer = self.tm:_createTimer(function (dt) self:_update(dt) end)
    end

    if self:_selfNeedTick() then
        self._tickTimer = self.tm:_createTimer(function (dt) self:_tick() end, 1.0)
    end
end

function context:_stopSub(scName)
    self:_setPc(self, scName, "stop_sub")
    self.tm:_pcall(self._pStopSub, self, scName)
end

function context:_pStopSub(scName)
    local subContext = self._headSubContext
    while subContext ~= nil do
        if subContext.p == self and subContext._name == scName then
            self:_setPc(self, subContext._name, "stop_sub")
            subContext:stop()
        end
        subContext = subContext._nextContext
    end
end

function context:_stopSelf()
    local debugger = self:_getDebugger()
    if debugger then
        debugger:onContextStop(self)
    end

    self:_setPc(self, "self", "stop_self")
    self._isStopped = true
    self:_stopUpdateTickNotify()
    self:_stopSubs()
    self:_finalize()
    self:_detach()
    self:_dispose()
    self:_notifyStop()
end

function context:_stopUpdateTickNotify()
    if self._isUpdateTickNotifyStopped then
        return 
    end

    self:_setPc(self, "self", "stop_update_and_tick")
    self._isUpdateTickNotifyStopped = true

    if self._updateTimer then
        self.tm:_destroyTimer(self._updateTimer)
        self._updateTimer = nil
    end

    if self._tickTimer then
        self.tm:_destroyTimer(self._tickTimer)
        self._tickTimer = nil
    end
end

function context:_stopSubs()
    if self._isSubStopped then
        return
    end

    self:_setPc(self, "self", "stop subs")

    self._isSubStopped = true
    local subContext = self._tailSubContext
    while subContext ~= nil do
        subContext:stop()
        subContext = subContext._preContext
    end
end

function context:_finalize()
    if self._isFinalized then
        return
    end

    self._isFinalized = true
    self._headSubContext = nil
    self._tailSubContext = nil

    self:_setPc(self, "self", "finalize")

    -- inner final first
    if self._finalFun ~= nil then
        self.tm:_pcall(self._finalFun, self)
    end

    if self._finalFunEx ~= nil  and self.p then
        self.tm:_pcall(self._finalFunEx, self.p)
    end
end

function context:forEachSub(callback)
    self._isSubStopped = true
    local subContext = self._tailSubContext
    while subContext ~= nil do
        local isIterationFinished = callback(subContext)
        if isIterationFinished then
            break
        end
        subContext = subContext._preContext
    end
end

function context:_detach()
    if self._isDetached then
        return
    end

    self._isDetached = true
    self:_setPc(self, "self", "finalize")

    local p = self.p
    local tm = self.tm
    if p and not p._isStopped then
        if self._outputVars then
            outputValues(p.v, self._outputVars, self._outputValues)
        end
        p:_removeSubContext(self)
    elseif self._isRoot then
        tm:_setOutputs(self._outputVavlues)
    end
end

function context:_dispose()
    if self._isDisposed then
        return
    end

    self:_setPc(self, "self", "finalize")
    self._isDisposed = true
    self.tm:_disposeContext(self)
end

function context:_notifyStop()
    if self._isNotifyStopped then
        return
    end

    self._isNotifyStopped = true
    local p = self._pp
    local tm = self.tm

    self:_setPc(self, "self", "notify_stop")

    local addEnter = false
    if p and not p._isStopped then
        addEnter = true
        p:_addEnterCount()
        local msg = {
            eventType = tabMachine.event_context_stop,
            p = p,
            name = self._name
        }
        -- only down to its siblings
        p:notify(msg, 2)
    end

    if p and not p._isStopped then
        p:_checkNext(self._name)
        p:_checkStop()
    elseif self._isRoot then
        tm:_onStopped()
    end

    if addEnter then
         p:_decEnterCount()
    end
end

function context:_addEnterCount()
    if self._isStopped then
        return
    end
    self._enterCount = self._enterCount + 1
end

function context:_decEnterCount()
    if self._isStopped then
        return
    end

    self._enterCount = self._enterCount - 1
    if self._enterCount <= 0 then
        self:_checkStop()
    end
end

function context:_selfNeedUpdate()
    return self._updateFun ~= nil or
        self._updateFunEx ~= nil
end

function context:_selfNeedTick()
    return self._tickFun ~= nil or
        self._tickFunEx ~= nil
end

function context:_selfNeedNotify()
    return self._eventFun ~= nil or
        self._eventFunEx ~= nil
end

function context:_throwException(exception)
    if self._isNotifyStopped then
        return true
    end

    if self._isStopped then
        -- when expction is thrown after c 
        -- is stopped, the parent should not
        -- be notified. We ensure stop is atomic
        -- operation.
        self:_stopUpdateTickNotify()
        self:_stopSubs()
        self:_finalize()
        self:_detach()
        self:_dispose()
        -- notifyStop should not be called here

        --allow handling exception even after being stopped
        --return false
    end

    local debugger = self:_getDebugger()
    if debugger then
        debugger:onContextException(self, exception)
    end

    local isCatched = false
    if self._catchFun ~= nil then
        isCatched = self._catchFun(self, exception)
    end

    if self._catchFunEx ~= nil and
        self.p and
        not self.p._isStopped then
        isCatched = self._catchFunEx(self.p, exception)
    end

    if isCatched then
        return true
    end

    if self._pp then
        exception.pcName = self._pp._pcName
        exception.pcAction = self._pp._pcAction
        exception.scName = self._name
        return self._pp:_throwException(exception)
    end

    return false
end

function context:_getDebugger()
    if self._debugger ~= nil then
        return self._debugger
    end

    local tm = self.tm
    if tm == nil then
        return nil
    end

    return tm:getDebugger()
end

function context:setDebugger(debugger)
    self._debugger = debugger
    local subContext = self._headSubContext
    while subContext ~= nil do
        subContext:setDebugger(debugger)
        subContext = subContext._nextContext
    end
end

return tabMachine

