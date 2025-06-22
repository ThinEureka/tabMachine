--author cs
--email 04nycs@gmail.com
--
--https://github.com/ThinEureka/tabMachine
--created on July 11, 2019
local socket = require("socket")

local table = table
local table_insert = table.insert
local table_remove = table.remove
local table_unpack = table.unpack
local table_pack = table.pack
local table_concat = table.concat
local rawget = rawget
local rawset = rawset
local next = next
local pairs = pairs
local ipairs = ipairs
local assert = assert
local type = type
local setmetatable = setmetatable
local xpcall = xpcall
local select = select
local str_byte = string.byte
local str_len = string.len

local co_yield = coroutine.yield
local co_create = coroutine.create
local co_resume = coroutine.resume
local co_status = coroutine.status
local co_close =  coroutine.close 
local co_running = coroutine.running


local tabMachine = class("tabMachine")

local context = class("context")

tabMachine.context = context
-- local tabProfiler = require("tabMachine.tabProfiler")

tabMachine.event_context_stop = "context_stop"
tabMachine.event_context_enter = "context_enter"
tabMachine.event_context_resume = "context_resume"
tabMachine.event_context_suspend = "context_suspend"
tabMachine.event_proxy_attached = "proxy_attached"

tabMachine.labels = {
    update = true,
    updateInterval = true,
    updateTimerMgr = true, 
    event = true,
    catch = true,
    iquit  = true,
    final = true,
}

tabMachine.labelLens = {
}

local lifeState = {
    running = 10,
    quitting = 20,
    quittted = 30,
    stopped = 40,
    
    -- recycled = 50, --current not used
    -- clear = 60,    --current not used
}

tabMachine.lifeState = lifeState

g_t = {}
g_t.empty_event = {}
g_t.empty_touch = function(target, type) end

g_t.empty_frame = function(...) end
g_t.empty_fun = function(...) end
g_t.anyOutputVars = {"a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8", "a9", "a10", "a11", "a12"}


g_t.updateTimerMgr_normal = 1
g_t.updateTimerMgr_fixed = 2
g_t.updateTimerMgr_late = 3


tabMachine.tabKeywords = {
    --current not used
    tm = true,
    __scheduler = true,

    p = true,
    inner = true,

    co = true,
    __co = true,
    __coFun = true,

    --current not used
    __pp = true,

    __tab = true,
    __name = true,
    -- __isRoot = true,

    __lifeId = true,
    __lifeState = true,
    __enterCount = true,

    --current not used
    __isStopped = true,
    __isQuitted = true,
    __isQuitting = true,
    __isLifeTimeRelationStopped = true,
    __isUpdateTickNotifyStopped = true,
    __isSubStopped = true,
    __isFinalized = true,
    __isDetached = true,
    __isDisposed = true,
    __isNotifyStopped = true,
    __isProxyStopped = true,

    __event = true,
    __updateFun = true,
    __updateInterval = true,
    __updateTimerMgr = true,
    __quitFun = true,
    __finalFun = true,
    __catchFun = true,

    __eventEx = true,
    __updateFunEx = true,
    __updateIntervalEx = true,
    __updateTimerMgrEx = true,
    __quitFunEx = true,
    __finalFunEx = true,
    __catchFunEx = true,

    __outputVars = true,
    __outputValues = true,

    __updateTimer = true,

    __subContexts = true,
    --__childOpId = true,
    __headProxyInfo = true,

    __mapHeadListener = true,
    __headListenInfo = true,

    __runMode = true,
    __breakPoints = true,
    __suspends = true,

    _nickName = true,

    __dynamics = true,

    __needDispose = true,

    _hasMsg = true,

    __banRecycleOutputVars = true,
}



for label, _ in pairs(tabMachine.labels) do
    local len = label:len()
    if #tabMachine.labelLens == 0 then
        table_insert(tabMachine.labelLens, len)
    else
        local index = 1
        while index <= #tabMachine.labelLens do
            local oldLen = tabMachine.labelLens[index] 
            if len == oldLen then
                break
            elseif len < oldLen then
                table_insert(tabMachine.labelLens, index, len)
                break
            else
                if index == #tabMachine.labelLens then
                    table_insert(tabMachine.labelLens, len)
                else
                    index = index + 1
                end
            end
        end
    end
end

local tabMachine_pcall = nil

local __nextLifeId = 1

function g_nextLifeId()
    return __nextLifeId
end

__arrayPool = {}
local __arrayPool = __arrayPool

__mapPool = {}
local __mapPool = __mapPool

__contextPool = {}
local __contextPool = __contextPool

__contextRecyclePool = {}
local __contextRecyclePool = __contextRecyclePool

__subContainerPool = {}
local __subContainerPool = __subContainerPool

__subContainerRecyclePool = {}
local __subContainerRecyclePool = __subContainerRecyclePool

__contextTreePool = {}
local __contextTreePool = __contextTreePool

__contextTreeRecyclePool = {}
local __contextTreeRecyclePool = __contextTreeRecyclePool

g_frameIndex = 1
-- local g_frameIndex = g_frameIndex

__bindTabPool = {}
local __bindTabPool = __bindTabPool

__outputVarsPool = {}
local __outputVarsPool = __outputVarsPool

local tabMachine_compileTab = nil

local __anyDebuggerEanbled = false

local context_pJoin = nil
local context_pSelect = nil
local context_addSubContext = nil
local context_removeSubContext = nil
local context_checkNext = nil
local context_update = nil
local context_installTab = nil
-- local context_prepareEnter = nil
local context_stopSub = nil
local context_stopSelf = nil
local context_stopTree = nil
local context_collectStopTree = nil
local context_stopLifeTimeRelation = nil
local context_stopUpdateTickNotify = nil
local context_createTickAndUpdateTimers = nil
local context_destroyTickAndUpdateTimers = nil
local context_stopSubs = nil
local context_finalize = nil
local context_detach = nil
-- local context_dispose = nil
local context_notifyStop = nil
local context_notifyLifeTimeEvent = nil
local context_addEnterCount = nil
local context_decEnterCount = nil
local context_throwException = nil
local context_addProxy = nil
local context_removeProxy = nil

local context_resumeStepSuspends = nil
local context_needToBreak = nil
local context_addSuspend = nil
local context_addBreakPass = nil
local context_removeBreakPass = nil

local context_getLifeId = nil
local context_getSub = nil
local context_getSubByLifeId = nil
local context_getContextByLifeId = nil
local context_hasAnySub = nil

local context_start = nil
local context_call = nil
local context_throw = nil
local context_join = nil
local context_select = nil

local context_co_call = nil
local context_co_join = nil
local context_co_select = nil

local context_registerLifeTimeListener = nil
local context_unregisterLifeTimeListener = nil
local context_tabProxy = nil
local context_hasSub = nil
local context_output = nil
local context_getOutputs = nil
local context_abort = nil
local context_stop = nil
local context_stopAllSubs = nil
local context_getDetailedPath = nil
local context_isStopped = nil
local context_isQuitted = nil
local context_isQuitting = nil
local context_downDistance = nil
local context_upDistance = nil
local context_notify = nil
local context_notifyAll = nil
local context_upwardNotify = nil
local context_upwardNotifyAll = nil
local context_forEachSub = nil
local context_getScheduler = nil
local context_setScheduler = nil
local context_setDynamics = nil
local context_getDebugger = nil
local context_setDebugger = nil
local context_setTabProfiler = nil
local context_setBreakPoint = nil
local context_deleteBreakPoint = nil

local context_deleteAllBreakPoints = nil
local context_runNormally = nil
local context_breakAtNextBreakPoint = nil
local context_breakAtNextSub = nil
local context_resumeSuspends = nil
local context_suspend = nil
local context_postpone = nil
local context_resume = nil
local context_hasSuspend = nil
local context_tabSuspend = nil
local context_hasInner = nil
local context_getInner = nil
local context_safeInner = nil

local context_meta_call = nil
local context_meta_len = nil
local context_meta_shr = nil

local context_meta_bor = nil
local context_meta_band = nil
local context_meta_concat = nil

local tabJoin = nil
local tabSelect = nil

local g_t_rebind = nil

local tabMachine_onUnCaughtException  = nil
local tabMachine_addContextException  = nil
local cocosTabMachine_prettyStr = nil
local tabMachine_throwError = nil

local co_sig_quit = {"co_signal_quit"}

__co_pools = {}
local __co_pools = __co_pools

local __co_traceback
local __co_error
local __co_on_error = function(err)
    __co_error = err
    __co_traceback = debug.traceback("", 2)
end

local __co_fun = function()
    while true do
        local f, c, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10 = co_yield()
        local stat = xpcall(f, __co_on_error, c, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10)
        local co = c.__co
        c.__co = nil
        if not stat then
            local err = __co_error
            __co_error = nil
            if err == co_sig_quit then
                c:stop()
            else
                c.__co_error = err
                tabMachine_throwError(c, err, __co_traceback)
            end
        else
            c:stop()
        end

        --co_checkin
        table_insert(__co_pools, co)
    end
end

local co_checkout = function ()
    local co = table_remove(__co_pools)
    if co ~= nil then
        return co
    else
        co = co_create(__co_fun)
        co_resume(co)
    end
    return co
end

local co_interupt = function(co)
    local status = co_status(co)
    if status == "running" then
        error(co_sig_quit)
    elseif status == "suspended" then
        co_resume(co, co_sig_quit)
    end
end

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

local function createContext(tab, ...)
    local c = table_remove(__contextPool)


    if c == nil then
        c = {}
        -- c.__lifeState = lifeState.running
        c.__lifeState = 10
    else
        -- c.__lifeState = lifeState.running
        c.__lifeState = 10

        -- c._isRecycled = false
    end

    local lifeId = __nextLifeId
    c.__lifeId = lifeId
    __nextLifeId = lifeId + 1

    if tab == nil then
        setmetatable(c, context)
    else
        if not tab.__hooked then
            local file, line = g_t.getTabCodeLocation(tab)
            printError("tab without precompilation is deprecated now ",
             " file: ", file, " ", line, "\n", debug.traceback())
            g_t.precompile(tab)
        end
        setmetatable(c, tab)
    end


    -- c.__enterCount = 0
    -- c.__childOpId = 0

    -- if g_t.stat then
        -- g_aliveContextCount = g_aliveContextCount + 1
        -- g_historyContextCount = g_historyContextCount + 1
    -- end

    return c
end


----------------- tabMachine -------------------------
local __curStackNum = 0
__nextSubCache = {}
local __nextSubCache = __nextSubCache

g_getCurStackNum = function()
    return __curStackNum
end

__commonLabelCache = {}
local __commonLabelCache = __commonLabelCache

__backwardCacheTable = {}
local __backwardCacheTable = __backwardCacheTable

__contextStack = {}
local __contextStack = __contextStack

function tabMachine:ctor()
    g_tm = self
    self.__isRunning = false
    self.__rootContext = nil
    self.__outputs = nil
    self.__tab = nil
    self.__curContext = nil
    self.__debugger = nil
    -- self.__contextStack = {}
    -- self.__curStackNum = 0
    -- self.__nextSubCache = {}
    -- self.__backwardCacheTable = {}
    self.__commonLabelCache = __commonLabelCache
end

function tabMachine:addNextSubCache(sub, num)
    __nextSubCache[sub] =  sub .. 1
    for i = 0, num - 1 do
        __nextSubCache[sub .. i] = sub .. (i+1)
    end
end

function tabMachine:addCommonLabels(sub, num)
    local name
    for i = -1, num do
        if i == -1 then
            name = sub
        else
            name = sub .. i
        end

        __commonLabelCache[name] = {
            update = name .. "_update",
            updateInterval = name .. "_updateInterval",
            event = name .. "_event",
            final = name .."_final",
            catch = name .."_catch",
        }
    end
end

tabMachine_compileTab  = function (tab)
    local targetTab = tab
    local nextSubCacheTable = nil
    local backwardCacheTable = nil
    while targetTab and not rawget(targetTab, "__isNextSubCached") do
        if backwardCacheTable == nil then
            backwardCacheTable = __backwardCacheTable
        end

        for tag, _ in pairs(targetTab) do
            if not backwardCacheTable[tag] then
                backwardCacheTable[tag] = true
                local l = str_len(tag)
                local splitPos = l

                local num = nil
                local power = 1
                for i = l, 1, -1 do
                    local code = str_byte(tag, i)
                    -- '0' = 48, '9' = 57
                    if code < 48 or code > 57  then
                        splitPos = i
                        break
                    else
                        if num == nil then
                            num = 0
                        end

                        num = num + (code - 48) * power 
                        power = power * 10
                    end
                end

                if num ~= nil then
                    local base = tag:sub(1, splitPos)
                    if base ~= nil then 
                        if nextSubCacheTable == nil then
                            nextSubCacheTable = __nextSubCache
                        end
                        nextSubCacheTable[base ..(num - 1)] = tag
                        if num == 1 then
                            nextSubCacheTable[base] = tag
                        end
                    end
                end
            end
        end

        rawset(targetTab, "__isNextSubCached", true)
        targetTab = targetTab.super 
    end

    local commonLabelCache = nil
    while tab ~= nil and not rawget(tab, "__isLabelCached") do
        rawset(tab, "__isLabelCached", true)

        if commonLabelCache == nil then
            commonLabelCache = __commonLabelCache
        end

        for tag, _ in pairs(tab) do

            local l = str_len(tag)
            local splitPos = 1
            for _, labelLen in ipairs(tabMachine.labelLens) do
                splitPos = l - labelLen
                if splitPos <= 1 then
                    break
                end

                -- '_' == 95
                if str_byte(tag, splitPos) == 95 then
                    break
                end

                --make sure splitPos is also correct for last iteration 
                splitPos = 0
            end

            if splitPos > 1 then
                local base = tag:sub(1, splitPos - 1)
                local label = tag:sub(splitPos + 1, -1)
                if tabMachine.labels[label] ~= nil then
                    local baseCache = commonLabelCache[base]
                    if baseCache == nil then
                        baseCache = {}
                        commonLabelCache[base] = baseCache
                    end
                    baseCache[label] = tag
                end
            end
        end

        tab = tab.super
    end
end


function tabMachine:installTab(tab)
    local subContext = createContext(tab)

    assert(subContext ~= nil)
    -- subContext.tm = self
    subContext.p = nil

    subContext.__name = "root"
    -- subContext.__isRoot = true

    self.__rootContext = subContext
    self.__tab = tab
    context_installTab(self.__rootContext, tab)
end

function tabMachine:setDebugger(debugger)
    __anyDebuggerEanbled = true
    self.__debugger = debugger
end

function tabMachine:getDebugger()
    return self.__debugger
end

function tabMachine:getScheduler()
    return self.__scheduler
end

function tabMachine:setScheduler(scheduler)
    self.__scheduler = scheduler
    if self.__rootContext then
        self.__rootContext:setScheduler(scheduler)
    end
end

function tabMachine:start(...)
    local debugger = __anyDebuggerEanbled and self.__debugger or nil 
    if debugger then
        debugger:onMachineStart(self)
    end
    if self.__tab == nil then
        return
    end

    self.__isRunning = true

    --enter
    local context = self.__rootContext
    if debugger then
        context.__debugger = debugger
    end
    context.__scheduler = self.__scheduler
    self.__rootContext:start("s1", ...)
end

function tabMachine:stop()
    if self.__rootContext then
        context_stop(self.__rootContext)
    end
    -- callback _onStopped is expected to be called
    -- then the variables would be proerly set
end

function tabMachine:isRunning()
    return self.__isRunning
end

function tabMachine:getOutputs()
    if self.__outputs then
        return table_unpack(self.__outputs)
    end

    return nil
end

function tabMachine:_setOutputs(outputValues)
    self.__outValues = outputValues
end

function tabMachine:_onStopped()
    self.__isRunning = false
    self.__rootContext = nil
end

tabMachine.compileTab = tabMachine_compileTab

--inline optimization
-- function tabMachine:_createContext(...)
-- local context = table_remove(__contextPool)
-- if context ~= nil then
-- return context
-- end
-- return context.new(...)
-- end


tabMachine_throwError = function (target, errorMsg, traceback)
    local e = {}
    e.errorMsg = errorMsg
    e.luaStackTrace = traceback
    e.isCustom = nil

    local catched = false

    if __curStackNum > 0 then
        local i = __curStackNum
        local contextStack = __contextStack
        while i > 0 do
            local context = contextStack[i].context

            if context == nil then
                break
            end

            if not context_throwException(context, e) then
                if e.errorTabStatcks == nil then
                    e.errorTabStatcks = {}
                end

                table_insert(e.errorTabStatcks, context:getDetailedPath())
            else
                catched = true
            end

            i = i - 1
            local lastContext = context

            while i > 0 do
                local context = contextStack[i].context

                if context == nil then
                    break
                end

                if context == lastContext.p or context == lastContext then
                    lastContext = context
                    i = i - 1
                else
                    break
                end
            end
        end
    else
        if not context_throwException(target, e) then
            if e.errorTabStatcks == nil then
                e.errorTabStatcks = {}
            end

            table_insert(e.errorTabStatcks, target:getDetailedPath())
        else
            catched = true
        end
    end

    if not catched then
        tabMachine_onUnCaughtException(e)
    end
end

tabMachine_onUnCaughtException = function(e)
    dump(e, "uncaught exception", 100, printError)

    --上报
    local eMsg = ""
    local errorMsg = e.errorMsg or "no errorMsg"
    -- local reportVals = self:getObject("report") and self:getObject("report"):getTreeMsg() or "no reportVals"
    local reportVals = "no report"
    local errorTabStatcks = e.errorTabStatcks and cocosTabMachine_prettyStr(e.errorTabStatcks or {}) or "no errorTabStatcks"
    local luaStackTrace = e.luaStackTrace or "no luaStackTrace"

    local strTop = "==== errorMsg ====\n"
    eMsg = eMsg .. strTop .. errorMsg
    strTop = "\n\n==== reportVals ====\n"
    eMsg = eMsg .. strTop .. reportVals
    strTop = "\n\n==== errorTabStatcks ====\n"
    eMsg = eMsg .. strTop .. errorTabStatcks
    strTop = "\n\n==== luaStackTrace ====\n"
    eMsg = eMsg .. strTop .. luaStackTrace
    if fabric then
        fabric:getInstance():allSet(tostring(errorMsg), eMsg, errorTabStatcks)
    end

    if g_enableDumpTabSnapshotOnCaughtException then
        if tabSnapshotLogger then
            tabSnapshotLogger:getInstance():dumpTabSnapshot(tostring(errorMsg), eMsg, errorTabStatcks)
        end
    end
end

cocosTabMachine_prettyStr = function (arr)
    local str = ""
    for _,v in ipairs(arr or {}) do
        str = str .. v .. "\n"
    end
    return str
end

local __perror
local __traceback
local function on_error(error)
    __perror = error
    __traceback = debug.traceback("", 2)
end

tabMachine_pcall = function (target, f, selfParam, ...)
    local curContextInfo
    local curStackNum = __curStackNum + 1
    __curStackNum = curStackNum

    local contextStack = __contextStack
    if #contextStack < curStackNum then
        curContextInfo = {}
        curContextInfo.context = target
        table_insert(contextStack, curContextInfo)
    else
        curContextInfo = contextStack[curStackNum]
        curContextInfo.context = target
    end

    local stat, result = xpcall(f, on_error, selfParam, ...)

    if stat then
        __curStackNum = curStackNum -1
        curContextInfo.context = nil
        return result
    else
        if __perror == co_sig_quit then
            error(co_sig_quit)
            return
        end
        tabMachine_throwError(target, __perror, __traceback)
        __curStackNum = curStackNum -1
        curContextInfo.context = nil
    end
    --inline optimization
    -- return nil
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

local runMode = {
    breakAtNextBreakPoint = 1,
    breakAtNextSub = 2,
}

local context_name_stack = {}
local path_concat_table = {}

local function table_array_clear(t)
    local n = #t
    for i = 1, n do
        t[i] = nil
    end
end

local pathInversionTreeCache = {}

local function findPathInInversionTree(ctx)
    local node = pathInversionTreeCache

    local c = ctx
    while c do
        local childNode = node[c.__name]
        if not childNode then
            return nil
        end

        node = childNode

        c = c.p
    end

    assert(type(node.__PATH__) == "string")

    return node.__PATH__
end

local function RegisterToInversionTree(ctx, path)
    local node = pathInversionTreeCache

    local c = ctx
    while c do
        local name = c.__name
        local childNode = node[c.__name]
        if not childNode then
            childNode = {}
            node[name] = childNode
        end

        node = childNode

        c = c.p
    end

    node.__PATH__ = path

    node = path
end

local function generateContextPath(ctx)
    table_array_clear(context_name_stack)

    local index = 1
    local c = ctx
    while c do
        context_name_stack[index] = c.__name
        index = index + 1

        c = c.p
    end

    table_array_clear(path_concat_table)

    index = 1
    for i = #context_name_stack, 1, -1 do
        if index > 1 then
            path_concat_table[index] = "."
            path_concat_table[index + 1] = context_name_stack[i]
            index = index + 2
        else
            path_concat_table[index] = context_name_stack[i]
            index = index + 1
        end
    end

    return table_concat(path_concat_table)
end

function context:_getPath()
    local path = self.__path
    if path then
        return path
    end

    local path = findPathInInversionTree(self)
    if not path then
        path = generateContextPath(self)
    end

    self.__path = path 

    RegisterToInversionTree(self, path)

    return path
end

context.getPath = context._getPath

context_getLifeId = function(self)
    return self.__lifeId
end

context_getSub = function (self, scName)
    local subContexts = self.__subContexts
    if subContexts == nil then
        return
    end

    for i = #subContexts, 1, -1 do
        local subContext = subContexts[i]
        if subContext.__name == scName then
            return subContext
        end
    end

    return nil
end

context_getSubByLifeId = function (self, lifeId)
    local subContexts = self.__subContexts
    if subContexts == nil then
        return
    end

    for i = #subContexts, 1, -1 do
        local subContext = subContexts[i]
        if subContext.__lifeId == lifeId then
            return subContext
        end
    end

    return nil
end

context_getContextByLifeId = function (self, lifeId)
    local contextArray = table_remove(__arrayPool)
    if contextArray == nil then
        contextArray = {}  
    end

    table_insert(contextArray, self)
    local index = 1
    local target = nil 
    while index <= #contextArray do
        target = contextArray[index]
        if target.__lifeId == lifeId then
            break
        end

        local subContexts = target.__subContexts
        if subContexts ~= nil then
            for i = #subContexts, 1, -1 do
                local subContext = subContexts[i]
                table_insert(contextArray, subContext)
            end
        end

        target = nil
        index = index + 1
    end

    while next(contextArray) do
        table_remove(contextArray)
    end
    table_insert(__arrayPool, contextArray)

    return target
end

context_hasAnySub = function (self)
    local subContexts = self.__subContexts
    return subContexts ~= nil and next(subContexts)
end

context_start = function (self, scName, ...)
    -- if self.__lifeState >= lifeState.quitting then
    if self.__lifeState >= 20 then
        return
    end

    local selfTab = self.__tab
    if selfTab  == nil then
        return
    end

    if self.__runMode ~= nil and context_needToBreak(self, scName)  then
        local params = table_pack(...)
        local function resumeFun (resume, ...)
            local resumeParamsNum = select("#", ...)
            if resumeParamsNum <= 0 then
                context_start(self, scName, table_unpack(params))
            else
                if params.n == 0 then
                    context_start(self, scName, ...)
                else
                    context_start(self, scName, ...)
                    printError("invald pramas for resume")
                end
            end
        end

        context_addSuspend(self, resumeFun, scName)
        return
    end

    -- self.__pc = self
    -- self.__pcName = "self"
    -- self.__pcAction = scName

    --inline optimization
    -- self:_addEnterCount()

    local sub = selfTab[scName]
    if sub == nil then
        return
    end

    local enterCount = self.__enterCount
    if enterCount then
        self.__enterCount = enterCount + 1
    end

    local debugger = __anyDebuggerEanbled and self.__debugger or nil
    if debugger then
        debugger:onContextStart(self, scName)
    end

    local subUpdateFunEx 
    local subUpdateIntevalEx
    local subUpdateTimerMgrEx
    local eventEx
    local subFinalFunEx
    local subCatchFunEx

    -- local tm = self.tm
    local commonLabels = __commonLabelCache[scName]
    if commonLabels then
        subUpdateFunEx = selfTab[commonLabels.update]
        eventEx = selfTab[commonLabels.event]
        subFinalFunEx = selfTab[commonLabels.final]
        subCatchFunEx = selfTab[commonLabels.catch]
    end

    if subUpdateFunEx == nil and
        eventEx == nil then
        if subCatchFunEx == nil then
            self.__curSubCatchFun = subCatchFunEx
            -- local tabProfiler = self.__tabProfiler
            -- if tabProfiler then
                -- tabProfiler:beginSampleTime(self:_getPath().."."..scName)
            -- end

            tabMachine_pcall(self, sub, self, ...)

            -- if tabProfiler  then
                -- tabProfiler:endSampleTime()
            -- end

            -- if self.__lifeState < lifeState.quitting then
            if self.__lifeState < 20 then
                --inline
                -- context_checkNext(self, scName)
                local nextSub = __nextSubCache[scName]
                if nextSub ~= nil then
                    context_start(self, nextSub)
                end
            end

            if subFinalFunEx ~= nil then
                tabMachine_pcall(self, subFinalFunEx, self, ...)
            end
        else
            if subCatchFunEx ~= nil then
                self.__curSubCatchFun = subCatchFunEx
            end
            tabMachine_pcall(self, sub, self, ...)
            self.__curSubCatchFun = nil

            -- if self.__lifeState < lifeState.quitting then
            if self.__lifeState < 20 then
                -- context_checkNext(self, scName)
                local nextSub = __nextSubCache[scName]
                if nextSub ~= nil then
                    context_start(self, nextSub)
                end
            end

            if subFinalFunEx ~= nil then
                tabMachine_pcall(self, subFinalFunEx, self, ...)
            end
        end
    else
        --inline optimization
        local subContext = createContext()
        -- local subContext = context.new()
        -- subContext.tm = tm
        subContext.p = self
        subContext.__name = scName

        local subEnterCount = 0
        if subUpdateFunEx ~= nil then
            subContext.__updateFunEx = subUpdateFunEx
            subEnterCount = nil

            local dynamics = self.__dynamics 
            if dynamics ~= nil then
                local dynamicLabels = dynamics[scName]
                if dynamicLabels ~= nil then
                    subUpdateIntevalEx = dynamicLabels.updateInterval
                end
            end

            if subUpdateIntevalEx == nil then
                subUpdateIntevalEx = selfTab[commonLabels.updateInterval]
            end

            if subUpdateIntevalEx ~= nil then
                subContext.__updateIntervalEx = subUpdateIntevalEx
            end

            subUpdateTimerMgrEx = selfTab[commonLabels.updateTimerMgr]

            if subUpdateTimerMgrEx ~= nil then 
                subContext.__updateTimerMgrEx = subUpdateTimerMgrEx
            end
        end

        if eventEx ~= nil then
            subContext.__eventEx = eventEx
        end
        if subFinalFunEx ~= nil then
            subContext.__finalFunEx = subFinalFunEx
        end
        if subCatchFunEx ~= nil then
            subContext.__catchFunEx = subCatchFunEx
        end

        context_addSubContext(self, subContext)

        --inline optimization
        -- subContext:_addEnterCount()
        if subEnterCount then
            subContext.__enterCount = 1
        end

        --inline code for prepapre enter
        if debugger ~= nil then
            subContext.__debugger = debugger
        end

        local scheduler = self.__scheduler
        subContext.__scheduler = scheduler

        --inline optimization
        -- self:_createTickAndUpdateTimers()
        if subUpdateFunEx ~= nil then
            local timer = scheduler:createTimer(subContext, context_update, subUpdateIntevalEx, subUpdateTimerMgrEx)
            subContext.__updateTimer = timer 
        end

        if self.__mapHeadListener then
            context_notifyLifeTimeEvent(self, tabMachine.event_context_enter, scName, subContext)
        end

        if subCatchFunEx ~= nil then
            self.__curSubCatchFun = subCatchFunEx
        end

        tabMachine_pcall(self, sub, self, ...)
        if subCatchFunEx ~= nil then
            self.__curSubCatchFun = nil
        end
    end

    --inline optimization
    -- self:_decEnterCount()
    if enterCount then
        enterCount = self.__enterCount - 1
        if enterCount <= 0 then
            local subContexts = self.__subContexts
            if (subContexts == nil or next(subContexts) == nil) and self.__updateFun == nil
                and self.__event == nil 
                and self.__suspends == nil then
                context_stopSelf(self)
                return
            end
        end
        self.__enterCount = enterCount
    end
end

context_call = function (self, tab, scName, outputVars, ...)
    if scName == nil then
        assert(false)
    end

    --assert can only be done before illegal context state is restored
    local bindFrameIndex = nil

    if tab then
        bindFrameIndex = tab.__bindFrameIndex
        if bindFrameIndex then
            assert(bindFrameIndex == g_frameIndex, "bindFrameIndex = " ..
            bindFrameIndex .. " g_frameIndex = " .. g_frameIndex)
            -- assert(__bindTabPool[tab] == nil)
        end
    else
        tab = g_t.empty_tab
    end

    local debugger = __anyDebuggerEanbled and self.__debugger or nil
    if debugger then
        debugger:onTabCall(self, scName, tab)
    end

    -- if self.__lifeState >= lifeState.quitting then
    if self.__lifeState >= 20 then
        return
    end

    if self.__runMode ~= nil and context_needToBreak(self, scName)  then
        local args = table_pack(...)
        local resumeFun = function(resume, ...)
            local resumeParamsNum = select("#", ...)
            if resumeParamsNum <= 0 then
                context_call(self, tab, scName, outputVars, table_unpack(args))
            else
                if args.n == 0 then
                    context_call(self, tab, scName, outputVars, ...)
                else
                    context_call(self, tab, scName, outputVars, ...)
                    printError("invald pramas for resume")
                end
            end
        end
        context_addSuspend(self, resumeFun, scName)
        return
    end


    -- self.__pc = self
    -- self.__pcName = scName
    -- self.__pcAction = "call"

    --inline optimization
    -- self:_addEnterCount()
    -- self.__enterCount = self.__enterCount + 1
    -- if tab == nil then
        -- context_checkNext(self, scName)
        -- local nextSub = __nextSubCache[scName]
        -- if nextSub ~= nil then
            -- context_start(self, nextSub)
        -- end

        --inline optimization
        -- self:_decEnterCount()
        -- local enterCount = self.__enterCount
        -- enterCount = enterCount - 1
        -- self.__enterCount =enterCount
        -- if enterCount <= 0 then
            -- local subContexts = self.__subContexts
            -- if (subContexts == nil or next(subContexts) == nil) and self.__updateFun == nil
                -- and self.__event == nil
                -- and self.__suspends == nil then
                -- context_stopSelf(self)
            -- end
        -- end
        -- return
    -- end

    local wrappedTab = tab.__wrappedTab 
    local wrappedParams = nil
    if wrappedTab ~= nil then
        wrappedParams = tab.__wrappedParams
    end
    --inline optimization
    -- local subContext = nil
    -- if (wrappedParams ~= nil) then
    --     subContext = createContext(tab, table.unpack(wrappedParams))
    -- else
    --     subContext = createContext(tab, ...)
    -- end
    -- local tm = self.tm
    local subContext = nil

    if wrappedTab == nil then
        subContext = createContext(tab, ...)
    else
        subContext = createContext(wrappedTab, table_unpack(wrappedParams))
    end

    -- subContext.tm = tm
    subContext.p = self
    subContext.__name = scName

    local tabToInstall = wrappedTab or tab
    -- tabinstall optimization
    -- context_installTab(subContext, tabToInstall)
    local subEnterCount = 0
    local needTimer = false
    

    if tabToInstall ~= nil then 
        subContext.__tab = tabToInstall

        local iquitFun = tabToInstall.iquit
        if iquitFun ~= nil then
            subContext.__quitFun = iquitFun
        end

        local finalFun = tabToInstall.final
        if finalFun ~= nil then
            subContext.__finalFun = finalFun
        end

        local event = tabToInstall.event
        if event ~= nil then
            subContext.__event = event
            subEnterCount = nil
        end

        local catchFun = tabToInstall.catch
        if catchFun ~= nil then
            subContext.__catchFun = catchFun
        end

        local updateFun = tabToInstall.update
        if updateFun ~= nil then
            subContext.__updateFun = updateFun
            subEnterCount = nil
            needTimer = true
        end

        local updateInterval = tabToInstall.updateInterval
        if updateInterval ~= nil then
            subContext.__updateInterval = updateInterval
        end

        local updateTimerMgr = tabToInstall.updateTimerMgr
        if updateTimerMgr ~= nil then
            subContext.__updateTimerMgr = updateTimerMgr
        end

        local co = tabToInstall.co
        if co ~= nil then
            subContext.__coFun = co
            subEnterCount = nil
        end


        local labelCache = rawget(tabToInstall, "__isLabelCached")
        if not labelCache then
            tabMachine_compileTab(tabToInstall)
        end

    end
    --end of installTab optimization

    local selfTab = self.__tab
    if selfTab then
        local commonLabels = __commonLabelCache[scName]
        if commonLabels then
            local __updateFunEx = selfTab[commonLabels.update]
            if __updateFunEx ~= nil then
                subContext.__updateFunEx = __updateFunEx
                needTimer = true
                local __updateIntervalEx = selfTab[commonLabels.updateInterval]
                if __updateIntervalEx ~= nil then
                    subContext.__updateIntervalEx = __updateIntervalEx
                end

                local __updateTimerMgrEx = selfTab[commonLabels.updateTimerMgr]
                if __updateTimerMgrEx ~= nil then
                    subContext.__updateTimerMgrEx = __updateTimerMgrEx
                end
            end

            local __eventEx = selfTab[commonLabels.event]
            if __eventEx ~= nil then
                subContext.__eventEx = __eventEx
                -- subEnterCount = nil
            end
            local __quitFunEx = selfTab[commonLabels.iquit]
            if __quitFunEx ~= nil then
                subContext.__quitFunEx = __quitFunEx
            end
            local __finalFunEx = selfTab[commonLabels.final]
            if __finalFunEx ~= nil then
                subContext.__finalFunEx = __finalFunEx
            end
            local __catchFunEx = selfTab[commonLabels.catch]
            if __catchFunEx ~= nil then
                subContext.__catchFunEx = __catchFunEx
            end
        end
    end

    if subEnterCount then
        subContext.__enterCount = 0 
    end

    if wrappedTab == nil then
        if outputVars ~= nil then
            subContext.__outputVars = outputVars
        end
    else
        subContext.__outputVars = tab.__outputVars or outputVars
    end

    if outputVars then
        subContext.__banRecycleOutputVars = true
    end

    --inline optimization
    -- context_addSubContext(self, subContext)
    -- if self.__isQuitting then
        -- return
    -- end
    local subContexts = self.__subContexts
    if subContexts == nil then
        subContexts = table_remove(__subContainerPool)
        if subContexts == nil then
            subContexts  = {}
        end
        self.__subContexts = subContexts
    end

    table_insert(subContexts, subContext)
    -- self.__childOpId = self.__childOpId + 1

    if debugger ~= nil then
        subContext.__debugger = debugger
    end

    local scheduler = self.__scheduler
    subContext.__scheduler = scheduler


    --inline optimization
    if needTimer then
        local timer = scheduler:createTimer(subContext, context_update,
        subContext.__updateIntervalEx or subContext.__updateInterval, subContext.__updateTimerMgrEx or subContext.__updateTimerMgr)
        subContext.__updateTimer = timer 
    end

    if self.__mapHeadListener then
        context_notifyLifeTimeEvent(self, tabMachine.event_context_enter, scName, subContext)
    end

    if wrappedTab == nil then
        context_start(subContext, "s1", ...)
    else
        --recycle bindTab
        if bindFrameIndex then
            tab.__wrappedTab = nil
            tab.__outputVars = nil
            tab.__bindFrameIndex = 0
        else
            tab.__outputVars = nil
        end

        context_start(subContext, "s1", table_unpack(wrappedParams))

        if bindFrameIndex then
            for i = wrappedParams.__numParams, 1, -1 do
                wrappedParams[i] = nil
            end
            __bindTabPool[tab] = tab
        end
    end

    if not subContext.__isStopped and subContext.__coFun ~= nil then
        local co = co_checkout()
        subContext.__co = co
        if wrappedTab == nil then
            co_resume(co, subContext.__coFun, subContext, ...)
        else
            co_resume(co, subContext.__coFun, subContext, table_unpack(wrappedParams))
        end
    end


    --inline optimization
    -- self:_decEnterCount()
    -- local enterCount = self.__enterCount
    -- enterCount = enterCount - 1
    -- self.__enterCount =enterCount
    -- if enterCount <= 0 then
        -- local subContexts = self.__subContexts
        -- if (subContexts == nil or next(subContexts) == nil) and self.__updateFun == nil
            -- and self.__event == nil
            -- and self.__suspends == nil then
            -- context_stopSelf(self)
        -- end
    -- end
    --
    --inline optimization
    -- if not subContext:isStopped() then 
    -- if subContext.__lifeState < lifeState.quitting then
    -- if subContext.__lifeState < 20 then
        -- return subContext
    -- end

    --no longer return nil when subContext is stopped
    return subContext
end

context_co_call = function (self, tab,  ...)
    local co = self.__co
    assert(co ~= nil and co_running() == co)
    local sc = context_call(self, tab, "__co", nil, ...) 
    -- if sc.__lifeState >= lifeState.stopped then
    if sc.__lifeState >= 40  then
        -- self.__lifeState >= lifeState.quitting
        if self.__lifeState >= 20  then
            error(co_sig_quit)
            return
        else
            local outputs = sc.__outputValues
            if outputs ~= nil then
                return table_unpack(outputs)
            else
                return nil
            end
        end
    end

    local ret = co_yield()
    if ret == co_sig_quit then
        error(co_sig_quit)
    end

    -- self.__lifeState >= lifeState.quitting
    if self.__lifeState >= 20  then
        error(co_sig_quit)
        return
    else
        local outputs = sc.__outputValues
        if outputs ~= nil then
            return table_unpack(outputs)

        end
    end
end


context_throw = function (self, e)
    local exception = {}
    exception.isCustom = true
    exception.e = e

    local c = self
    -- local pc = c.__pc
    local pc = c
    if pc ~= nil and 
        pc ~= self and
        pc.p ==  self then
        c = pc
    end

    context_throwException(c, exception)
end

context_join = function (self, scNames, scName, callback, joinFuture)
    return context_call(self, tabJoin, scName, nil, self, scNames, callback, joinFuture)
end

context_co_join = function(self, ...)
    return context_co_call(self, tabJoin, self, ...)
end

context_select = function(self, scNames, scName, outputVars, selectFuture)
    return context_call(self, tabSelect, scName, outputVars, self, scNames, selectFuture)
end

context_co_select = function(self, ...)
    return context_co_call(self, tabSelect, self, ...)
end

context_registerLifeTimeListener = function (self, name, listenningContext)
    -- stopped contexts are not allowed to listen or be listenned
    -- if self.__lifeState >= lifeState.quitting or listenningContext.__lifeState >= lifeState.quitting then
    if self.__lifeState >= 20 or listenningContext.__lifeState >= 20 then
        return
    end

    local oldHeadListenInfo = listenningContext.__headListenInfo
    local oldListenInfo = oldHeadListenInfo
    while oldListenInfo ~= nil do
        if oldListenInfo.target == self and oldListenInfo.name == name then
            --duplicate listenning is not allowed
            return
        end
        oldListenInfo = oldListenInfo.nextInfo
    end

    local listenInfo = {target = self, name = name}
    if oldHeadListenInfo ~= nil then
        oldHeadListenInfo.preInfo = listenInfo
        listenInfo.nextInfo = oldHeadListenInfo
    end
    listenningContext.__headListenInfo = listenInfo

    local mapHeadListener = self.__mapHeadListener
    if mapHeadListener == nil then
        mapHeadListener = {}
        self.__mapHeadListener = mapHeadListener
    end

    local listenter = {context = listenningContext}
    local oldHeadListener = mapHeadListener[name]
    if oldHeadListener then
        oldHeadListener.preListener = listenter
        listenter.nextListener = oldHeadListener
    end
    mapHeadListener[name] = listenter
end

context_unregisterLifeTimeListener = function (self, name, listenningContext)
    local mapHeadListener = self.__mapHeadListener
    if mapHeadListener == nil then
        return
    end

    local listenInfo = listenningContext.__headListenInfo
    while listenInfo ~= nil do
        if listenInfo.name == name and listenInfo.target == self then
            if listenInfo.preInfo ~= nil then
                listenInfo.preInfo.nextInfo = listenInfo.nextInfo
            end

            if listenInfo.nextInfo ~= nil then
                listenInfo.nextInfo.preInfo = listenInfo.preInfo
            end

            if listenningContext.__headListenInfo == listenInfo then
                listenningContext.__headListenInfo = listenInfo.nextInfo
            end

            break
        end

        listenInfo = listenInfo.nextInfo
    end

    local headListener = mapHeadListener[name]
    local listenter = headListener   

    while listenter ~= nil do
        if listenter.context == listenningContext then
            listenter.detached = true

            if listenter.preListener ~= nil then
                listenter.preListener.nextListener = listenter.nextListener
            end

            if listenter.nextListener ~= nil then
                listenter.nextListener.preListener = listenter.preListener
            end

            if headListener == listenter then
                headListener = listenter.nextListener
                mapHeadListener[name] = headListener
            end
            break
        end
        listenter = listenter.nextListener
    end

end

context_hasSub = function (self, scName)
    local subContexts = self.__subContexts
    if subContexts == nil then
        return false
    end

    for i = #subContexts, 1, -1 do
        local subContext = subContexts[i]
        if subContext.__name == scName then
            return true
        end
    end

    return false
end

context_output = function (self, ...)
    self.__outputValues = {...}
    local proxyInfo = self.__headProxyInfo

    while proxyInfo ~= nil do
        context_output(proxyInfo.proxy, ...)
        proxyInfo = proxyInfo.nextInfo
    end
end

context_getOutputs = function (self)
    return self.__outputValues
end

context_abort = function (self, scName)
    local sc
    if scName ~= nil then
        sc = context_getSub(self, scName)
    else
        sc = self
    end

    if sc ~= nil then
        sc.__name = "__abort" .. sc.__name
        --inline optimization
        -- sc:stop()
        context_stopSelf(sc)
    end
end

context_stop = function (self, scName)
    -- if self.__lifeState >= lifeState.stopped then
    if self.__lifeState >= 40 then
        return
    end

    if scName == nil then
        context_stopSelf(self)
    else
        context_stopSub(self, scName)
    end
end

context_stopAllSubs = function (self, scName)
    -- if self.__lifeState >= lifeState.stopped then
    if self.__lifeState >= 40 then
        return
    end

    local subContexts = self.__subContexts
    if subContexts == nil then
        return
    end

    local contextArray = table_remove(__arrayPool)
    if contextArray == nil then
        contextArray = {}  
    end

    for index = #subContexts, 1, -1 do
        local subContext = subContexts[index]
        table_insert(contextArray, subContext)
    end

    for _, subContext in ipairs(contextArray) do
        -- if subContext.p == self and subContext.__name == scName and not subContext.__lifeState >= lifeState.quitted then
        if subContext.p == self and (scName == nil or subContext.__name == scName) and subContext.__lifeState < 30 then
            context_stopSelf(subContext)
        end
    end

    while next(contextArray) do
        table_remove(contextArray)
    end

    table_insert(__arrayPool, contextArray)
end

context_getDetailedPath = function (self)
    local c = self
    local name = nil
    while c do
        local partName = c.__name
        if partName == nil then
            local s = debug.traceback("", 1)
            printError("encouter recycled node:", name, " ", s)
            partName = "@recycled@"
        end

        if c.tabName and c.tabName ~= "context" then
            partName = partName .. "(" .. c.tabName .. ")"
        end

        if c._nickName then
            partName = partName .. "[" .. c._nickName .. "]"
        end

        if name == nil then
            name = partName
        else
            name = partName .. "." .. name
        end

        c = c.p
    end

    return name
end

context_isStopped = function (self)
    -- return self.__lifeState >= lifeState.stopped
    return self.__lifeState >= 40
end

context_isQuitted = function(self)
    -- return self.__lifeState >= lifeState.quitted
    return self.__lifeState >= 30 
end

context_isQuitting = function(self)
    -- return self.__lifeState >= lifeState.quitting
    return self.__lifeState >= 20 
end

context_addSubContext = function (self, subContext)
    -- if self.__lifeState > lifeState.quitting then
    if self.__lifeState >= 20 then
        return
    end

    local subContexts = self.__subContexts
    if subContexts == nil then
        subContexts = table_remove(__subContainerPool)
        if subContexts == nil then
            subContexts  = {}
        end
        self.__subContexts = subContexts
    end
    table_insert(subContexts, subContext)
    -- self.__childOpId = self.__childOpId + 1
end


context_removeSubContext = function (self, subContext)
    -- if subContext.p ~= self then
        -- return
    -- end

    -- subContext.p = nil

    local subContexts = self.__subContexts
    if subContexts == nil then
        return
    end

    for i = #subContexts, 1, -1 do 
        if subContexts[i] == subContext then
            table_remove(subContexts, i)
            -- self.__childOpId = self.__childOpId + 1
            return
        end
    end
end

--check stop before call this method
context_checkNext = function (self, scName)
    --print("start next ", self:_getPath().. "." ..scName)

    -- local tm = self.tm
    local nextSub = nextSubCache[scName]
    if nextSub ~= nil then
        return context_start(self, nextSub)
    end

    -- local tab = self.__tab
    -- local backwardTable
    -- if tab and tab.__backwardNextSubTable then
    -- backwardTable = tab.__backwardNextSubTable
    -- else
    -- backwardTable = self.__backwardNextSubTable
    -- end
    -- if backwardTable ~= nil then
    -- nextSub = backwardTable[scName]
    -- if nextSub ~= nil then
    -- return self:start(nextSub)
    -- end
    -- end
end

-- _checkStop is expanded
-- function context:_checkStop()
-- print("checkStop ", self:_getPath(), self.__isEntering,
-- " ", self.__headSubContext, " ",
-- self.__updateFun, " ", self.__tickFun, " ", self.__event, " ")
--
-- if self.__isStopped then
-- return
-- end
--
-- if self.__headSubContext == nil
-- and self.__updateFun == nil
-- and self.__event == nil
-- and self.__enterCount <= 0 then
-- self:_stopSelf()
-- end
-- end

context_update = function(self, dt)
    -- inner update first
    -- if self.__lifeState >= lifeState.quitting then
    -- if self.__lifeState >= 20 then
        -- return
    -- end

    -- self.__pc = self
    -- self.__pcName = "self"
    -- self.__pcAction = "update"

    --inline optimization
    -- self:_addEnterCount()

    -- local tm = nil
    local updateFun = self.__updateFun
    if updateFun then 
        --inline optimization
        -- if self.__isFastMode then
        --     self.__updateFun(self, dt)
        -- else
        -- local tabProfiler = self.__tabProfiler
        -- if  tabProfiler then
            -- tabProfiler:beginSampleUpdateTime(self:_getPath())
        -- end

        -- if tm == nil then
            -- tm = self.tm
        -- end
        tabMachine_pcall(self, updateFun, self, dt)

        -- if tabProfiler then
            -- tabProfiler:endSampleUpdateTime(self:_getPath())
        -- end
    end

    local updateFunEx = self.__updateFunEx
    if updateFunEx then
        -- local p = self.p
        --inline optimization
        -- if self.__isFastMode then
        --     self.__updateFunEx(self.p, dt)
        -- else
        --     self.tm:_pcall(self, self.__updateFunEx, self.p, dt)
        -- end
        -- if p then
            -- local tabProfiler = self.__tabProfiler
            -- if  tabProfiler then
                -- tabProfiler:beginSampleUpdateTime(self:_getPath())
            -- end

            -- if tm == nil then
                -- tm = self.tm
            -- end

            tabMachine_pcall(self, updateFunEx, self.p, dt)

            -- if tabProfiler then
                -- tabProfiler:endSampleUpdateTime(self:_getPath())
            -- end
        -- end
    end
    --inline optimization
    -- self:_decEnterCount()
    --
end

context_downDistance = function(self, dst)
    local dstDistance = -1

    local contextArray = table_remove(__arrayPool)
    if contextArray == nil then
        contextArray = {}
    end

    local distanceArray = table_remove(__arrayPool)
    if distanceArray == nil then
        distanceArray = {}
    end

    table_insert(contextArray, self)
    table_insert(distanceArray, 0)

    local index = 1
    while index <= #contextArray do
        local target = contextArray[index]
        local distance = distanceArray[index]

        if target == dst then
            dstDistance = distance
            break
        end

        local subContexts = target.__subContexts
        if subContexts ~= nil then
            for _, sub in ipairs(subContexts) do
                table_insert(contextArray, sub)
                table_insert(distanceArray, distance + 1)
            end
        end

        index = index + 1
    end

    while next(contextArray) do
        table_remove(contextArray)
    end
    table_insert(__arrayPool, contextArray)

    while next(distanceArray) do
        table_remove(distanceArray)
    end
    table_insert(__arrayPool, distanceArray)

    return dstDistance
end

context_upDistance = function(self, dst)
    local dstDistance = -1

    local contextArray = table_remove(__arrayPool)
    if contextArray == nil then
        contextArray = {}
    end

    local distanceArray = table_remove(__arrayPool)
    if distanceArray == nil then
        distanceArray = {}
    end

    local visitMap = table_remove(__mapPool)
    if visitMap == nil then
        visitMap = {}
    end

    table_insert(contextArray, self)
    table_insert(distanceArray, 0)

    local index = 1
    while index <= #contextArray do
        local target = contextArray[index]
        local distance = distanceArray[index]

        if target == dst then
            dstDistance = distance
            break
        end

        local proxyInfo = target.__headProxyInfo
        while proxyInfo ~= nil do
            if not proxyInfo.detached then
                local proxy = proxyInfo.proxy
                if not visitMap[proxy] and
                    -- proxy.__lifeState < lifeState.quitting then
                    proxy.__lifeState < 20 then
                    table_insert(contextArray, proxy)
                    table_insert(distanceArray, distance + 1)
                    visitMap[proxy] = true
                end
            end
            proxyInfo = proxyInfo.nextInfo
        end

        local p = target.p
        if p and not visitMap[p] then
            -- if self is not quitting then self.p isn't quitting too.
            -- and  not p.__isQuitting then
            table_insert(contextArray, p)
            table_insert(distanceArray, distance + 1)
            visitMap[p] = true
        end

        index = index + 1
    end

    for key, _ in pairs(visitMap) do
        visitMap[key] = nil
    end
    table_insert(__mapPool, visitMap)

    while next(contextArray) do
        table_remove(contextArray)
    end
    table_insert(__arrayPool, contextArray)

    while next(distanceArray) do
        table_remove(distanceArray)
    end
    table_insert(__arrayPool, distanceArray)

    return dstDistance
end

context_notify = function (self, p1, p2, ...)
    -- if self.__lifeState >= lifeState.quitting then
    if self.__lifeState >= 20 then
        return
    end

    if p1 == nil then
        return
    end

    local msg = p1
    local range = nil
    local p2IsMsg = false
    if type(p1) == "number" then
        p2IsMsg = true
        msg = p2

        if p1 ~= -1 then
            range = p1
        end
    end

    local contextArray = table_remove(__arrayPool)
    if contextArray == nil then
        contextArray = {}
    end

    local distanceArray = nil
    if range ~= nil then
        distanceArray = table_remove(__arrayPool)
        if distanceArray == nil then
            distanceArray = {}
        end
    end

    table_insert(contextArray, self)
    if range ~= nil then
        table_insert(distanceArray, 0)
    end

    local index = 1
    local target = nil
    local fun = nil

    while index <= #contextArray do
        target = contextArray[index]
        local eventEx = target.__eventEx 
        if eventEx ~= nil then
            fun = eventEx[msg]
            if fun ~= nil then
                -- use parent context for ex event
                target = target.p
                break
            end
        end

        local event = target.__event
        if event ~= nil then
            fun = event[msg]
            if fun ~= nil then
                break
            end
        end

        local outofRange = false
        local distance = 0
        if range ~= nil then
            distance = distanceArray[index]
            if distance >= range then
                outofRange = true
            end
        end

        if not outofRange then
            local subContexts = target.__subContexts
            if subContexts ~= nil then
                for _, sub in ipairs(subContexts) do
                    -- if sub.__lifeState < lifeState.quitting then
                    if sub.__lifeState < 20 then
                        table_insert(contextArray, sub)
                        if range ~= nil then
                            table_insert(distanceArray, distance + 1)
                        end
                    end
                end
            end
        end


        index = index + 1
    end

    while next(contextArray) do
        table_remove(contextArray)
    end
    table_insert(__arrayPool, contextArray)

    if distanceArray ~= nil then
        while next(distanceArray) do
            table_remove(distanceArray)
        end
        table_insert(__arrayPool, distanceArray)
    end

    if fun ~= nil then
        if p2IsMsg then
            return fun(target, ...)
        else
            return fun(target, p2, ...)
        end
    end
end

context_notifyAll = function (self, p1, p2, ...)
    -- if self.__lifeState >= lifeState.quitting then
    if self.__lifeState >= 20 then
        return
    end

    if p1 == nil then
        return
    end

    local msg = p1
    local range = nil
    local p2IsMsg = false
    if type(p1) == "number" then
        p2IsMsg = true
        msg = p2

        if p1 ~= -1 then
            range = p1
        end
    end


    local funArray = table_remove(__arrayPool)
    if funArray == nil then
        funArray = {}
    end

    local targetArray = table_remove(__arrayPool)
    if targetArray == nil then
        targetArray = {}
    end

    local target = nil
    local contextArray = table_remove(__arrayPool)
    if contextArray == nil then
        contextArray = {}
    end

    local distanceArray = nil
    if range ~= nil then
        distanceArray = table_remove(__arrayPool)
        if distanceArray == nil then
            distanceArray = {}
        end
    end

    table_insert(contextArray, self)
    if range ~= nil then
        table_insert(distanceArray, 0)
    end
    local index = 1
    local fun = nil

    while index <= #contextArray do
        target = contextArray[index]

        local eventEx = target.__eventEx 
        if eventEx ~= nil then
            fun = eventEx[msg]
            if fun ~= nil then
                -- use parent context for ex event
                table_insert(targetArray, target.p)
                table_insert(funArray, fun)
            end
        end

        local event = target.__event
        if event ~= nil then
            fun = event[msg]
            if fun ~= nil then
                table_insert(targetArray, target)
                table_insert(funArray, fun)
            end
        end

        local outofRange = false
        local distance = 0
        if range ~= nil then
            distance = distanceArray[index]
            if distance >= range then
                outofRange = true
            end
        end

        if not outofRange then
            local subContexts = target.__subContexts
            if subContexts ~= nil then
                for _, sub in ipairs(subContexts) do
                    -- if sub.__lifeState < lifeState.quitting then
                    if sub.__lifeState < 20 then
                        table_insert(contextArray, sub)
                        if range ~= nil then
                            table_insert(distanceArray, distance + 1)
                        end
                    end
                end
            end
        end

        index = index + 1
    end

    while next(contextArray) do
        table_remove(contextArray)
    end
    table_insert(__arrayPool, contextArray)

    -- local tm = self.tm
    for i = 1, #targetArray do
        local c = targetArray[i]
        local fun = funArray[i]
        -- if c.__lifeState < lifeState.quitting then
        if c.__lifeState < 20 then
            if p2IsMsg then
                tabMachine_pcall(self, fun, c, ...)
            else
                tabMachine_pcall(self, fun, c, p2, ...)
            end
        end
    end

    while next(targetArray) do
        table_remove(targetArray)
    end
    table_insert(__arrayPool, targetArray)

    if distanceArray ~= nil then
        while next(distanceArray) do
            table_remove(distanceArray)
        end
        table_insert(__arrayPool, distanceArray)
    end

    while next(funArray) do
        table_remove(funArray)
    end
    table_insert(__arrayPool, funArray)
end

context_upwardNotify = function (self, p1, p2, ...)
    -- if self.__lifeState >=  lifeState.quitting then
    if self.__lifeState >= 20 then
        return
    end

    if p1 == nil then
        return
    end

    local msg = p1
    local range = nil
    local p2IsMsg = false
    if type(p1) == "number" then
        p2IsMsg = true
        msg = p2

        if p1 ~= -1 then
            range = p1
        end
    end

    --search and visit states 
    local contextArray = table_remove(__arrayPool)
    if contextArray == nil then
        contextArray = {}
    end

    local distanceArray = nil
    if range ~= nil then
        distanceArray = table_remove(__arrayPool)
        if distanceArray == nil then
            distanceArray = {}
        end
    end

    local visitMap = table_remove(__mapPool)
    if visitMap == nil then
        visitMap = {}
    end

    table_insert(contextArray, self)
    if range ~= nil then
        table_insert(distanceArray, 0)
    end

    visitMap[self] = true
    local index = 1


    local target = nil
    local fun = nil
    while index <= #contextArray do
        target = contextArray[index]

        local event = target.__event
        if event ~= nil then
            fun = event[msg]
            if fun ~= nil then
                break
            end
        end

        local eventEx = target.__eventEx 
        if eventEx ~= nil then
            fun = eventEx[msg]
            if fun ~= nil then
                -- use parent context for ex event
                target = target.p
                break
            end
        end

        local outofRange = false
        local distance = 0
        if range ~= nil then
            distance = distanceArray[index]
            if distance >= range then
                outofRange = true
            end
        end

        if not outofRange then
            local proxyInfo = target.__headProxyInfo
            while proxyInfo ~= nil do
                if not proxyInfo.detached then
                    local proxy = proxyInfo.proxy
                    if not visitMap[proxy] and
                        -- proxy.__lifeState < lifeState.quitting then
                        proxy.__lifeState < 20 then
                        table_insert(contextArray, proxy)
                        if range ~= nil then
                            table_insert(distanceArray, distance + 1)
                        end
                        visitMap[proxy] = true
                    end
                end
                proxyInfo = proxyInfo.nextInfo
            end

            local p = target.p
            if p and not visitMap[p] then
                -- if self is not quitting then self.p isn't quitting too.
                -- and  not p.__isQuitting then
                table_insert(contextArray, p)
                if range ~= nil then
                    table_insert(distanceArray, distance + 1)
                end
                visitMap[p] = true
            end
        end

        index = index + 1
    end

    for key, _ in pairs(visitMap) do
        visitMap[key] = nil
    end
    table_insert(__mapPool, visitMap)

    while next(contextArray) do
        table_remove(contextArray)
    end
    table_insert(__arrayPool, contextArray)

    if distanceArray ~= nil then
        while next(distanceArray) do
            table_remove(distanceArray)
        end
        table_insert(__arrayPool, distanceArray)
    end


    if fun ~= nil then
        if p2IsMsg then
            return fun(target, ...)
        else
            return fun(target, p2, ...)
        end
    end
end

context_upwardNotifyAll = function (self, p1, p2, ...)
    -- if self.__lifeState >= lifeState.quitting then
    if self.__lifeState >= 20 then
        return
    end

    if p1 == nil then
        return
    end

    local msg = p1
    local range = nil
    local p2IsMsg = false
    if type(p1) == "number" then
        p2IsMsg = true
        msg = p2

        if p1 ~= -1 then
            range = p1
        end
    end

    --notify target and fun
    local funArray = table_remove(__arrayPool)
    if funArray == nil then
        funArray = {}
    end

    local targetArray = table_remove(__arrayPool)
    if targetArray == nil then
        targetArray = {}
    end

    --search and visit states 
    local contextArray = table_remove(__arrayPool)
    if contextArray == nil then
        contextArray = {}
    end
    local visitMap = table_remove(__mapPool)
    if visitMap == nil then
        visitMap = {}
    end

    local distanceArray = nil
    if range ~= nil then
        distanceArray = table_remove(__arrayPool)
        if distanceArray == nil then
            distanceArray = {}
        end
    end

    table_insert(contextArray, self)
    if range ~= nil then
        table_insert(distanceArray, 0)
    end

    visitMap[self] = true
    local index = 1


    local target = nil
    local fun = nil
    while index <= #contextArray do
        target = contextArray[index]

        local event = target.__event
        if event ~= nil then
            fun = event[msg]
            if fun ~= nil then
                table_insert(targetArray, target)
                table_insert(funArray, fun)
            end
        end

        local eventEx = target.__eventEx 
        if eventEx ~= nil then
            fun = eventEx[msg]
            if fun ~= nil then
                --use parent context for ex event
                table_insert(targetArray, target.p)
                table_insert(funArray, fun)
            end
        end

        local outofRange = false
        local distance = 0
        if range ~= nil then
            distance = distanceArray[index]
            if distance >= range then
                outofRange = true
            end
        end

        if not outofRange then
            local proxyInfo = target.__headProxyInfo
            while proxyInfo ~= nil do
                if not proxyInfo.detached then
                    local proxy = proxyInfo.proxy
                    if not visitMap[proxy] and
                        -- proxy.__lifeState < lifeState.quitting then
                        proxy.__lifeState < 20 then
                        table_insert(contextArray, proxy)
                        if range ~= nil then
                            table_insert(distanceArray, distance + 1)
                        end
                    end
                end
                proxyInfo = proxyInfo.nextInfo
            end

            local p = target.p
            if p and not visitMap[p] then
                -- if target is not quitting then target.p isn't quitting too.
                -- and  not p.__isQuitting then
                table_insert(contextArray, p)
                if range ~= nil then
                    table_insert(distanceArray, distance + 1)
                end
                visitMap[p] = true
            end
        end

        index = index + 1
    end


    for key, _ in pairs(visitMap) do
        visitMap[key] = nil
    end
    table_insert(__mapPool, visitMap)

    while next(contextArray) do
        table_remove(contextArray)
    end
    table_insert(__arrayPool, contextArray)

    -- local tm = self.tm
    for i = 1, #targetArray do
        local c = targetArray[i]
        local fun = funArray[i]
        -- if c.__lifeState < lifeState.quitting then
        if c.__lifeState < 20 then
            if p2IsMsg then
                tabMachine_pcall(self, fun, c, ...)
            else
                tabMachine_pcall(self, fun, c, p2, ...)
            end
        end
    end

    while next(targetArray) do
        table_remove(targetArray)
    end
    table_insert(__arrayPool, targetArray)

    if distanceArray ~= nil then
        while next(distanceArray) do
            table_remove(distanceArray)
        end
        table_insert(__arrayPool, distanceArray)
    end

    while next(funArray) do
        table_remove(funArray)
    end
    table_insert(__arrayPool, funArray)
end

context_installTab  = function (self, tab)
    self.__tab = tab
    if tab == nil then
        return
    end

    self.__finalFun = tab.final
    self.__event = tab.event
    self.__catchFun = tab.catch
    local updateFun = tab.update
    if updateFun ~= nil then
        self.__updateFun = tab.update
        self.__updateInterval = tab.updateInterval
        self.__updateTimerMgr = tab.updateTimerMgr
    end

    tabMachine_compileTab(tab)
end

context_stopSub = function (self, scName)
    -- self.__pc = subContext
    -- self.__pcName = scName
    -- self.__pcAction = "stop_sub"

    local subContexts = self.__subContexts
    if  subContexts == nil then
        return
    end

    for index = #subContexts, 1, -1 do
        local subContext = subContexts[index]
        if subContext.__name == scName  then
            context_stopSelf(subContext)
            return
        end
    end
end

context_stopSelf = function (self)
    -- if self.__lifeState >= lifeState.stopped then
    if self.__lifeState >= 40 then
        return
    end

    local debugger = __anyDebuggerEanbled and self.__debugger or nil
    if debugger then
        debugger:onContextStop(self)
    end

    -- self.__pc = self
    -- self.__pcName =  "self"
    -- self.__pcAction = "stop_self"

    -- self.__lifeState = lifeState.stopped
    -- self.__lifeState = 40
    local p = self.p
    -- if p == nil then
        -- dump(c, "jjjjjjjj 444444444 p is nil", 3, printError)
    -- end

    -- local tm = self.tm
    -- if self.__lifeState < lifeState.quitted then
    if self.__lifeState < 30 then
        -- self.__lifeState = lifeState.stopped
        self.__lifeState = 40

        local quitFun = self.__quitFun
        if quitFun ~= nil then
            -- self.__pc = self
            -- self.__pcName = "self"
            -- self.__pcAction = "finalize"

            tabMachine_pcall(self, quitFun, self)
        end


        local quitFunEx = self.__quitFunEx
        if quitFunEx ~= nil and p then
            -- self.__pc = self
            -- self.__pcName = "self"
            -- self.__pcAction = "finalize"
            tabMachine_pcall(self, quitFunEx, p)
        end
    else
        -- self.__lifeState = lifeState.stopped
        self.__lifeState = 40
    end

    --inline optimization
    -- self:_stopUpdateTickNotify()
    
    -- self.__isUpdateTickNotifyStopped = true

    local updateTimer = self.__updateTimer
    if  updateTimer then
        self.__scheduler:destroyTimer(updateTimer, self.__updateTimerMgrEx or self.__updateTimerMgr)
        self.__updateTimer = nil
    end

    -- self.__isSubStopped = true

    -- we use the same flag that indicating timer clearing
    local subContexts = self.__subContexts 
    if subContexts ~= nil then
        if #subContexts ~= 0 then
            local treeArray = table_remove(__contextTreePool)
            if treeArray == nil then
                treeArray  = {}
            end

            context_collectStopTree(self, treeArray)
            context_stopTree(treeArray)

            table_insert(__contextTreeRecyclePool, treeArray)
        end

        table_insert(__subContainerRecyclePool, subContexts)
        self.__subContexts = nil
    end

    --inline optimization
    -- self:_stopLifeTimeRelation()
    -- we use the same flag that indicating timer clearing
    local listenInfo = self.__headListenInfo
    while listenInfo do
        context_unregisterLifeTimeListener(listenInfo.target, listenInfo.name, self)
        listenInfo = self.__headListenInfo
    end
    self.__headListenInfo = nil

    local mapHeadListener = self.__mapHeadListener
    if mapHeadListener then
        for name, headListener in pairs(mapHeadListener) do
            local listenter = headListener
            while listenter ~= nil do
                context_unregisterLifeTimeListener(self, name, listenter.context)
                listenter = listenter.nextListener
            end
        end
    end
    self.__mapHeadListener = nil


    -- local subContexts = self.__subContexts
    -- if  subContexts ~= nil then
    -- local index = #subContexts
    -- while index > 0 do
    -- local subContext = subContexts[index]
    -- if not subContext.__isStopped then
    -- local oldChildOpId = self.__childOpId
    -- context_stopSelf(subContext)
    -- if self.__childOpId == oldChildOpId then
    -- index = index - 1
    -- else
    -- index = #subContexts
    -- end
    -- else
    -- index = index - 1
    -- context_stopSelf(subContext)
    -- end
    -- end
    -- end
    
    if self.__needDispose then
        self:dispose()
    end

    local finalFun = self.__finalFun

    if finalFun ~= nil then
        -- self.__pc = self
        -- self.__pcName = "self"
        -- self.__pcAction = "finalize"

        tabMachine_pcall(self, finalFun, self)
    end

    local finalFunEx = self.__finalFunEx
    if finalFunEx ~= nil and p then
        -- self.__pc = self
        -- self.__pcName = "self"
        -- self.__pcAction = "finalize"
        tabMachine_pcall(self, finalFunEx, p)
    end

    -- local tm = self.tm
    if p then
        -- if p.__lifeState < __lifeState.quitting then
        if p.__lifeState < 20 then
            local outputVars = self.__outputVars
            if outputVars then
                outputValues(p, outputVars, self.__outputValues)
            end
        end

        context_removeSubContext(p, self)
    -- elseif self.__isRoot then
        -- tm:_setOutputs(self.__outputValues)
    end

    -- if not self.__isNotifyStopped then
        -- self.__isNotifyStopped = true
        -- context_notifyStop(self)
    -- end

    local co = self.__co
    if co then
        co_interupt(co)
    end

    context_notifyStop(self)

    -- if not self.__isProxyStopped then
        -- self.__isProxyStopped = true
        local proxyInfo = self.__headProxyInfo
        while proxyInfo ~= nil do
            if not proxyInfo.detached then
                context_stopSelf(proxyInfo.proxy)
            end
            proxyInfo = proxyInfo.nextInfo
        end
    -- end


    -- self.tm:_recycleContext(self)
    -- inline optimization
    -- if not self.__isRecycled then
        -- self.__isRecycled = true
        table_insert(__contextRecyclePool, self)
    -- else
        -- dump(self, "jjjjjjjj 333333333 stop self repeat recycle", 3, printError)
    -- end
end

context_collectStopTree = function (self, treeArray)
    local frontNode = self
    while true do

        local subContexts  = frontNode.__subContexts
        local visitIndex = frontNode.__visitIndex

        if visitIndex == nil then
            if subContexts == nil or #subContexts == 0 then
                local ls = frontNode.__lifeState
                -- if ls < lifeState.stopped then
                if ls < 40 then
                    if ls < 20 then
                        -- frontNode.__lifeState = lifeState.quitting
                        frontNode.__lifeState = 20
                    end
                    
                    table_insert(treeArray, frontNode)
                end

                frontNode = frontNode.p
            else
                visitIndex = #subContexts 
                frontNode.__visitIndex = visitIndex
                local childNode = subContexts[visitIndex]
                if childNode.p == frontNode then
                    frontNode = childNode
                end
            end
        else
            if visitIndex == 1  then
                frontNode.__visitIndex = nil
                if frontNode == self then
                    break
                else
                    local ls = frontNode.__lifeState
                    -- if ls < lifeState.stopped then
                    if ls < 40 then
                        if ls < 20 then
                            -- frontNode.__lifeState = lifeState.quitting
                            frontNode.__lifeState = 20
                        end

                        table_insert(treeArray, frontNode)
                    end

                    frontNode = frontNode.p
                end
            else
                visitIndex = visitIndex - 1
                frontNode.__visitIndex = visitIndex
                local childNode = subContexts[visitIndex]
                if childNode.p ~= frontNode then
                else
                    frontNode = childNode
                end
            end
        end
    end
end

function __getContextPath(context)
    local c = context
    local name = nil
    while c do
        local partName = c.__name

        if c.tabName and c.tabName ~= "context" then
            partName = partName .. "(" .. c.tabName .. ")"
        end

        if c._nickName then
            partName = partName .. "[" .. c._nickName .. "]"
        end

        if name == nil then
            name = partName
        else
            name = partName .. "." .. name
        end

        c = c.p
    end

    return name
end

context_stopTree = function (treeArray)
    local len = #treeArray
    for index = len, 1, -1 do
        local c = treeArray[index]
        -- if c.__lifeState < lifeState.quitted then
        if c.__lifeState < 30 then
            -- c.__lifeState = lifeState.quitted
            c.__lifeState = 30
            local debugger = __anyDebuggerEanbled and c.__debugger or nil
            if debugger then
                debugger:onContextQuit(c)
            end

            local quitFun = c.__quitFun
            if quitFun ~= nil then
                tabMachine_pcall(c, quitFun, c)
            end

            local quitFunEx = c.__quitFunEx
            local p = c.p 
            if quitFunEx ~= nil and p then
                tabMachine_pcall(c, quitFunEx, p)
            end
        end
    end
    
    for _, c in ipairs (treeArray) do
        -- if c.__lifeState < lifeState.stopped then
        if c.__lifeState < 40 then
            -- c.__lifeState = lifeState.stopped
            c.__lifeState = 40
            -- c.__isUpdateTickNotifyStopped = true

            local debugger = __anyDebuggerEanbled and c.__debugger or nil
            if debugger then
                debugger:onContextStop(c)
            end

            local updateTimer = c.__updateTimer
            if  updateTimer then
                c.__scheduler:destroyTimer(updateTimer, c.__updateTimerMgrEx or c.__updateTimerMgr)
                c.__updateTimer = nil
            end

            -- c.__isSubStopped = true
            local subContexts = c.__subContexts 
            if subContexts ~= nil then
                table_insert(__subContainerRecyclePool, subContexts)
                c.__subContexts = nil
            end

            local listenInfo = c.__headListenInfo
            while listenInfo do
                context_unregisterLifeTimeListener(listenInfo.target, listenInfo.name, c)
                listenInfo = c.__headListenInfo
            end
            c.__headListenInfo = nil

            local mapHeadListener = c.__mapHeadListener
            if mapHeadListener then
                for name, headListener in pairs(mapHeadListener) do
                    local listenter = headListener
                    while listenter ~= nil do
                        context_unregisterLifeTimeListener(c, name, listenter.context)
                        listenter = listenter.nextListener
                    end
                end
            end
            c.__mapHeadListener = nil

            if c.__needDispose then
                c:dispose()
            end

            local p = c.p
            -- c.__isFinalized = true
            local finalFun = c.__finalFun
            if finalFun ~= nil then
                tabMachine_pcall(c, finalFun, c)
            end

            local finalFunEx = c.__finalFunEx
            if finalFunEx ~= nil and p then
                tabMachine_pcall(c, finalFunEx, p)
            end

            local co = c.__co
            if co then
                co_interupt(co)
            end

            local proxyInfo = c.__headProxyInfo
            while proxyInfo ~= nil do
                if not proxyInfo.detached then
                    context_stopSelf(proxyInfo.proxy)
                end
                proxyInfo = proxyInfo.nextInfo
            end
            c.__headProxyInfo = nil

            -- if not c.__isRecycled then
                -- c.__isRecycled = true
                table_insert(__contextRecyclePool, c)
            -- else
                -- dump(c, "jjjjjjjj 333333333 collect tree repeat recycle", 3, printError)
            -- end
        end
    end
end

context_stopLifeTimeRelation = function (self)
    if self.__isLifeTimeRelationStopped then
        return
    end

    self.__isLifeTimeRelationStopped = true

    while self.__headListenInfo do
        local listenInfo = self.__headListenInfo
        context_unregisterLifeTimeListener(listenInfo.target, listenInfo.name, self)
        -- after unreigeration, self.__headListenInfo should be updated
    end

    local mapHeadListener = self.__mapHeadListener
    if mapHeadListener then
        for name, headListener in pairs(mapHeadListener) do
            local listenter = headListener
            while listenter ~= nil do
                context_unregisterLifeTimeListener(self, listenter.name, listenter.context)
                listenter = listenter.nextListener
            end
        end
    end
end

context_stopUpdateTickNotify = function (self)
    if self.__isUpdateTickNotifyStopped then
        return 
    end

    -- self.__pc = subContext
    -- self.__pcName = "self"
    -- self.__pcAction =  "stop_update_and_tick"

    self.__isUpdateTickNotifyStopped = true

    context_destroyTickAndUpdateTimers(self)
end

context_createTickAndUpdateTimers = function (self)
    if self.__isUpdateTickNotifyStopped then
        return 
    end

    if self.__updateFun ~= nil or
        self.__updateFunEx ~= nil then
        local timer = self.__scheduler:createTimer(self, context_update,
        self.__updateIntervalEx or self.__updateInterval, self.__updateTimerMgrEx or self.__updateTimerMgr)
        self.__updateTimer = timer
    end
end

context_destroyTickAndUpdateTimers = function (self)
    local timer = self.__updateTimer
    if timer then
        self.__scheduler:destroyTimer(timer, self.__updateTimerMgrEx or self.__updateTimerMgr)
        self.__updateTimer = nil
    end
end

--deprecated
context_stopSubs = function (self)
    if self.__isSubStopped then
        return
    end

    -- self.__pc = subContext
    -- self.__pcName = "self"
    -- self.__pcAction = "stop subs"

    self.__isSubStopped = true
    local subContexts = self.__subContexts
    if  subContexts ~= nil then
        local subContext = subContexts[#subContexts]
        while subContext ~= nil and subContext.p == self do
            context_stopSelf(subContext)
            -- subContext:_stopSelf() will ensure subContext being removed from self
            subContext = subContexts[#subContexts]
        end
    end
end

context_finalize = function (self)
    if self.__isFinalized then
        return
    end

    self.__isFinalized = true
    self.__subContexts = nil

    -- self.__pc = self
    -- self.__pcName = "self"
    -- self.__pcAction = "finalize"

    -- local tm = self.tm
    -- inner final first
    local finalFun = self.__finalFun
    if finalFun ~= nil then
        tabMachine_pcall(self, finalFun, self)
    end

    local finalFunEx = self.__finalFunEx
    if finalFunEx ~= nil then
        local p = self.p
        if p then
            tabMachine_pcall(self, finalFunEx, p)
        end
    end
end


context_forEachSub = function (self, callback)
    local subContexts = self.__subContexts
    if subContexts == nil then
        return
    end

    local contextArray = table_remove(__arrayPool)
    if contextArray == nil then
        contextArray = {}  
    end

    for index = #subContexts, 1, -1 do
        local subContext = subContexts[index]
        table_insert(contextArray, subContext)
    end

    for _, subContext in ipairs(contextArray) do
        if subContext.p == self then
            local isIterationFinished = callback(subContext)
            if isIterationFinished then
                break
            end
        end
    end

    while next(contextArray) do
        table_remove(contextArray)
    end
    table_insert(__arrayPool, contextArray)
end

--deprecated
context_detach = function (self)
    if self.__isDetached then
        return
    end

    self.__isDetached = true

    -- self.__pc = self
    -- self.__pcName = "self"
    -- self.__pcAction =  "detach"

    local p = self.p
    -- local tm = self.tm
    -- if p and p.__lifeState < lifeState.stopped then
    if p and p.__lifeState < 40 then
        local outputVars = self.__outputVars
        if outputVars then
            outputValues(p, outputVars, self.__outputValues)
        end
        context_removeSubContext(p, self)
    -- elseif self.__isRoot then
        -- tm:_setOutputs(self.__outputValues)
    end
end

--inline 
context_notifyStop = function(self)
    -- if self.__isNotifyStopped then
    --     return
    -- end

    self.__isNotifyStopped = true
    local p = self.p
    -- local tm = self.tm

    -- self.__pc = self
    -- self.__pcName = "self"
    -- self.__pcAction = "notify_stop"

    local hasNotify = false
    if p and p.__mapHeadListener then
        context_addEnterCount(p)
        hasNotify = true
        context_notifyLifeTimeEvent(p, tabMachine.event_context_stop, self.__name, self)
    end

    -- if p and p.__lifeState < lifeState.stopped then
    if p and p.__lifeState < 40 then
        -- context_checkNext(p, self.__name)
        local nextSubCache = __nextSubCache
        local nextSub = nextSubCache[self.__name]
        if nextSub ~= nil then
            context_start(p, nextSub)
        end
        --p:_checkStop()
        --expand checkStop
        local subContexts = p.__subContexts
        if (subContexts == nil or next(subContexts) == nil) and p.__updateFun == nil
            and p.__enterCount 
            and p.__enterCount <= 0 and p.__suspends == nil then
            context_stopSelf(p)
        end
    -- elseif self.__isRoot then
        -- tm:_onStopped()
        -- return
        local pco = p.__co
        if pco and self.__name == "__co" then
            co_resume(pco, self)
        end
    end

    if hasNotify then
        context_decEnterCount(p)
    end
end

context_notifyLifeTimeEvent = function (self, eventType, scName, target)
    local listenter = self.__mapHeadListener[scName]
    -- local tm = self.tm
    while listenter ~= nil do
        if not listenter.detached then
            local c = listenter.context
            -- if c.__lifeState < lifeState.quitting then
            if c.__lifeState < 20 then 
                local fun = nil
                local event = c.__event 
                if event ~= nil then
                    fun = event[eventType]
                    if fun ~= nil then
                        tabMachine_pcall(self, fun, c, self, scName, target)
                    end
                end

                local eventEx = c.__eventEx 
                if eventEx ~= nil then
                    fun = eventEx[eventType]
                    if fun ~= nil then
                        tabMachine_pcall(self, fun, c.p, self, scName, target)
                    end
                end
            end
        end
        listenter = listenter.nextListener
    end
end

-- function context:_stopProxy()
--     if self.__isProxyStopped then
--         return
--     end
--     self.__isProxyStopped = true

--     local proxyInfo = self.__headProxyInfo
--     while proxyInfo ~= nil do
--         if not proxyInfo.detached then
--             proxyInfo.proxy:stop()
--         end
--         proxyInfo = proxyInfo.nextInfo
--     end
-- end

context_addEnterCount = function(self)
    -- if self.__lifeState >= lifeState.stopped then
    if self.__lifeState >= 40 then
        return
    end
    local enterCount = self.__enterCount
    if enterCount then
        self.__enterCount = enterCount + 1
    end
end

context_decEnterCount = function(self)
    -- if self.__lifeState >= lifeState.stopped then
    if self.__lifeState >= 40 then
        return
    end

    local enterCount = self.__enterCount
    if enterCount then
        enterCount = enterCount - 1
        if enterCount <= 0 then
            local subContexts = self.__subContexts
            if (subContexts == nil or next(subContexts) == nil) and self.__updateFun == nil
                and self.__event == nil 
                and self.__suspends == nil then
                context_stopSelf(self)
                return
            end
        end
        self.__enterCount = enterCount
    end
end

context_throwException = function(self, exception)
    -- if self.__isNotifyStopped then
        -- return true
    -- end

    local debugger = __anyDebuggerEanbled and self.__debugger or nil
    if debugger then
        debugger:onContextException(self, exception)
    end

    local isCatched = false
    local curSubCatchFun = self.__curSubCatchFun
    if curSubCatchFun ~= nil then
        isCatched = curSubCatchFun(self, exception)
    end

    if not isCatched then
        local catchFun = self.__catchFun 
        if catchFun ~= nil then
            isCatched = catchFun(self, exception)
        end
    end

    if not isCatched then
        local p = self.p
        -- if p ~= nil and p.__lifeState < lifeState.stopped then
        if p ~= nil and p.__lifeState < 40 then
            local catchFunEx = self.__catchFunEx
            if catchFunEx ~= nil then
                isCatched = catchFunEx(self.p, exception)
            end
        end
    end

    if isCatched then
        return true
    end

    local pp = self.p
    if pp then
        exception.pcName = pp.__pcName
        exception.pcAction = pp.__pcAction
        exception.scName = self.__name
        return context_throwException(pp, exception)
    end

    return false
end

context_getScheduler = function (self)
    return self.__scheduler
end

context_setScheduler = function (self, scheduler)
    if scheduler == self.__scheduler then
        return
    end

    context_destroyTickAndUpdateTimers(self)
    self.__scheduler = scheduler
    context_createTickAndUpdateTimers(self)

    local subContexts = self.__subContexts
    if subContexts == nil then
        return
    end

    for _, subContext in ipairs(subContexts) do
        subContext:setScheduler(scheduler)
    end
end

context_getDebugger = function (self)
    return self.__debugger
end

context_setDebugger = function (self, debugger)
    __anyDebuggerEanbled = true
    self.__debugger = debugger
    local subContexts = self.__subContexts
    if subContexts == nil then
        return
    end

    for _, subContext in ipairs(subContexts) do
        context_setDebugger(subContext, debugger)
    end
end

context_setTabProfiler = function (self, tabProfiler)
    self.__tabProfiler = tabProfiler
    if subContexts == nil then
        return
    end

    for _, subContext in ipairs(subContexts) do
        context_setTabProfiler(subContext, subContext)
    end
end

context_addProxy = function(self, proxy)
    -- if self.__lifeState >= lifeState.stopped then
    if self.__lifeState >= 40 then
        return
    end

    local outputValues = self.__outputValues
    if outputValues == nil then
        proxy.__outputValues = nil
    else
        proxy.__outputValues = {}
        for _, output in ipairs(outputValues) do
            table_insert(proxy.__outputValues, output)
        end
    end

    local proxyInfo = {proxy = proxy}
    local oldHeadProxyInfo = self.__headProxyInfo
    if oldHeadProxyInfo ~= nil then
        oldHeadProxyInfo.prevInfo = proxyInfo
        proxyInfo.nextInfo = oldHeadProxyInfo
    end
    self.__headProxyInfo = proxyInfo
end

context_removeProxy = function(self, proxy)
    -- if self.__lifeState >= lifeState.stopped then
    if self.__lifeState >= 40 then
        return
    end

    local proxyInfo = self.__headProxyInfo
    while proxyInfo ~= nil do
        if proxyInfo.proxy == proxy then 
            proxyInfo.detached = true

            if proxyInfo.prevInfo ~= nil then
                proxyInfo.prevInfo.nextInfo = proxyInfo.nextInfo
            end

            if proxyInfo.nextInfo ~= nil then
                proxyInfo.nextInfo.prevInfo = proxyInfo.prevInfo
            end

            if self.__headProxyInfo == proxyInfo then
                self.__headProxyInfo = proxyInfo.nextInfo
            end

            break
        else
            proxyInfo = proxyInfo.nextInfo
        end
    end
end

context_setDynamics = function(self, scName, key, value)
    local dynamics = self.__dynamics
    local dynamicLabels = nil

    if dynamics == nil then
        dynamics = {}
        self.__dynamics = dynamics
    else
        dynamicLabels = dynamics[scName]
    end

    if dynamicLabels == nil then
        dynamicLabels = {}
        dynamics[scName] = dynamicLabels
    end

    dynamicLabels[key] = value
end

context_setBreakPoint = function (self, scName)
    local breakPoints = self.__breakPoints
    if breakPoints == nil then
        breakPoints = {}
        self.__breakPoints = breakPoints 
    end

    local breakPoint = breakPoints[scName]
    if breakPoint ~= nil then
        return
    end

    breakPoint = {}
    breakPoint.scName = scName
    breakPoints[scName] = breakPoint
end

context_deleteBreakPoint = function (self, scName)
    local breakPoints = self.__breakPoints
    if breakPoints  == nil then
        return
    end

    local breakPoint = breakPoints[scName]
    if breakPoint == nil then
        return
    end

    breakPoints[scName] = nil

    if next(breakPoints) == nil then
        self.__breakPoints = nil
    end
end

context_deleteAllBreakPoints = function (self)
    self.__breakPoints = nil
end

context_runNormally = function (self)
    self.__runMode = nil
    context_resumeSuspends(self, true)
end

context_breakAtNextBreakPoint = function (self)
    self.__runMode = runMode.breakAtNextBreakPoint
end

context_breakAtNextSub = function (self)
    self.__runMode = runMode.breakAtNextSub
end

context_resumeSuspends = function (self, resumeAll, scName, ...)
    local suspends = self.__suspends
    if suspends then
        context_addEnterCount(self)

        for _, suspend in ipairs(suspends) do
            local needToResume = true
            if scName ~= nil then
                needToResume = scName == suspend.scName
            end

            if needToResume then
                suspend.isResumed = true
                context_addBreakPass(self, suspend.scName)
                suspend.resume(suspend, ...)
                context_removeBreakPass(self, suspend.scName)
                if self.__mapHeadListener then
                    context_notifyLifeTimeEvent(self, tabMachine.event_context_resume, suspend.scName, self)
                end
                if not resumeAll then
                    break
                end
            end
        end

        local index = 1
        while index <= #suspends do
            local suspend = suspends[index]
            if suspend.isResumed then
                table_remove(suspends, index)
                local debugger = self.__debugger
                if debugger then
                    debugger:onTabResume(self, suspend.scName)
                end
            else
                index = index + 1
            end
        end

        if next(suspends) == nil then
            self.__suspends = nil
        end

        context_decEnterCount(self)
    end
end

context_resumeStepSuspends = function(self)
    local suspends = self.__suspends
    if suspends then
        context_addEnterCount(self)
        for _, suspend in ipairs(suspends) do
            local breakPoints = self.__breakPoints
            if breakPoints == nil or breakPoints[suspend.scName] == nil then
                context_addBreakPass(self, suspend.scName)
                suspend.resume(suspend)
                context_removeBreakPass(self, suspend.scName)
                if self.__mapHeadListener then
                    context_notifyLifeTimeEvent(self, tabMachine.event_context_resume, suspend.scName, self)
                end
            end
        end

        local index = 1
        while index <= #suspends do
            local suspend = suspends[index]
            if suspend.isResumed then
                table_remove(suspends, index)
            else
                index = index + 1
            end
        end

        context_decEnterCount(self)

        if next(suspends) == nil then
            self.__suspends = nil
        end
    end
end


context_needToBreak = function(self, scName)
    local mode = self.__runMode
    if mode == runMode.breakAtNextSub then
        local breakPass = self.__breakPass 
        if breakPass and breakPass[scName] then
            return false
        end

        return true
    end

    if mode == runMode.breakAtNextBreakPoint then
        local breakPoints = self.__breakPoints
        if breakPoints ~= nil then
            local breakPoint = breakPoints[scName]
            if breakPoint == nil then
                return false
            end

            local breakPass = self.__breakPass 
            if breakPass and breakPass[scName] then
                return false
            end

            return true
        end
    end

    return false
end

context_addSuspend = function(self, resumeFun, scName)
    local suspends = self.__suspends
    if suspends == nil then
        suspends = {}
        self.__suspends = suspends
    end

    local suspend = {
        resume = resumeFun,
        scName = scName
    }

    table_insert(suspends, suspend)
    if self.__mapHeadListener then
        context_notifyLifeTimeEvent(self, tabMachine.event_context_suspend, scName, self)
    end

    local debugger = self.__debugger
    if debugger then
        debugger:onTabSuspend(self, scName)
    end
end

context_addBreakPass = function(self, scName)
    local breakPass = self.__breakPass
    if breakPass == nil then
        breakPass = {}
        self.__breakPass = breakPass
    end
    breakPass[scName] = true
end

context_removeBreakPass = function(self, scName)
    local breakPass = self.__breakPass
    if breakPass == nil then
        return
    end

    breakPass[scName] = nil
    if next(breakPass) == nil then
        self.__breakPass = nil
    end
end

context_suspend = function (self, scName)
    context_setBreakPoint(self, scName)
    context_breakAtNextBreakPoint(self)
end

context_postpone = function (self, scName)
    context_suspend(self, scName)

    return _({
        s1 = function(c)
            context_resume(self, scName)
            context_call(c, self:tabProxy(scName), "s2")
        end,
    })
end

context_resume = function (self, scName, ...)
    if self.__breakPoints then
        context_deleteBreakPoint(self, scName)
    end

    context_resumeSuspends(self, true, scName, ...)
end

context_hasSuspend = function (self, scName)
    local suspends = self.__suspends
    if suspends == nil then
        return false
    end

    if scName == nil then
        return #suspends > 0
    end

    for _, suspend in ipairs(suspends) do
        if scName == suspend.scName then
            return true
        end
    end

    return false
end

context_tabSuspend = function (self, scName, target)
    return _({
        s1 = function(c)
            local suspends = self.__suspends
            if suspends == nil or suspends[scName] == nil then
                context_output(c, false)
                context_stop(c)
                return
            end

            context_registerLifeTimeListener(self, scName, context_getSub(c, "s1"))
        end,

        s1_event = {
            [tabMachine.event_context_resume] = function(c, p, name, target)
                if name == scName then
                    context_output(c, true)
                    context_stop(c)
                    return true
                end
            end
        },
    })
end

context_hasInner = function(self, name, ...)
    local target = self
    while target do
        local inner = target.inner
        if inner ~= nil then
            local f = inner[name]
            if f ~= nil then
                return true
            end
        end
        target = target.p
    end
    return false
end

context_getInner = function(self, name, ...)
    local target = self
    while target do
        local inner = target.inner
        if inner ~= nil then
            local f = inner[name]
            if f ~= nil then
                return f(target, ...)
            end
        end
        target = target.p
    end

    assert(false, "can not find inner for name:" .. tostring(name))
end

context_safeInner = function(self, name, ...)
    local target = self
    while target do
        local inner = target.inner
        if inner ~= nil then
            local f = inner[name]
            if f ~= nil then
                return f(target, ...)
            end
        end
        target = target.p
    end
end

-- tab operator supports
context_meta_len = function(t)
    return t
end

context_meta_shr = function (t1, outputVar)
    local t = g_t_rebind(t1) >> outputVar
    return t
end

context_meta_bor = function(t1, t2)
    if t1 == nil then
        return t2
    end

    if t2 == nil then
        return t1
    end

    local selectTab1 = nil
    if t1 ~= nil then
        local wrappedTab = t1.__wrappedTab
        if wrappedTab ~= nil then
            if wrappedTab.tabName == "__select" then
                selectTab1 = wrappedTab
            end
        end
    end

    local selectTab2 = nil
    if t2 ~= nil then
        local wrappedTab = t2.__wrappedTab
        if wrappedTab ~= nil then
            if wrappedTab.tabName == "__select" then
                selectTab2 = wrappedTab
            end
        end
    end

    local hostTab = nil
    local normalTab = nil

    if selectTab1 == nil and selectTab2 == nil then
        return g_t.select(t1, t2)
    elseif selectTab1 ~= nil and selectTab2 == nil then
        hostTab = t1
        normalTab = t2
    elseif selectTab1 == nil and selectTab2 ~= nil then
        hostTab = t2
        normalTab = t1
    else
        hostTab = t1
    end

    if normalTab ~= nil then
        local tabs = hostTab.__wrappedParams[1]
        table_insert(tabs, normalTab)
        return hostTab
    end

    -- both t1 and t2 are bind tabs
    -- t1 being the host tab
    local hostTabs = hostTab.__wrappedParams[1]
    local guestTabs = t2.__wrappedParams[1]

    for index, tab in ipairs(guestTabs)  do
        table_insert(hostTabs, tab)
    end

    return hostTab
end

context_meta_band = function(t1, t2)
    if t1 == nil then
        return t2
    end

    if t2 == nil then
        return t1
    end

    local selectTab1 = nil
    if t1 ~= nil then
        local wrappedTab = t1.__wrappedTab
        if wrappedTab ~= nil then
            if wrappedTab.tabName == "__join" then
                selectTab1 = wrappedTab
            end
        end
    end

    local selectTab2 = nil
    if t2 ~= nil then
        local wrappedTab = t2.__wrappedTab
        if wrappedTab ~= nil then
            if wrappedTab.tabName == "__join" then
                selectTab2 = wrappedTab
            end
        end
    end

    local hostTab = nil
    local normalTab = nil

    if selectTab1 == nil and selectTab2 == nil then
        return g_t.join(t1, t2)
    elseif selectTab1 ~= nil and selectTab2 == nil then
        hostTab = t1
        normalTab = t2
    elseif selectTab1 == nil and selectTab2 ~= nil then
        hostTab = t2
        normalTab = t1
    else
        hostTab = t1
    end

    if normalTab ~= nil then
        local tabs = hostTab.__wrappedParams[1]
        table_insert(tabs, normalTab)
        return hostTab
    end

    -- both t1 and t2 are bind tabs
    -- t1 being the host tab
    local hostTabs = hostTab.__wrappedParams[1]
    local guestTabs = t2.__wrappedParams[1]

    for index, tab in ipairs(guestTabs)  do
        table_insert(hostTabs, tab)
    end

    return hostTab
end

context_meta_concat = function(t1, t2)
    if t1 == nil then
        return t2
    end

    if t2 == nil then
        return t1
    end

    local selectTab1 = nil
    if t1 ~= nil then
        local wrappedTab = t1.__wrappedTab
        if wrappedTab ~= nil then
            if wrappedTab.tabName == "__seq" then
                selectTab1 = wrappedTab
            end
        end
    end

    local selectTab2 = nil
    if t2 ~= nil then
        local wrappedTab = t2.__wrappedTab
        if wrappedTab ~= nil then
            if wrappedTab.tabName == "__seq" then
                selectTab2 = wrappedTab
            end
        end
    end

    local hostTab = nil
    local normalTab = nil

    if selectTab1 == nil and selectTab2 == nil then
        return g_t.seq(t1, t2)
    elseif selectTab1 ~= nil and selectTab2 == nil then
        hostTab = t1
        normalTab = t2
    elseif selectTab1 == nil and selectTab2 ~= nil then
        hostTab = t2
        normalTab = t1
    else
        hostTab = t1
    end

    if normalTab ~= nil then
        local tabs = hostTab.__wrappedParams[1]
        table_insert(tabs, normalTab)
        return hostTab
    end

    -- both t1 and t2 are bind tabs
    -- t1 being the host tab
    local hostTabs = hostTab.__wrappedParams[1]
    local guestTabs = t2.__wrappedParams[1]

    for index, tab in ipairs(guestTabs)  do
        table_insert(hostTabs, tab)
    end

    return hostTab
end

context.tabName = "context"


--public:
--
tabMachine._pcall = tabMachine_pcall

context.getLifeId = context_getLifeId
context.getSub = context_getSub 
context.getSubByLifeId = context_getSubByLifeId
context.getContextByLifeId = context_getContextByLifeId
context.hasAnySub = context_hasAnySub
context.start = context_start
context.call = context_call
context.throw = context_throw
context.join = context_join
context.select = context_select

context.co_call = context_co_call
context.co_join = context_co_join
context.co_select = context_co_select

context.registerLifeTimeListener = context_registerLifeTimeListener
context.unregisterLifeTimeListener = context_unregisterLifeTimeListener
context.tabProxy = context_tabProxy
context.hasSub = context_hasSub
context.output = context_output
context.getOutputs = context_getOutputs
context.abort = context_abort
context.stop = context_stop
context.stopAllSubs = context_stopAllSubs
context.isStopped = context_isStopped
context.isQuitted = context_isQuitted
context.isQuitting = context_isQuitting
context.downDistance = context_downDistance
context.upDistance = context_upDistance
context.notify = context_notify
context.notifyAll = context_notifyAll
context.upwardNotify = context_upwardNotify
context.upwardNotifyAll = context_upwardNotifyAll
context.forEachSub = context_forEachSub
context.getScheduler = context_getScheduler
context.setScheduler = context_setScheduler
context.setDynamics = context_setDynamics
context.getDebugger = context_getDebugger
context.setDebugger = context_setDebugger
context.setTabProfiler = context_setTabProfiler
context.setBreakPoint = context_setBreakPoint
context.deleteBreakPoint = context_deleteBreakPoint
context.deleteAllBreakPoints = context_deleteAllBreakPoints
context.runNormally = context_runNormally
context.breakAtNextBreakPoint = context_breakAtNextBreakPoint
context.breakAtNextSub = context_breakAtNextSub
context.resumeSuspends = context_resumeSuspends
context.suspend = context_suspend
context.postpone = context_postpone
context.resume = context_resume
context.hasSuspend = context_hasSuspend
context.tabSuspend = context_tabSuspend
context.getDetailedPath = context_getDetailedPath
context.hasInner = context_hasInner
context._ = context_getInner
context._safe = context_safeInner

context._b = function(self, ...)
    return context_getInner(self, "b", ...)
end

--private:
--for current compacity
context._getDebugger = context_getDebugger
context._stopSelf = context_stopSelf

context.__len = context_meta_len
context.__shr = context_meta_shr

context.__bor = context_meta_bor
context.__band = context_meta_band
context.__concat = context_meta_concat

--make t nonreuse to be compatible with bindTab 

local metaWrappedParams = {
    __len = function(t)
        return t.__numParams
    end
}

--------------------wrapped tabs -------------
local metaBind = nil
metaBind = {
    __shr = function(t, outputVar)
        local outputVars = t.__outputVars
        if outputVars == nil then
            outputVars = table_remove(__outputVarsPool)
            if outputVars == nil then
                t.__outputVars = {outputVar}
                return t
            end
            t.__outputVars = outputVars
        end
        table_insert(t.__outputVars, outputVar)
        return t
    end,

    --make fix bind operattor
    -- return a fix bind tab
    __len = function(t)
        if t.__bindFrameIndex == nil then
            return t
        end

        local ft = {}
        setmetatable(ft, metaBind)

        local wrappedTab = t.__wrappedTab
        ft.__wrappedTab = wrappedTab 

        local wrappedParams = t.__wrappedParams
        if wrappedParams == nil then
            wrappedParams = {}
            ft.__wrappedParams = wrappedParams
            setmetatable(wrappedParams, metaWrappedParams)
        else
            ft.__wrappedParams = wrappedParams
            t.__wrappedParams = nil
        end

        ft.__outputVars = t.__outputVars

        t.__wrappedTab = nil
        t.__outputVars = nil
        t.__bindFrameIndex = 0
        __bindTabPool[t] = t

        if wrappedTab.tabName == "__select"or 
            wrappedTab.tabName == "__join" then
            local tabs = wrappedParams[1]
            for index, tab in ipairs(tabs) do
                tabs[index] = #tab
            end
        end

        return ft
    end,
    
    __bor = context.__bor,
    __band = context.__band,
    __concat = context.__concat,
}

g_t_rebind = function(tab, ...)
    local bindTab = next(__bindTabPool)
    local wrappedParams = nil 

    if bindTab == nil then
        bindTab = {}
        setmetatable(bindTab, metaBind)
    else
        __bindTabPool[bindTab] = nil
        wrappedParams = bindTab.__wrappedParams
    end

    if wrappedParams == nil then
        wrappedParams = {}
        bindTab.__wrappedParams = wrappedParams
        setmetatable(wrappedParams, metaWrappedParams)
    end

    bindTab.__bindFrameIndex = g_frameIndex
    bindTab.__wrappedTab = tab

    local numParams = select("#", ...)
    for i = 1, numParams do
        wrappedParams[i] = select(i, ...)
    end
    wrappedParams.__numParams = numParams

    return bindTab
end

g_t.rebind = g_t_rebind

function g_t.bind(tab, ...)

    local bindTab = {}
    setmetatable(bindTab, metaBind)
    bindTab.__wrappedTab = tab

    local wrappedParams =  table_pack(...)
    local numParams = select("#", ...)
    wrappedParams.__numParams = numParams
    setmetatable(wrappedParams, metaWrappedParams)

    bindTab.__wrappedParams = wrappedParams


    -- for i = 1, numParams do
        -- bindTab.__wrappedParams[i] = select(i, ...)
    -- end

    return bindTab
end

__compileCount = 0

function g_t.getTabCodeLocation(tab)
    local fun = rawget(tab, "s1")
    if fun == g_t.empty_fun then
        fun = nil
    end

    if fun == nil then
        for _, v in pairs(tab) do
            if type(v) == "function" then
                if fun ~= g_t.empty_fun then
                    fun = v
                    break
                end
            end
        end
    end

    if fun == nil then
        for k, v in pairs(tab) do
            if type(v) == "table" and type(k) == "string" and k:find("event", 1, true) then
                for _, vv in pairs(v) do
                    if type(vv) == "function" then
                        fun = vv
                        break
                    end
                end

                if fun ~= nil then
                    break
                end
            end
        end
    end

    if fun == nil then
        local inner = rawget(tab, "inner") 
        if inner ~= nil then
            for k, v in pairs(inner) do
                if type(v) == "function" then
                    v = fun
                    break
                end
            end
        end
    end

    if fun == nil then
        for k, v in pairs(tab) do
            if type(v) == "table" and k ~= "super" then
                for _, vv in pairs(v) do
                    if type(vv) == "function" then
                        fun = vv
                        break
                    end
                end

                if fun ~= nil then
                    break
                end
            end
        end
    end

    if fun ~= nil then
        local info = debug.getinfo(fun)
        local file  = info.source
        local line = info.linedefined
        return file, line
    end
end

function g_t.getContextCodeLocation(c)
    local tab = c.__tab
    if tab ~= nil then
        return g_t.getTabCodeLocation(tab)
    end

    if c.p.__tab == nil then
        return
    end

    fun = c.p.__tab[c.__name]

    if fun == nil then
        fun = c.__updateFunEx
    end

    if fun == nil then
        local eventEx = c.__eventEx
        if eventEx ~= nil then
            for _, v in pairs(eventEx) do
                if type(v) == "function" then
                    fun = v
                    break
                end
            end
        end
    end

    if fun ~= nil then
        local info = debug.getinfo(fun)
        file  = info.source
        line = info.linedefined

        return file, line
    end
end

function g_t.precompile(tab)
    __compileCount = __compileCount + 1
    if __tabCompilationStat then
        local file, line = g_t.getTabCodeLocation(tab)
        local location = nil
        if file ~= nil and line ~= nil then
            location = file .. " " .. line 
        else
            location = "unkown tab"
        end
        
        local info = __tabCompilationStat[location]
        if info == nil then
            info = {}
            info.location = location
            info.count = 1
            __tabCompilationStat[location] = info
        else
            info.count = info.count + 1
        end
    end

    local rawget = rawget
    local superTab = rawget(tab, "super")
    if superTab == nil then
        superTab = context 
        tab.super = context
    else
        if rawget(superTab, "__call") == nil then
            superTab.__call = context_meta_call
            superTab.__shr = context_meta_shr
            superTab.__len = context_meta_len

            superTab.__band = context_meta_band
            superTab.__bor = context_meta_bor
            superTab.__concat = context_meta_concat
        end
    end

    local inner = rawget(tab, "inner")
    if inner ~= nil then
        inner.__index = inner

        if superTab ~= nil then
            local p_inner = superTab.inner 
            if p_inner ~= nil then
                setmetatable(inner, p_inner)
            end
        end
    end

    setmetatable(tab, superTab)
    tab.__index = tab
    tab.__hooked = true

    return tab
end

_ = g_t.precompile

function g_t.fix(tab)
    if tab ~= nil then
        return #tab
    end
end

function g_t.seq(...)
    local tabs = {...}
    return g_t.seqWithArray(tabs)
end

g_t.seqWithArray = _({
    tabName = "__seq",

    s1 = function (c, tabs)
        if g_t.debug then
            c._nickName = "seq"
        end
        c.tabs = tabs
        for index, tab in ipairs(tabs) do
            tabs[index] = #tab
        end

        c.index = 1
        c:start("s3")
    end,

    s3 = function (c)
        if c.index > #c.tabs then
            return
        end

        local index = c.index
        c.index = c.index + 1
        c:call(c.tabs[index], "s2")
    end,

    __addNickName = function(c)
        c._nickName = "seqWithArray<" .. (#c.tabs)  .. ">"
    end,
})

function g_t.join(...)
    local tabs = {...}
    return g_t.joinWithArray(tabs)
end

g_t.joinWithArray = _({ 
    tabName = "__join",

    s1 = function(c, tabs)
        if g_t.debug then
            c._nickName = "join"
        end
        for index, tab in ipairs(tabs) do
            c:call(tab, "ss_"..index.. "ss")
        end
    end,

    __addNickName = function(c)
        c._nickName = "joinWithArray<" .. (#c.tabs)  .. ">"
    end,
})


function g_t.select(...)
    local tabs = {...}
    return g_t.selectWithArray(tabs)
end

g_t.selectWithArray = _({
    tabName = "__select",

    s1 = function (c, tabs)
        c.prefix = "__select_sub"
        c.prefixLen = string.len(c.prefix)
        c.tabs = tabs
        for k,tab in ipairs(c.tabs) do 
            local name = c.prefix .. k
            c:registerLifeTimeListener(name, c)
            c:call(tab, name, g_t.anyOutputVars)
        end 
    end,

    event = {
        [tabMachine.event_context_stop] = function(c, p, name, target)
            if name:find(c.prefix) then
                local index = name:sub(c.prefixLen+1)
                c:output(tonumber(index),c.a1, c.a2, c.a3, c.a4, c.a5, c.a6, c.a7,
                c.a8, c.a9, c.a10)
                c:stop()
            end
        end
    },

    __addNickName = function(c)
        c._nickName = "selectWithArray<" .. (#c.tabs)  .. ">"
    end,
})

g_t.delay = _({
    s1 = function(c, totalTime)
        if g_t.debug then
            if totalTime == nil then
                c._nickName = "delay" 
            else
                c._nickName = "delay<" ..totalTime .. ">"
            end
        end
        c.totalTime = totalTime

        --for system schuler we look upon the scheduler to optimize timer performance.
        if totalTime == nil then
            c:stop()
        else
            local scheduler = c:getScheduler()
            c.timer = scheduler:createTimer(c, context_stopSelf, totalTime, 1) --g_t.updateTimerMgr_normal
        end
    end,

    final = function (c)
        if c.timer ~= nil then
            local scheduler = c:getScheduler()
            scheduler:destroyTimer(c.timer)
            c.timer = nil
        end
    end,

    __addNickName = function(c)
        c._nickName = "delay<" .. (c.totalTime)  .. ">"
    end,

    setScheduler = function (c, newScheduler)
        local oldScheduler = c.__scheduler
        if newScheduler == oldScheduler then
            return
        end
        if c.timer ~= nil then
            oldScheduler:destroyTimer(c.timer)
        end
        context_destroyTickAndUpdateTimers(c)
        c.__scheduler = newScheduler
        context_createTickAndUpdateTimers(c)
        c.timer = newScheduler:createTimer(c, context_stopSelf, c.totalTime, 1) --g_t.updateTimerMgr_normal
        local subContexts = c.__subContexts
        if subContexts == nil then
            return
        end
        for _, subContext in ipairs(subContexts) do
            subContext:setScheduler(newScheduler)
        end
    end,

    event = g_t.empty_event,
})

g_t.delayRealTime = _({
    s1 = function(c, totalTime, updateInterval)
        if g_t.debug then
            if totalTime == nil then
                c._nickName = "delayRealTime"
            else
                c._nickName = "delayRealTime<"..totalTime.. ">"
            end
        end
        if totalTime == nil then
            c:stop()
            return
        end

        c.endTime = socket.gettime() + totalTime
        c:setDynamics("s2", "updateInterval", updateInterval)
    end,

    s2 = g_t.empty_fun,
    s2_update = function(c)
        local currentTime = socket.gettime()
        if currentTime >= c.endTime then
            c:stop()
        end
    end,

    --s2_updaeInteral is overrided by setDynamics in s1
    s2_updateInteral = nil,
})

context_meta_call = g_t_rebind
context.__call = context_meta_call

context.tabProxy = _({
        s1 = function(c, self, scName, stopHostWhenStop, proxyFuture, proxyEvent)
            if g_t.debug then
                if scName then
                    c._nickName = "proxy<" .. self:_getPath() .. ":" .. scName .. ">"
                else
                    c._nickName = "proxy<" .. self:_getPath() .. ">"
                end
            end

            c.scName = scName
            c.proxyFuture = proxyFuture
            c.proxyEvent = proxyEvent
            c.self = self

            -- if self.__lifeState >= lifeState.quitting then
            if self.__lifeState >= 20 then
                --inline optimization
                -- c:stop()
                if scName == nil then
                    if self.__outputValues then
                        c:output(table_unpack(self.__outputValues))
                    end
                end
                context_stopSelf(c)
                return
            end

            c.stopHostWhenStop = stopHostWhenStop
            local host = nil
            if scName == nil then
                host = self
            else
                local subContext = context_getSub(self, scName)
                if subContext ~= nil then
                    host = subContext
                else
                    if c.proxyFuture then
                        context_start(c, "t1")
                    else
                        --inline optimization
                        -- c:stop()
                        context_stopSelf(c)
                    end
                end
            end

            if host ~= nil then
                c.host = host
                -- if host.__lifeState >= lifeState.quitting then
                if host.__lifeState >= 20 then
                    if host.__outputValues then 
                        c:output(table_unpack(host.__outputValues))
                    end
                    c:stop()
                    return
                end

                context_addProxy(host, c)
                if c.proxyEvent then
                    context_upwardNotify(c, tabMachine.event_proxy_attached, host, c)
                end
            end
        end,

        __addNickName = function(c)
            if c.scName then
                c._nickName = "proxy<" .. c.self:_getPath() .. ":" .. c.scName .. ">"
            else
                c._nickName = "proxy<" .. c.self:_getPath() .. ">"
            end
        end,

        t1 = function(c)
            local self = c.self
            context_registerLifeTimeListener(self, c.scName, context_getSub(c,"t1"))
        end,
        
        t1_event = {
            [tabMachine.event_context_enter] = function(c, p, name, target)
                c.host = target
                context_addProxy(c.host, c)
                if c.proxyEvent then
                    context_upwardNotify(c, tabMachine.event_proxy_attached, c.host, c)
                end
                context_stop(c, "t1")
            end
        },

        event = g_t.empty_event,

        final = function(c)
            if c.host ~= nil then 
                context_removeProxy(c.host, c)
                -- if c.stopHostWhenStop and c.host.__lifeState < lifeState.quitting then
                if c.stopHostWhenStop and c.host.__lifeState < 20 then
                    --inline optimization
                    -- c.host:stop()
                    context_stopSelf(c.host)
                end
            end
        end,

        --public methods
        getHost = function(c)
            return c.host
        end
})

tabJoin = _({
    tabName = "join",

    s1 = function(c, self, scNames, joinFuture)
        if scNames == nil then
            c:stop()
            return
        end

        if #scNames == 0 then
            c:stop()
            return
        end

        c.scNames = scNames
        if g_t.debug then
            c:__addNickName()
        end

        for index, name in ipairs(scNames) do
            if joinFuture or context_getSub(self, name) ~= nil then
                if c.__unTriggeredContexts == nil then
                    c.__unTriggeredContexts = {}
                end
                table_insert(c.__unTriggeredContexts, name)
                context_registerLifeTimeListener(self, name, c)
            end
        end

        if c.__unTriggeredContexts == nil then
            c:stop()
        end
    end,

    event = {
        [tabMachine.event_context_stop] = function(c, p, name, target)
            local cp = c.p
            if cp ~= p then
                return
            end

            -- if not p or p.__lifeState >= lifeState.quitting then
            if not p or p.__lifeState >= 20 then
                return
            end

            local unTriggeredContexts = c.__unTriggeredContexts
            for index, n in ipairs(unTriggeredContexts) do
                if name == n then
                    table_remove(unTriggeredContexts, index)
                    break
                end
            end

            if not next(unTriggeredContexts) then
                context_stopSelf(c)
            end
        end
    },

    __addNickName = function(c)
        local nickName = "join<" 
        local listName = table_concat(c.scNames, ",")
        nickName = nickName .. listName
        nickName = nickName  .. ">"
        c._nickName = nickName
    end,
})

tabSelect = _({
    tabName = "select",

    s1 = function(c, self, scNames, selectFuture)
        if scNames == nil then
            c:stop()
            return
        end

        if #scNames == 0 then
            c:stop()
            return
        end

        c.scNames = scNames
        if g_t.debug then
            c:__addNickName()
        end

        local isDone = true
        for index, name in ipairs(scNames) do
            if selectFuture or context_getSub(self, name) ~= nil then
                isDone = false
                context_registerLifeTimeListener(self, name, c)
            end
        end

        if isDone then
            c:stop()
        end
    end,

    event = {
        [tabMachine.event_context_stop] = function(c, p, name, target)
            if c.isDone then
                return
            end

            local cp = c.p
            if cp ~= p then
                return
            end

            -- if not p or p.__lifeState >= lifeState.quitting then
            if not p or p.__lifeState >= 20 then
                return
            end

            local stoppedIndex = -1
            local scNames = c.scNames
            for index, scName in ipairs(scNames) do
                if name == scName then
                    stoppedIndex = index
                    break
                end
            end

            if stoppedIndex ~= -1 then
                c.isDone = true
                for index = 1, #scNames do
                    if index ~= stoppedIndex then
                        context_stop(p, scNames[index])
                    end
                end

                if target.__outputValues ~= nil then 
                    context_output(c, stoppedIndex, table_unpack(target.__outputValues))
                else
                    context_output(c, stoppedIndex)
                end
                context_stopSelf(c)
            end
        end,
    },

    __addNickName = function(c)
        local nickName = "select<" 
        local listName = table_concat(c.scNames, ",")
        nickName = nickName .. listName
        nickName = nickName  .. ">"
        c._nickName = nickName
    end,
})

return tabMachine

