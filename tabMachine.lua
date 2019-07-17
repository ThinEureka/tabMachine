--author cs
--email 04nycs@gmail.com
--created on July 11, 2019 

local tabMachine = class("tabMachine", function (target)
    if target == nil then
        target = {}
    end

    return target
end)

local context = class("context")

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

local function isValidGlobalTabName(name)
    return name:len() > 2 and name:sub(1, 2) == "::"
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
end

function tabMachine:installTab(tab)
    local subContext = self:_createContext()
    subContext.tm = self
    subContext.p = nil
    subContext._name = "root"
    subContext._isRoot = true
    self._rootContext = subContext
    self._tab = tab
    self._rootContext:_installTab(tab)
end

function tabMachine:start(...)
    if self._tab == nil then
        return false
    end

    self._isRunning = true
    self._rootContext:_enter(...)

    return true
end

function tabMachine:update(dt)
    return self._rootContext:_update(dt)
end

function tabMachine:notify(msg, level)
    self._rootContext:notify(msg, level)
end

function tabMachine:_addUpdate()
    -- to be need to be implemented by sub class
end

function tabMachine:_decUpdate()
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

function tabMachine:registerGlobalTab(name, tab)
    local typeName = type(name)
    assert(typeName == "string")
    assert(isValidGlobalTabName(name))
    local typeTab = type(tab)
    assert(typeTab == "table" or typeTab == "userdata")
    if self._globalTabs == nil then
        self._globalTabs = {}
    end
    self._globalTabs[name] = tab
end

function tabMachine:_getGlobalTab(name)
    if self._globalTabs == nil then
        return nil
    end

    return self._globalTabs[name]
end

function tabMachine:_setOutputs(outputValues)
    self._outValues = outputValues
end

function tabMachine:_onStopped()
    self._isRunning = false
    self._rootContext = nil
end

function tabMachine:_createContext()
    return context.new()
end

function tabMachine:_disposeContext(context)
    -- the subclass may need to do some disposing work
end

---------------------- context -------------------------

function context:ctor()
    self.tm = nil
    self.p = nil

    self._tab = nil
    self._name = nil
    self._isRoot = false

    if parent == nil then
        self.rc = self
    else
        self.rc = parent.rc
    end

    self._isStopped = false

    self._headSubContext = nil
    self._tailSubContext = nil

    self._preContext = nil
    self._nextContext = nil

    self._eventFun = nil
    self._updateFun = nil
    self._finalFun = nil
    
    self._eventFunEx = nil
    self._updateFunEx = nil
    self._finalFunEx = nil

    self._outputVars = nil
    self._outputValues = nil

    self._needUpdateCount = 0
    self._needNotifyCount = 0

    self.v = {}
end

function context:start(scName, ...)
    print("start ", scName)
    if self._isStopped then
        return false
    end

    local sub = self._tab[scName]
    local subUpdateFun = self._tab[scName.."_update"]
    local subEventFun = self._tab[scName.."_event"]
    local subFinalFunEx = self._tab[scName.."_final"]

    if sub == nil and subUpdateFun == nil and subEventFun == nil then
        return false
    end

    if subUpdateFun == nil and subEventFun == nil then
        sub(self, ...)
        if subFinalFunEx ~= nil then
            subFinalFunEx(self)
        end
        self:_checkNext(scName)
    else
        local subContext = self.tm:_createContext()
        subContext.tm = self.tm
        subContext.p = self
        subContext._name = scName

        subContext._updateFunEx = subUpdateFun
        subContext._eventFunEx = subEventFun
        subContext._finalFunEx = subFinalFunEx
        self:_addSubContext(subContext)

        subContext:_prepareEnter()

        -- to ganrantee that the subcontext is added before execution
        if (sub ~= nil) then
            sub(self, ...)
        end
    end

    return true
end

function  context:call(tabName, scName, outputVars, ...)
    print("call ", tabName, " ", scName)
    if self._isStopped then
        return false
    end

    local tab = nil
    if type(tabName) == "string" then
        if isValidGlobalTabName(tabName) then
            tab = self.tm:_getGlobalTab(tabName)
        else
            tab = self._tab[tabName]
        end
    elseif type(tabName) == "table" or type(tabName) == "userdata" then
        tab = tabName
    end

    if tab == nil then
        return false
    end

    local subContext = self.tm:_createContext()
    subContext.tm = self.tm
    subContext.p = self
    subContext._name = scName

    subContext:_installTab(tab)
    subContext._outputVars = outputVars
    self:_addSubContext(subContext)
    subContext:_enter(...)

    return true
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
        c:stop()
    end
    -- always return false
    return false
end

function context:join(scNames, scName)
    if self._isStopped then
        return false
    end

    if #scNames == 0 then
        return false
    end

    local subContext = self.tm:_createContext()
    subContext.tm = self.tm
    subContext.p = self
    subContext._name = scName
    subContext._eventFun = joint_event
    subContext.v._unTriggeredContexts = {}

    for _, name in ipairs(scNames) do
        subContext.v._unTriggeredContexts[name] = true
    end

    self:_addSubContext(subContext)

    subContext:_prepareEnter()

    return true
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
        return false
    end

    if scName == nil then
        self:_stopSelf(scName)
    else
        self:_stopSub(scName)
        self:_checkNext(scName)
    end

    return true
end

function context:_addSubContext(subContext)
    if self._isStopped then
        return false
    end

    if self._tailSubContext == nil then
        self._headSubContext = subContext
        self._tailSubContext = subContext
    else
        subContext._preContext = self._tailSubContext
        self._tailSubContext._nextContext = subContext
        self._tailSubContext = subContext
    end

    return true
end


function context:_removeSubContext(subContext)
    if subContext.p == nil then
        return false
    end

    if subContext == subContext.p._headSubContext then
        subContext.p._headSubContext = subContext._nextContext
    end

    if subContext == subContext.p._tailSubContext then
        subContext.p._tailSubContext = subContext._preContext
    end

    if subContext._preContext ~= nil then
        subContext._preContext._nextContext = subContext._nextContext
    end

    if subContext._nextContext ~= nil then
        subContext._nextContext._preContext = subContext._preContext
    end


    subContext.p = nil
    subContext.rc = nil
    subContext.tm = nil

    return true
end

function context:_checkNext(scName)
    if self._isStopped then
        return
    end

    if self:_startNext(scName) then
        return
    end

    self:_checkStop()
end

function context:_checkStop()
    if self._isStopped then
        return
    end

    if self._headSubContext == nil 
        and self._updateFun == nil
        and self._eventFun == nil then
        self:_stopSelf() 
    end
end

function context:_startNext(scName)
    print("start next ", scName)
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
        return false
    end

    local base = scName:sub(1, splitPos)
    local num = scName:sub(splitPos + 1, l)
    num = tonumber(num)

    if num == nil then
        return false
    end

    local nextSub = base .. (num + 1)
    return self:start(nextSub)
end

function context:_update(dt)
    -- inner update first
    if self._isStopped then
        return false
    end

    if not self:_needUpdate() then
        return false
    end

    if self._updateFun then 
        self._updateFun(self, dt)
    end

    if self._updateFunEx then
        self._updateFunEx(self.p, dt)
    end

    local subContext = self._headSubContext
    while subContext ~= nil do
        if subContext.p and not subContext.p._isStopped then
            subContext:_update(dt)
        end
        subContext = subContext._nextContext
    end

    return true
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

    local captured = false
    -- call ex notified first
    if self._eventFunEx then
        captured = self._eventFunEx(self.p, msg)
    end

    if captured then
        return true
    end

    if self._isStopped then
        return false
    end

    if self._eventFun then
        captured = self._eventFun(self, msg)
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
        return false
    end

    self._finalFun = self._tab.final
    self._updateFun = self._tab.update
    self._eventFun = self._tab.event

    return true
end

function  context:_enter(...)
    self:_prepareEnter()

    if self:start("s1", ...) then
        return
    end

    self:_checkStop()
end

function context:_prepareEnter()
    if self:_selfNeedUpdate() then
        self:_addUpdate()
    end

    if self:_selfNeedNotify() then
        self:_addNotify()
    end
end

function context:_stopSub(scName)
    local subContext = self._headSubContext
    while subContext ~= nil do
        if subContext.p == self and subContext._name == scName then
            subContext:stop()
        end
        subContext = subContext._nextContext
    end
end

function context:_stopSelf()
    print("stop ", self._name)

    self._isStopped = true

    if self:_needUpdate() then
       if self.p then 
           self.p:_decUpdate()
       elseif self._isRoot then
           self.tm:_decUpdate()
       end
    end

    if self:_needNotify() then
       if self.p then 
           self.p:_decNotify()
       elseif self._isRoot then
           self.tm:_decNotify()
       end
    end

    local subContext = self._headSubContext
    while subContext ~= nil do
        subContext:stop()
        subContext = subContext._nextContext
    end

    self._headSubContext = nil
    self._tailSubContext = nil

    -- inner final first
    if self._finalFun ~= nil then
        self._finalFun(self.p)
    end

    if self._finalFunEx ~= nil then
        self._finalFunEx(self.p)
    end

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

    tm:_disposeContext(self)
    self.p = nil
    self.tm = nil

    if p and not p._isStopped then
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
    elseif self._isRoot then
        tm:_onStopped()
    end
end

function context:_addUpdate()
    if self._isStopped then
        return false
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
        return false
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

function context:_addNotify()
    if self._isStopped then
        return false
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
        return false
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

return tabMachine

