--author cs
--email 04nycs@gmail.com
--created on July 11, 2019 

local tabMachine = class("tabMachine")

tabMachine.context = class("context")

local context = tabMachine.context

tabMachine.event_context_stop = "context_stop"

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
    self._globalTabs = nil
    self._tab = nil
    self._curContext = nil
    self._tickIndex = 0
    self._isEntering = false
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

function tabMachine:start(...)
    print("machine start")
    if self._tab == nil then
        return
    end

    self._isRunning = true
    self:_pcallMachine(self._rootContext._enter, self._rootContext, ...)
end

function tabMachine:update(dt)
    self:_pcallMachine(self._rootContext._update, self._rootContext, dt)
end

function tabMachine:tick(index)
    self:_pcallMachine(self._rootContext._tick, self._rootContext, index)
end

function tabMachine:notify(msg, level)
    self:_pcallMachine(self._rootContext.notify, self._rootContext, msg, level)
end

function tabMachine:_addUpdate()
    -- to be need to be implemented by sub class
end

function tabMachine:_decUpdate()
    -- to be need to be implemented by sub class
end

function tabMachine:_addTick()
    -- to be need to be implemented by sub class
end

function tabMachine:_decTick()
    -- to be need to be implemented by sub class
end

function tabMachine:_addNotify()
    -- to be need to be implemented by sub class
end

function tabMachine:_decNotify()
    -- to be need to be implemented by sub class
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

function tabMachine:_pcall(f, ...)
    local function on_error(errorMsg)
        local e = self:_createException(errorMsg, false)

        local catched = false
        local curContext = self._curContext
        if curContext ~= nil then
            self._curContext = nil
            catched = curContext:_throwException(e)
        end

        if not catched then
            self:_onUnCaughtException(e)
        end
    end

    --print("machine xpcall")
    local a1, a2, a3, a4, a5, a6 = ...
    local stat, result = xpcall(function()
        return f(a1, a2, a3, a4, a5, a6)
    end, on_error) 

    if stat then
        return result
    end

    return nil
end

function tabMachine:_pcallMachine(f, ...)
    -- deal with excetion caused by machine itself
    -- such exceptions can't be properly handled by
    -- machine itself 
    -- or deal with external unprected calls which 
    -- you have no way to trace
    local function on_error(errorMsg)
        local e = self:_createException(errorMsg, true)
        local catched = false
        local curContext = self._curContext
        if curContext ~= nil then
            self._curContext = nil
            catched = curContext:_throwException(e)
        end
        self:_onUnCaughtException(e)
    end

    local a1, a2, a3, a4, a5, a6 = ...
    local stat, result = xpcall(function()
        return f(a1, a2, a3, a4, a5, a6)
    end, on_error) 

    if stat then
        return result
    end

    return nil
end

function tabMachine:_createException(errorMsg, isTabMachineError)
    -- the subclass may override to get the call stack info
    -- acoording to whether its debug or release configuration
    local exception = {}
    exception.errorMsg = errorMsg
    exception.isTabMachineError = isTabMachineError
    exception.isCustom = false
    
    return exception
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
    self.tm = nil
    self.p = nil
    self._pp = nil

    self._pc = nil
    self._pcAction = nil
    self._pcName = nil

    self._tab = nil
    self._name = nil
    self._isRoot = false

    self._isStopped = false
    self._isUpdateTickNotifyStopped = false
    self._isSubStopped = false
    self._isFinalized = false
    self._isDetached = false
    self._isDisposed = false
    self._isNotifyStopped = false

    self._headSubContext = nil
    self._tailSubContext = nil

    self._preContext = nil
    self._nextContext = nil

    self._eventFun = nil
    self._updateFun = nil
    self._tickFun = nil
    self._finalFun = nil
    self._catchFun = nil
    
    self._eventFunEx = nil
    self._updateFunEx = nil
    self._tickFunEx = nil
    self._finalFunEx = nil
    self._catchFunEx = nil

    self._outputVars = nil
    self._outputValues = nil

    self._needUpdateCount = 0
    self._needNotifyCount = 0
    self._needTickCount = 0

    self.v = {}
end

function context:_getAbsName()
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
    local curContext = self._headSubContext
    while curContext ~= nil  do
        if curContext.p == self and
            curContext._name == scName then
            return curContext
        end
        curContext = curContext._nextContext 
    end
    return nil
end

function context:_setPc(pc, pcName, action)
    self.tm._curContext = self
    self._pc = pc
    self._pcName = name
    self._pcAction = action
end

function context:start(scName, ...)
    print("start ",  self:_getAbsName().. "." ..scName)
    if self._isStopped then
        return
    end

    self:_setPc(self, "self", scName)

    local sub = self._tab[scName]
    local subUpdateFunEx = self._tab[scName.."_update"]
    local subEventFunEx = self._tab[scName.."_event"]
    local subTickFunEx = self._tab[scName.."_tick"]
    local subFinalFunEx = self._tab[scName.."_final"]
    local subCatchFunEx = self._tab[scName.."_catch"]

    if sub == nil and
        subUpdateFunEx == nil and
        subTickFunEx == nil and
        subEventFunEx == nil then 
            return
    end

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

            subContext._isEntering = true
            subContext:_prepareEnter()

            -- to ganrantee that the subcontext is added before execution
            if (sub ~= nil) then
                subContext:_setPc(subContext, "self", "start")
                self.tm:_pcall(sub, self, ...)
            end

            subContext._isEntering = false
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

        subContext._isEntering = true
        subContext:_prepareEnter()

        -- to ganrantee that the subcontext is added before execution
        if (sub ~= nil) then
            subContext:_setPc(subContext, "self", "start")
            self.tm:_pcall(sub, self, ...)
        end

        subContext._isEntering = false
    end
end

function  context:call(tabName, scName, outputVars, ...)
    print("call ", tabName, " ", self:_getAbsName().. "." .. scName)
    if self._isStopped then
        return
    end

    self:_setPc(self, scName, "call")
    local tab = nil
    if type(tabName) == "string" then
        tab = self._tab[tabName]
    elseif type(tabName) == "table" or type(tabName) == "userdata" then
        tab = tabName
    end

    if tab == nil then
        return
    end

    local subContext = self.tm:_createContext(tab, ...)
    subContext.tm = self.tm
    subContext.p = self
    subContext._pp = self
    subContext._name = scName

    subContext:_installTab(tab)
    subContext._outputVars = outputVars
    self:_addSubContext(subContext)
    subContext:_enter(...)
end

function  context:_callWithContext(context, tabName, scName, outputVars, ...)
    print("call ", tabName, " ", self:_getAbsName().. "." .. scName)
    if self._isStopped then
        return
    end

    self:_setPc(self, scName, "call")
    local tab = nil
    if type(tabName) == "string" then
        tab = self._tab[tabName]
    elseif type(tabName) == "table" or type(tabName) == "userdata" then
        tab = tabName
    end

    if tab == nil then
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
        if c.v.callack then
            c.v.callback()
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
    subContext.v.callback = callback

    for _, name in ipairs(scNames) do
        subContext.v._unTriggeredContexts[name] = true
    end

    self:_addSubContext(subContext)
    subContext:_prepareEnter()
end

function context:tabWait(scNames)
    local t = {
        s1 = function(c)
            self:join(scNames, "__wait__", function() c:stop() end )
        end,

        s1_event = function() end
    }
    return t
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
    print("checkStop ", self:_getAbsName(), self._isEntering,
        " ", self._headSubContext, " ",
        self._updateFun, " ", self._tickFun, " ", self._eventFun, " ")

    if self._isStopped then
        return
    end

    if self._headSubContext == nil 
        and self._updateFun == nil
        and self._tickFun == nil
        and self._eventFun == nil 
        and not self._isEntering then
        self:_stopSelf() 
    end
end

function context:_startNext(scName)
    print("start next ", self:_getAbsName().. "." ..scName)
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

    if splitPos == l then
        return
    end

    local base = scName:sub(1, splitPos)
    local num = scName:sub(splitPos + 1, l)
    num = tonumber(num)

    if num == nil then
        return
    end

    local nextSub = base .. (num + 1)
    return self:start(nextSub)
end

function context:_update(dt)
    -- inner update first
    if self._isStopped then
        return
    end

    if not self:_needUpdate() then
        return
    end

    self:_setPc(self, "self", "update")

    if self._updateFun then 
        self.tm:_pcall(self._updateFun, self, dt)
    end

    if self._updateFunEx and self.p then
        self.tm:_pcall(self._updateFunEx, self.p, dt)
    end

    local subContext = self._headSubContext
    while subContext ~= nil do
        if subContext.p and not subContext.p._isStopped then
            self:_setPc(subContext, subContext._name, "update_sub")
            subContext:_update(dt)
        end
        subContext = subContext._nextContext
    end
end

function context:_tick(index)
    -- inner update first
    if self._isStopped then
        return false
    end

    if not self:_needTick() then
        return false
    end

    self:_setPc(self, "self", "tick")

    if self._tickFun then 
        self.tm:_pcall(self._tickFun, self, index)
    end

    if self._tickFunEx then
        self.tm:_pcall(self._tickFunEx, self.p, index)
    end

    local subContext = self._headSubContext
    while subContext ~= nil do
        if subContext.p and not subContext.p._isStopped then
            self:_setPc(subContext, subContext._name, "tick_sub")
            subContext:_tick(index)
        end
        subContext = subContext._nextContext
    end
end

function context:notify(msg, level)
    if self._isStopped then
        return false
    end

    if not self:_needNotify() then
        return false
    end

    if level == nil then
        level = -1
    end

    if level == 0 then
        return false
    end

    self:_setPc(self, "self", "notify")

    local captured = false
    -- call ex notified first
    if self._eventFunEx and self.p then
        captured = self.tm:_pcall(self._eventFunEx, self.p, msg)
    end

    if captured then
        return true
    end

    if self._isStopped then
        return false
    end

    if self._eventFun then
        captured = self.tm:_pcall(self._eventFun, self, msg)
    end

    if captured then
        return true
    end

    if self._isStopped then
        return false
    end

    local subContext = self._headSubContext
    while subContext ~= nil do
        if subContext.p and not subContext.p._isStopped then
            self:_setPc(subContext, subContext._name, "notify_sub")
            captured = subContext:notify(msg, level - 1)
            if captured then
                return true
            end
        end
        subContext = subContext._nextContext
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
end

function  context:_enter(...)
    print("enter ",  self:_getAbsName())
    self._isEntering = true
    self:_prepareEnter()
    self:start("s1", ...)
    self._isEntering = false
    self:_checkStop()
end

function context:_prepareEnter()
    self:_setPc(self, "self", "prepare")

    if self:_selfNeedUpdate() then
        self:_addUpdate()
    end

    if self:_selfNeedTick() then
        self:_addTick()
    end

    if self:_selfNeedNotify() then
        self:_addNotify()
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
    print("stop ", self:_getAbsName())
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
    if self:_needUpdate() then
       if self.p then 
           self.p:_decUpdate()
       elseif self._isRoot then
           self.tm:_decUpdate()
       end
    end

    if self:_needTick() then
       if self.p then 
           self.p:_decTick()
       elseif self._isRoot then
           self.tm:_decTick()
       end
    end

    if self:_needNotify() then
       if self.p then 
           self.p:_decNotify()
       elseif self._isRoot then
           self.tm:_decNotify()
       end
    end
end

function context:_stopSubs()
    if self._isSubStopped then
        return
    end

    self:_setPc(self, "self", "stop_update_and_tick")

    self._isSubStopped = true
    local subContext = self._headSubContext
    while subContext ~= nil do
        subContext:stop()
        subContext = subContext._nextContext
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

function context:_detach()
    if self._isDetached then
        return
    end

    self._isDetached = true
    self:_setPc(self, "self", "finalize")

    local p = self.p
    local tm = self.tm
    if p then
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
    local p = self._pp
    local tm = self.tm
    
    self:_setPc(self, "self", "notify_stop")

    if p and not p._isStopped and p:_needNotify() then
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
end

function context:_addUpdate()
    if self._isStopped then
        return
    end

    local oldNeedUpdate = self:_needUpdate()
    self._needUpdateCount = self._needUpdateCount + 1
    if oldNeedUpdate ~= self:_needUpdate() then
        if self.p then
            return self.p:_addUpdate()
        elseif self._isRoot and self.tm then
            return self.tm:_addUpdate()
        end
    end
end

function context:_decUpdate()
    if self._isStopped then
        return
    end

    local oldNeedUpdate = self:_needUpdate()
    self._needUpdateCount = self._needUpdateCount - 1
    if oldNeedUpdate ~= self:_needUpdate() then
        if self.p then
            return self.p:_decUpdate()
        elseif self._isRoot and self.tm then
            return self.tm:_decUpdate()
        end
    end
end

function context:_needUpdate()
    return self._needUpdateCount > 0
end

function context:_selfNeedUpdate()
    return self._updateFun ~= nil or
        self._updateFunEx ~= nil
end

function context:_addTick()
    if self._isStopped then
        return
    end

    local oldNeedTick = self:_needTick()
    self._needTickCount = self._needTickCount + 1
    if oldNeedTick ~= self:_needTick() then
        if self.p then
            return self.p:_addTick()
        elseif self._isRoot and self.tm then
            return self.tm:_addTick()
        end
    end
end

function context:_decTick()
    if self._isStopped then
        return
    end

    local oldNeedTick = self:_needTick()
    self._needTickCount = self._needTickCount - 1
    if oldNeedTick ~= self:_needTick() then
        if self.p then
            return self.p:_decTick()
        elseif self._isRoot and self.tm then
            return self.tm:_decTick()
        end
    end
end

function context:_needTick()
    return self._needTickCount > 0
end

function context:_selfNeedTick()
    return self._tickFun ~= nil or
        self._tickFunEx ~= nil
end

function context:_addNotify()
    if self._isStopped then
        return
    end

    local oldNeedNotify = self:_needNotify()
    self._needNotifyCount = self._needNotifyCount + 1
    if oldNeedNotify ~= self:_needNotify() then
        if self.p then
            return self.p:_addNotify()
        elseif self._isRoot and self.tm then
            return self.tm:_addNotify()
        end
    end
end

function context:_decNotify()
    if self._isStopped then
        return
    end

    local oldNeedNotify = self:_needNotify()
    self._needNotifyCount = self._needNotifyCount - 1
    if oldNeedNotify ~= self:_needNotify() then
        if self.p then
            return self.p:_decNotify()
        elseif self._isRoot and self.tm then
            return self.tm:_decNotify()
        end
    end
end

function context:_needNotify()
    return self._needNotifyCount > 0
end

function context:_selfNeedNotify()
    return self._eventFun ~= nil or
        self._eventFunEx ~= nil
end

function context:_throwException(exception)
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
        return false
    end

    print("throwException ", self:_getAbsName())

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

return tabMachine

