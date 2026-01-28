--author cs
--email 04nycs@gmail.com
--https://github.com/ThinEureka/tabMachine
--created on July 11, 2019 


local tabMachine = require("tabMachine.tabMachine")
local socket = require("socket")

local cocosContext = tabMachine.context
cocosContext.isTabClass = true
local context_stopSelf  = cocosContext._stopSelf 
-- cocosContext.reuse = true

--inline optimization
-- cocosContext.p_ctor = cocosContext.ctor

-- function cocosContext:ctor()
--     cocosContext.p_ctor(self)
-- end


local tabMachine_pcall = tabMachine._pcall

function cocosContext:registerMsg(msg, fun, selfObj)
    -- if self.__lifeState >= lifeState.quitting then
    if self.__lifeState >= 20 then
        return
    end

    self.__needDispose = true
    self._hasMsg = true

    if selfObj then
        g_msgMgr:addMsg(self, msg, function(...)
            tabMachine_pcall(self, fun, ...)
        end, selfObj)
    else
        g_msgMgr:addMsg(self, msg, function(_, ...)
            tabMachine_pcall(self, fun, ...)
        end)
    end
end

function cocosContext:registerMsgEx(msgTable)
    for k, v in pairs(msgTable) do
        if type(k) == "string" then
            self:registerMsg(g_msg[k], v, self)
        elseif type(k) == "table" then
            for _, msg in ipairs(k) do
                self:registerMsg(g_msg[msg], v, self)
            end
        end
    end
end

function cocosContext:unRegisterMsg(msg)
    if self._hasMsg then
        g_msgMgr:removeMsgByName(self, msg)
    end
end

function cocosContext:registerMsgs(msgs, fun)
    -- if self.__lifeState >= lifeState.quitting then
    if self.__lifeState >= 20 then
        return
    end

    for _, msg in ipairs(msgs) do
        self:registerMsg(msg, fun)
    end
end

function cocosContext:registerButtonClick(target, fun, monitor)
    -- if self.__lifeState >= lifeState.quitting then
    if self.__lifeState >= 20 then
        return
    end

    if self.btnClickList == nil then 
        self.btnClickList = {}
    end
    self.__needDispose = true
    local button
    if type(target) == "table" then 
        button = target:com(ct.button)
    else
        button = target
    end

    if self.btnClickList[button] then 
        return
    end

    local pc = self.__pc
    if pc == nil then
        pc = self
    end

    local monitorRef = nil 
    if monitor ~= nil then
        monitorRef = g_t.aliveRef(monitor)
    end
    -- local pcName = self._pcName
    -- local pcAction = self._action
    local action = CS.Utils.AddButtonListener(button, function (...)
        -- pc.__pc = pc
        -- pc.__pcName = pcName
        -- pc.__pcAction = pcAction

        local monitor = nil
        if monitorRef then
            monitor = monitorRef:getTarget()
        end

        if monitor == nil or monitor:isIdle() then
            tabMachine_pcall(self, fun, ...)
        end

    end)
    self.btnClickList[button] = action
end

function cocosContext:unregisterAllButtonClick(target)
    local button
    if type(target) == "table" then 
        button = target:com(ct.button)
    else
        button = target
    end
    
    button.onClick:RemoveAllListeners()
    if self.btnClickList and self.btnClickList[button] then 
        self.btnClickList[button] = nil
    end
end


function cocosContext:retainAsyncOperationHandle(handle, releaseFunc)
    -- if self.__lifeState >= lifeState.quitting then
    if self.__lifeState >= 20 then
        return
    end

    self.__needDispose = true
    if not handle then
        printError("retainAsyncOperationHandle handle is nil")
        return
    end
    if not self.asyncOperationHandlePool then
        self.asyncOperationHandlePool = {}
    end
    table.insert(self.asyncOperationHandlePool, {handle = handle, releaseFunc = releaseFunc})
end

function cocosContext:releaseAsyncOperationHandle(handle)
    if not self.asyncOperationHandlePool then
        return
    end

    local index = nil
    for i = #self.asyncOperationHandlePool, 1, -1 do
        local v = self.asyncOperationHandlePool[i]
        if handle==v.handle and v.releaseFunc then
            v.releaseFunc(v.handle)
            index = i
            break
        end
    end

    if index then
        table.remove(self.asyncOperationHandlePool, index)
    end

end
function cocosContext:releaseAllAsyncOperationHandle()
    if not self.asyncOperationHandlePool then
        return
    end

    for k, v in pairs(self.asyncOperationHandlePool) do
        if v.releaseFunc then
            tabMachine_pcall(self, v.releaseFunc, v.handle)
        end
    end
    self.asyncOperationHandlePool = nil
end

local removeBtnListener = function(target, action)
    target.onClick:RemoveListener(action)
end

function cocosContext:dispose()
    if self._hasMsg then
        g_msgMgr:removeMsgByTarget(self)
    end

    if self.btnClickList then 
        for target, action in pairs(self.btnClickList) do 
            tabMachine_pcall(self, removeBtnListener, target, action)
        end
        self.btnClickList = nil
    end

    if self.asyncOperationHandlePool then
        self:releaseAllAsyncOperationHandle()
    end
end

function cocosContext:getObject(path)
    if path == "" then
        return self
    end

    local object = self
    local beginIndex = 1

    local len = path:len()
    while object ~= nil and beginIndex <= len do
        local key = nil

        local endIndex = path:find(".", beginIndex, true)
        if endIndex == nil then
            endIndex = len + 1
        end

        key = path:sub(beginIndex, endIndex - 1)

        if key == "^" then
            object = self.p
        else
            object = object:getSub(key)
        end

        beginIndex = endIndex + 1
    end

    return object
end

function cocosContext:getTreeMsg()
    local msg = self:getMsg(self)
    return msg
end

function cocosContext:getMsg(context, prefix, msg)
    local xx = prefix or ""
    local name = xx..context.__name
    if context.tabName and context.tabName ~= "cocosContext" then
        name = name .. "(" .. context.tabName .. ")"
    end

    if context._nickName then
        name = name .. "[" .. context._nickName .. "]"
    end

    msg = msg or ""
    msg = msg .. "\n" .. name
    print(name)

    local subContext = context._headSubContext
    while subContext ~= nil do
        msg = self:getMsg(subContext, xx .. " ", msg)
        subContext = subContext._nextContext
    end
    return msg
end

-------------------------- gt --------------------------



g_t.tabError = _{
    s1 = g_t.empty_fun,
    event = g_t.empty_event,
}

g_t.tabSuccess = _{
    s1 = function (c, skipFrame)
        c:output(true)
        if skipFrame then
            c:call(g_t.skipFrames(1), "s2")
        end
    end,
}

g_t.tabFail = _{
    s1 = function (c, skipFrame)
        c:output(false)
        if skipFrame then
            c:call(g_t.skipFrames(1), "s2")
        end
    end,
}


g_t.tabForward = _{
    s1 = function(c, ...)
        c:output(...)
    end
}

g_t.skipFrames = _{
    s1 = function (c, totalFrames, tab)
        if g_t.debug then
            c._nickName = "skipFrames"
        end

        c.totalFrames = totalFrames or 1
        c.numFrames = 0
    end,

    update = function(c, dt)
        c.numFrames = c.numFrames + 1
        if c.numFrames >= c.totalFrames then
            c:stop()
        end
    end,

    __addNickName = function(c)
        c._nickName = "skipFrames<" .. (c.totalFrames)  .. ">"
    end,

}

g_t.waitMessage = _{
    s1 = function(c, msg)
        if g_t.debug then
            c._nickName = "waitMessage"
        end
        c.msg = msg

        c:registerMsg(msg, function(msg, data, ...)
            c:output(msg, data, ...)
            c:stop()
        end)
    end,

    __addNickName = function(c)
        c._nickName = "waitMessage<" .. (c.msg)  .. ">"
    end,

    event = g_t.empty_event,
}

g_t.waitMessageWithFilter = _{
    s1 = function(c, msg, filter)
        if g_t.debug then
            c._nickName = "waitMessageWithFilter"
        end
        c.msg = msg

        c:registerMsg(msg, function(msg, data, ...)
            local ok = true
            ok = filter(msg, data, ...)
            if ok then
                c:output(msg, data, ...)
                c:stop()
            end
        end)
    end,

    __addNickName = function(c)
        c._nickName = "waitMessageWithFilter<" .. (c.msg)  .. ">"
    end,

    event = g_t.empty_event,
}

g_t.pageViewChange = _{
    s1 = function(c, goTable, callBack)
        c.goTable = goTable
        c.isPage = goTable:com(ct.custom_pageView) ~= nil
        if c.isPage then
            goTable:addOnPageViewChangedListener(callBack)
        else
            goTable:addOnPageChangedListener(callBack)
        end
    end,
    event = g_t.empty_event,
    final = function(c)
        if c.isPage then
            c.goTable:ClearPageViewListener()
        else
            c.goTable:clearOnPageChanged()
        end
    end,

    __addNickName = function(c)
        c._nickName = "pageViewChange"
    end,
}

g_t.tabPageViewChange = _{
    s1 = function(c, goTable)
        c.goTable = goTable
        c.isPage = goTable:com(ct.custom_pageView) ~= nil

        local onPageChage = function(index) c:upwardNotify("pageChange", index) end
        if c.isPage then
            goTable:addOnPageViewChangedListener(onPageChage)
        else
            goTable:addOnPageChangedListener(onPageChage)
        end
    end,

    event = g_t.empty_event,
    final = function(c)
        if c.isPage then
            c.goTable:ClearPageViewListener()
        else
            c.goTable:clearOnPageChanged()
        end
    end,

    __addNickName = function(c)
        c._nickName = "pageViewChange"
    end,
}
g_t.eventTrigger = _{
    s1 = function(c, go, callback)
        c.trigger = go:GetComponent(typeof(EventTrigger))
        if isNil(c.trigger) then
            c.trigger = go:AddComponent(typeof(EventTrigger))
        end

        local downEntry, upEntry, dragEntry
        for i = 0, c.trigger.triggers.Count - 1 do
            local t = c.trigger.triggers[i]
            if t.eventID == EventTriggerType.PointerDown then
                downEntry = t
            elseif t.eventID == EventTriggerType.PointerUp then
                upEntry = t
            elseif t.eventID == EventTriggerType.Drag then
                dragEntry = t
            end
        end
        local createEntry = function(trigger, eventID)
            local entry = EventTrigger.Entry()
            entry.eventID = eventID
            entry.callback = EventTrigger.TriggerEvent()
            return entry
        end
        downEntry = downEntry or createEntry(c.trigger, EventTriggerType.PointerDown)
        upEntry = upEntry or createEntry(c.trigger, EventTriggerType.PointerUp)
        dragEntry = dragEntry or createEntry(c.trigger, EventTriggerType.Drag)

        downEntry.callback:AddListener(
            function()
                callback("down")
            end
        )
        upEntry.callback:AddListener(
            function()
                callback("up")
            end
        )
        dragEntry.callback:AddListener(
            function()
                callback("move")
            end
        )
        c.trigger.triggers:Add(downEntry)
        c.trigger.triggers:Add(upEntry)
        c.trigger.triggers:Add(dragEntry)
    end,
    final = function(c)
        for _,v in pairs(c.trigger.triggers) do
            v.callback:RemoveAllListeners()
            v.callback:Invoke()
        end
    end,
    event = g_t.empty_event,

    __addNickName = function(c)
        c._nickName = "eventTrigger<" .. (c.trigger.name)  .. ">"
    end,

}

-- compete中所有tab的第一个返回值必须是boolean, 并返回首个返回true的tab的索引及其返回值。若所有的tab执行结果都为false则返回nil
function g_t.compete(tabs)
    return _{
        s1 = function(c)
            if g_t.debug then
                c._nickName = "compete"
            end
            c.prefix = "__compete_sub"
            c.prefixLen = string.len(c.prefix)
            c.tabs = tabs
            c.faildCount = 0
            for k, tab in ipairs(c.tabs) do
                local name = c.prefix .. k
                c:registerLifeTimeListener(name, c)
                c:call(tab, name, g_t.anyOutputVars)
            end
        end,

        event = {
            [tabMachine.event_context_stop] = function(c, p, name, target)
                if name:find(c.prefix) then
                    local index = name:sub(c.prefixLen + 1)
                    if type(c.a1) ~= "boolean" then
                        printError("compete中所有tab的第一个返回值必须是boolean")
                        c:output(nil)
                        c:stop()
                        return
                    end

                    if c.a1 then
                        c:output(index, c.a2, c.a3, c.a4, c.a5, c.a6, c.a7, c.a8, c.a9, c.a10)
                        c:stop()
                    else
                        c.faildCount = c.faildCount + 1
                        if c.faildCount >= table.nums(tabs) then
                            c:output(nil)
                            c:stop()
                        end
                    end
                end
            end
        },

        __addNickName = function(c)
            c._nickName = "compete<" .. (#c.tabs)  .. ">"
        end,
    }
end


g_t.tabCS = _{
    s1 = function(c, csTab, reuse)
        c.csTab = csTab
        if reuse then
            c.csTab.IsReuse = reuse
        end
        c.csTab:_OnLuaStart(c)
    end,
    --private C# tab执行结束调用
    onCSStop = function(c)
        c.isCSStop = true
        c:stop()
    end,
    --private C# tab执行结束调用（带返回值）
    onCSReturn = function(c, outPutValue)
        c.isCSStop = true
        c:output(outPutValue)
        c:stop()
    end,
    onCSNotify = function(c, ...)
        c:upwardNotify("onCSNotify", ...)
    end,
    printCSTabError = function(c, ...)
        printError(..., (c and c.getDetailedPath and c:getDetailedPath()), debug.traceback("", 2))
    end,
    event = g_t.empty_event,
    final = function(c)
        if not c.isCSStop then
            c.csTab:_OnLuaStop()
        end
    end,

    __addNickName = function(c)
        c._nickName = "tabCS"
    end,
}

g_t.tabUnityCoroutine = _{
    s1 = function (c, asyncOperation, activeOnLoad)
        c._nickName = "asyncOperation"
        c.asyncOperation = asyncOperation
        if activeOnLoad == nil then activeOnLoad = true end
        c.activeOnLoad = activeOnLoad
    end,

    s1_event = g_t.empty_event,

    s1_update = function (c)
        if c.asyncOperation.IsDone==true then
            if c.asyncOperation:IsValid() then
                if c.asyncOperation.Status then
                    if c.asyncOperation.Status==CS.UnityEngine.ResourceManagement.AsyncOperations.AsyncOperationStatus.None then
                        assert(false)
                    elseif c.asyncOperation.Status==CS.UnityEngine.ResourceManagement.AsyncOperations.AsyncOperationStatus.Succeeded then
                        if not c.activeOnLoad then
                            c.asyncOperation.Result:ActivateAsync()
                            c:stop("s1")
                            return
                        end
                        c:output(true,c.asyncOperation)
                    elseif c.asyncOperation.Status==CS.UnityEngine.ResourceManagement.AsyncOperations.AsyncOperationStatus.Failed then
                        c:output(false)
                    end
                    c:stop()
                end
            else
                c:output(false)
                c:stop()
            end
        end
    end,

    s2 = g_t.empty_fun,

    s2_update = function(c)
        if c.asyncOperation.Result.Scene.isLoaded then
            c:output(true,c.asyncOperation)
            c:stop()
        end
    end,

    final = function(c)
        c.asyncOperation = nil
    end,

    __addNickName = function(c)
        c._nickName = "asyncOperation"
    end,
}

g_t.tabRequire = _{
    s1 = function(c, luaFiles, frameTime)
        c.index = 1
        c.luaFiles = luaFiles
        c.totalCount = #luaFiles
        if (not frameTime) then
            frameTime = 0.003
        end
        c.frameTime = frameTime
    end,
    update = function(c)
        local startTime = socket:gettime()
        while(c.index <= c.totalCount) do
            require(c.luaFiles[c.index])
            c.index = c.index + 1
            local endTime = socket:gettime()
            if (endTime - startTime >= c.frameTime) then
                return
            end
        end
        c:stop()
    end,
}

g_t.empty_tab = _{
    s1 = function()
    end,
}

g_t.tabContainer = _{
    s1 = g_t.empty_fun,
    event = g_t.empty_event,

    __addNickName = function(c)
        c._nickName = "tabContainer"
    end,
}

g_t.tabRefCount = _{
    s1 = function(c)
        c.refMap = {}
    end,

    tabRef = _{
        s1 = function(c, key)
            c.key = key
            c.count = 0
        end,
        event = {
            addRef = function(c, context)
                c.count = c.count + 1
                c:call(context:tabProxy(), "contentProxy")
            end,
            hasRef = function(c)
                return c:getSub("contentProxy") ~= nil
            end,
        },
        contentProxy1 = function(c)
            c.count = c.count - 1
            if c.count == 0 then
                c:output(c.key)
                c:stop()
            end
        end,
    },

    --public:
    acquire = function(c, context, key)
        if not c.refMap[key] then
            local refKeyTab = c:call(c.tabRef(key) >> "key", "ref")
            c.refMap[key] = refKeyTab
        end
        c.refMap[key]:notify("addRef", context)
    end,

    ref1 = function(c)
        c:upwardNotify("zero", c.key)
        c.refMap[c.key] = nil
    end,

    hasRef = function(c, key)
        if c.refMap[key] then
            return c.refMap[key]:notify("hasRef")
        end
    end,


    event = g_t.empty_event,
}

local aliveRefMetatable = nil
aliveRefMetatable = {
    isAlive = function(self)
        local c = rawget(self, "c")
        if c == nil then
            return false
        end

        local lifeId = rawget(c, "__lifeId")
        local savedLifeId = rawget(self, "lifeId")

        if lifeId ~= savedLifeId then
            self.c = nil
            return false
        end

        return true
    end,

    getTarget = function(self)
        local c = rawget(self, "c")
        if c == nil then
            return nil
        end

        local lifeId = rawget(c, "__lifeId")
        local savedLifeId = rawget(self, "lifeId")

        if lifeId ~= savedLifeId then
            return nil
        end

        return c
    end,

    isTargetStopped = function(self)
        local target = self:getTarget()
        return target == nil or target:isStopped()
    end
}

aliveRefMetatable.__index = aliveRefMetatable

function g_t.aliveRef(c)
    local t = {}
    t.c = c
    local lifeId = rawget(c, "__lifeId")
    assert(lifeId ~= nil)
    t.lifeId = lifeId
    setmetatable(t, aliveRefMetatable)

    return t
end

g_t.tabAliveMap = _{
    s1 = function(c, keepRunning)
        c.keepRunning = keepRunning
        c._map = {}
    end,

    event = g_t.empty_event,

    --public:
    set = function (c, key, value)
        if value == nil then
            c._map[key] = value
        else
            local t = g_t.aliveRef(value)
            if c.keepRunning then
                if t:isAlive() and not value:isStopped() then
                    c._map[key] = t
                end
            else
                c._map[key] = t
            end
        end
    end,

    get = function(c, key)
        local map = c._map
        local ref = map[key]
        if ref == nil then
            return nil
        end

        local target = ref:getTarget()
        if target == nil then
            map[key] = nil
            return nil
        end
        if c.keepRunning and target:isStopped() then
            map[key] = nil
            return nil
        end
        return target
    end,

    remove = function(c, key)
        c._map[key] = nil
    end,

    forEach = function(c, f, params)
        c:validate()
        local map = c._map
        for key, ref in pairs(map) do
            local target = ref:getTarget()
            local needToBreak = f(target, key, params)
            if needToBreak then
                return
            end
        end
    end,

    validate = function(c)
        local map = c._map
        for k, v in pairs(map) do
            if not v:isAlive() then
                map[k] = nil
            else
                if c.keepRunning and v:getTarget():isStopped() then
                    map[k] = nil
                end
            end
        end
    end,

    count = function(c)
        c:validate()
        local num = 0
        for k, v in pairs(c._map) do
            num = num + 1
        end
        return num
    end,

    clear = function(c)
        local map = c._map
        for k, _ in pairs(map) do
            map[k] = nil
        end
    end,
}

g_t.tabRunningMap = #g_t.tabAliveMap(true)

g_t.tabAliveList = _{
    s1 = function(c, keepRunning)
        c._keepRunning = keepRunning
        c._array = {}
    end,

    event = g_t.empty_event,

    _checkContextValidate = function(c, aliveRef)
        if aliveRef == nil then
            return false
        end
        if not aliveRef:isAlive() then
            return false
        end
        if c._keepRunning then
            local t = aliveRef:getTarget()
            if t:isStopped() then
                return false
            else
                return true
            end
        else
            return true
        end
    end,

    --public:
    pushBack = function (c, context)
        local t = g_t.aliveRef(context)
        if c:_checkContextValidate(t) then
            table.insert(c._array, t)
        end
    end,

    pushFront = function(c, context)
        local t = g_t.aliveRef(context)
        if c:_checkContextValidate(t) then
            table.insert(c._array, 1, t)
        end
    end,

    popBack = function(c)
        local array = c._array
        while #array > 0 do
            local ref = table.remove(array)
            local target = ref:getTarget()
            if target ~= nil then
                return target
            end
        end
    end,

    popFront = function(c)
        local array = c._array
        while #array > 0 do
            local ref = table.remove(array, 1)
            local target = ref:getTarget()
            if target ~= nil then
                return target
            end
        end
    end,

    remove = function(c, context)
        local array = c._array
        local index = #array
        while index > 0 do
            local ref = array[index]
            local target = ref:getTarget()
            if target == context then
                table.remove(array, index)
                return target
            elseif target == nil then
                table.remove(array, index)
                if ref.c == context then
                    return nil
                end
            end
            index = index - 1
        end
    end,

    forEach = function(c, f, params)
        c:validate()
        for _, ref in ipairs(c._array) do
            local target = ref:getTarget()
            local needToBreak = f(target, params)
            if needToBreak then
                return
            end
        end
    end,

    validate = function(c)
        local array = c._array
        local index = #array
        while index > 0 do
            local ref = array[index]
            if not c:_checkContextValidate(ref) then
                table.remove(array, index)
            end
            index = index - 1
        end
    end,

    count = function(c)
        c:validate()
        return #c._array
    end,

    clear = function(c)
        local array = c._array
        while #array > 0 do
            table.remove(array)
        end
    end,
}

g_t.tabRunningList = #g_t.tabAliveList(true)

function g_t.importMethodsFromTab(hostTab, comName, comTab)
    for k, v in pairs(comTab) do
        if type(v) == "function" and not g_t.isInstructionTag(k) and not hostTab[k] then
            hostTab[k] = function(self, ...)
                local sc = self[comName]
                return v(sc, ...)
            end
        end
    end
end

function g_t.importMethodsFromList(hostTab, comName, methodNames)
    for _, methodName in ipairs(methodNames) do
        hostTab[methodName] = function(self, ...)
            local sc = self[comName]
            return sc[methodName](sc, ...)
        end
    end
end

function g_t.isTab(t)
    return t.__hooked == true
end

function g_t.isInstructionTag(name)
    local len = name:len()
    local lastByte = name:byte(len)

    -- '0' = 48, '9' = 57
    if  lastByte >= 48 and lastByte <= 57 then
        return true
    end
    
    local splitPos = -1
    local labels = tabMachine.labels
    for _, labelLen in ipairs(tabMachine.labelLens) do
        splitPos = len - labelLen
        if splitPos <= 1 then
            break
        end

        -- '_' == 95
        if name:byte(splitPos) == 95 then
            break
        end

        --make sure splitPos is also correct for last iteration 
        splitPos = -1
    end

    if splitPos > 1 then
        local label = tag:sub(splitPos + 1, -1)
        return labels[label] ~= nil
    elseif splitPos == 0 then
        return labels[name] ~= nil
    end

    return false
end

g_t.tabMonitor = _{
    s1 = function(c)
        if g_t.debug then
            c:__addNickName()
        end
    end,

    event = g_t.empty_event,

    -- public:
    watch = function (c, target, scName)
        if target == nil then
            return
        end
        c:call(target:tabProxy(scName), "watch")
    end,

    isIdle = function (c)
        return c:getSub("watch") == nil
    end,

    waitIdle = function(c)
        return c.tabWaitIdle(c)
    end,

    --system:
    __addNickName = function(c)
        c._nickName = "tabMonitor"
    end,

    tabWaitIdle = _{
        s1 = function(c, target)
            c.target = target 
        end,

        update = function(c)
            if c.target:isIdle() then
                c:stop()
            end
        end,
    }
}

g_t.tabSimpleRequest = _{
    s1 = function(c, ip, port, reqMsg, respDecodeFunc, timeout)
        c.ip = ip
        c.port = port
        c.reqMsg = reqMsg
        c.socket = c:call(require("tabMachine.tabSocket"), "socket")
        if timeout then
            c:call(g_t.delay, "t1", nil, timeout)
        end
        if respDecodeFunc then
            c.tabReadResponse = #c.socket:tabReadOneSegment(respDecodeFunc, nil, timeout and timeout or 10, true)
        end
    end,

    t2 = function(c)
        c:output(nil, "Timeout")
        c:stop()
    end,

    s2 = function(c)
        c:call(c.socket:connect(c.ip, c.port), "s3", {"isSuccess", "err"})
    end,

    s4 = function(c)
        if c.isSuccess then
            local tabSocket = require("tabMachine.tabSocket")
            c:call(c.socket:tabInState(tabSocket.STATE.CONNECTED), "c1")
            if c.tabReadResponse then
                c.respMsg = nil
                c:call(c.tabReadResponse, "s5", {"respMsg"})
            end
            c.socket:send(c.reqMsg)
        else
            c:output(nil, c.err)
        end
    end,

    s6 = function(c)
        c:output(c.respMsg)
        c:stop()
    end,

    c2 = function(c)
        c:output(nil, "Disconnected")
        c:stop()
    end,
}

g_t.tabWaitEmpty = _{
    s1 = function(c, target)
        c.target = target
        c:update()
    end,

    update = function(c)
        local target = c.target
        if target.__subContexts == nil or #target.__subContexts == 0 then
            c:stop()
        end
    end,
}

g_t.tabSubLessEqual = _{
    s1 = function(c, target, count)
        c.count = count
        c.targetRef = g_t.aliveRef(target)
        c:update()
    end,

    update = function(c)
        local target = c.targetRef:getTarget()
        if not target then
            c:stop()
        end
        if target.__subContexts == nil or #target.__subContexts <= c.count then
            c:stop()
        end
    end,
}

require("tabMachine.tabClicks")
require("tabMachine.tabAction")
require("tabMachine.tabLanes")
require("tabMachine.tabHttp")

return cocosContext
